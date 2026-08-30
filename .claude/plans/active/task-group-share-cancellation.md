# タスクグループ共有解除機能 実装プラン

## Context

現在 `TaskGroupShare` には作成(`create`)・引き継ぎワークフロー(`request_handover`/`cancel_handover_request`/`accept_handover`/`decline_handover`)はあるが、共有そのものを解除する `destroy` アクションが存在しない。一度共有すると、オーナー・共有された側どちらからも共有関係を解消できない状態になっている。これを解消するため、共有解除機能を新設する。

合意した仕様:
- 解除は「オーナー(`task_group.user`)が共有相手を外す」操作と「共有された側(`user`)が自ら共有から抜ける」操作の両方に対応する。別アクションに分けず、同一の `DELETE /api/v1/task_group_shares/:id` で権限チェックのみ両者を許可する形にする。
- `status: shared` の場合のみ解除可能。`handover_pending`(引き継ぎ依頼中)は不可とし、`invalid_transition` エラーを返す。状態不整合(引き継ぎ進行中に共有関係が消える)を防ぐため。
- ブロック関係の有無は解除可否に影響させない。`without_blocked_owners` は index/show 系の可視性フィルタであり、既に共有関係にある当事者が離脱・解除する権利とは別軸のため、destroy には適用しない。
- RSpecによるテストは本プランの対象外(別途後日作成)。

## ステップ構成

ブランチ単位で1ステップとする。各ステップは単独でBruno CLIによる動作確認まで完結させる(このリポジトリの運用ルール: エンドポイント追加・変更時はBruno CLI確認必須、新設メソッド/scopeは使用コードと同一コミットにまとめる)。

分割軸は機能単位: **Step1でオーナーによる解除を実装し、Step2で共有された側の自己離脱を追加**する。Step2はStep1のブランチを土台にしたスタック構成(git-spice)を想定。

---

### Step1: オーナーによる共有解除

オーナー(`task_group.user`)が共有相手を外せるようにする。finderは既存の `set_owned_task_group_share` と同じ考え方(`current_api_v1_user.owned_task_group_shares`)を使う。

#### 変更ファイル

**`app/controllers/api/v1/task_group_shares_controller.rb`**

`before_action` に destroy専用finderを追加(既存の `set_task_group_share`／`set_owned_task_group_share` は対象アクションを増やさず、権限範囲を変えない):

```ruby
before_action :set_task_group_share, only: %i[show decline_handover accept_handover]
before_action :set_tasks, only: %i[tasks task calendar]
before_action :set_owned_task_group_share, only: %i[request_handover cancel_handover_request destroy]
before_action :ensure_status_handover_pending, only: %i[cancel_handover_request decline_handover accept_handover]
```

`destroy` はStep1時点では既存の `set_owned_task_group_share` に相乗りする(オーナー限定)。専用finderはStep2で導入する。

`destroy` アクション本体。ステータスチェックは `request_handover` のインラインパターンを踏襲する(過去に `ensure_status_shared` という同種の before_action が存在したが、利用箇所が1つしかなく `720b2dc refactor: replace ensure_status_shared before_action with inline check` でインライン化された実績があるため、同じ理由で before_action 化しない):

```ruby
def destroy
  unless @task_group_share.status_shared?
    return render_custom_error source: "status", type: "invalid_transition", message: "共有中の状態でのみ解除できます。"
  end

  @task_group_share.destroy!
  head :no_content
end
```

**`config/routes.rb`**

```diff
-        resources :task_group_shares, only: %i[index show create] do
+        resources :task_group_shares, only: %i[index show create destroy] do
```

**`.bruno/Collection/TaskGroupShares/Destroy.bru`**(新規)

既存ファイルの `meta.seq` 最大値が11のため、`seq: 12` とする。

```
meta {
  name: Destroy
  type: http
  seq: 12
}

delete {
  url: {{BASE_URL}}/{{API_VERSION}}/task_group_shares/2
  body: none
  auth: inherit
}

headers {
  Origin: {{FRONTEND_ORIGIN}}
}

settings {
  encodeUrl: true
  timeout: 0
}
```

#### 動作確認(`bru run`、curl代用不可)

1. owner側トークンで実行し204を確認。
2. 共有された側(recipient)トークンで実行し403/404(オーナーでないため権限エラー)になることを確認。
3. `Request Handover.bru` 実行後(`handover_pending`化)にDestroyを実行し、422 + `invalid_transition` を確認。

---

### Step2: 共有された側による自己離脱

recipient自身も同じ `DELETE /api/v1/task_group_shares/:id` で共有から抜けられるように、finderの権限範囲を拡張する。

#### 変更ファイル

**`app/models/task_group_share.rb`** — scope追加

既存の `without_blocked_owners` と同じ「lambda + joins」スタイルで追加する。

```ruby
scope :owned_or_shared_with, lambda { |user|
  joins(:task_group)
    .where(task_groups: { user_id: user.id })
    .or(joins(:task_group).where(user_id: user.id))
}
```

`.or` はRailsの制約上、両辺の `joins` が構造的に一致している必要があるため、両方に `joins(:task_group)` を明示する。

**`app/controllers/api/v1/task_group_shares_controller.rb`**

destroy専用finderを新設し、`owned_task_group_shares` への相乗りから切り離す:

```ruby
before_action :set_task_group_share, only: %i[show decline_handover accept_handover]
before_action :set_tasks, only: %i[tasks task calendar]
before_action :set_owned_task_group_share, only: %i[request_handover cancel_handover_request]
before_action :set_task_group_share_for_destroy, only: :destroy
before_action :ensure_status_handover_pending, only: %i[cancel_handover_request decline_handover accept_handover]
```

```ruby
def set_task_group_share_for_destroy
  @task_group_share = TaskGroupShare.owned_or_shared_with(current_api_v1_user).find(params[:id])
end
```

`destroy` アクション本体はStep1のまま変更不要。

第三者アクセスは `owned_or_shared_with` scope により `find` が `ActiveRecord::RecordNotFound` を投げ、標準の404になる(他のdestroyアクションと同じ挙動)。`destroy!` はバリデーションを経由しないため `must_be_contact` 等の影響はない。

#### 動作確認(`bru run`、curl代用不可)

1. owner側トークンで実行し204を確認(既存動作の再確認、デグレなきこと)。
2. recipient側トークンで実行し204を確認(新規に許可される)。
3. 第三者トークンで実行し404を確認。
4. `handover_pending` 中の解除が422になることを再確認(既存動作の再確認)。

---

## 実装方針

このプランニングセッションでは設計のみ行い、実コード実装はCodex系エージェントへ委譲する。各ステップは1ブランチ=1コミットとし、Bruno CLIでの動作確認が完了した状態でコミットする。

## 検証方法

1. devcontainer内でPuma起動後、各ステップのBruno確認手順を `bru run "TaskGroupShares/Destroy.bru" --env <environment>` で実施。
2. `bundle exec rubocop` で新規・変更ファイルのスタイル確認。
