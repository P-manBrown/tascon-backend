# タスクグループ共有解除機能 実装プラン

Worktree: /home/ruby/tascon-backend/.claude/worktrees/agent-a7729d0959ce38cc6

## Progress

- [x] Step1: オーナーによる共有解除（ブランチ `feat/task-group-share-destroy`、親 `docs/doc-gardening-sync`、コミット `c603f42`）。Bruno: オーナー解除(id 15) 204、受け手(id 14) 404、`handover_pending`(id 18) 422 + `invalid_transition`
- [x] Step2: 共有された側による自己離脱（ブランチ `feat/task-group-share-self-leave`、Step1の上にスタック、restack後のコミット `588a2b9`）。Bruno: オーナー解除(id 20) 204、受け手離脱(id 26) 204、第三者(id 16) 404、`handover_pending`(id 18) 422 + `invalid_transition`
- [x] レビュー修正: `destroy` の競合対策（`with_lock` 内で状態と `user_id` を再確認）を `feat/task-group-share-destroy` に `d709345` として追加し、git-spiceで上位ブランチをrestack。Bruno: Step1ブランチでオーナー(id 22) 204・`handover_pending`(id 18) 422、Step2ブランチでオーナー(id 23) 204・受け手(id 29) 204・`handover_pending`(id 18) 422
- [ ] 残作業: PR作成・マージ（ユーザー指示待ち）、RSpec（本プラン対象外）
- 検証で dev DB の共有 id 15・20・22・23・26・29 を削除済み（`Destroy.bru` のURLは id 2 に戻してある）

再開時の前提:
- worktreeには `config/master.key` が無いため、メインリポジトリの `config/master.key` へのシンボリックリンクを置いて `bin/rails` / Puma を起動する（gitignore対象）。
- Bruno検証は `test@example.com`（id 302）のみで全ケースを網羅する。同ユーザーがオーナーの共有・受け手の共有・無関係な共有を、`Destroy.bru` のURL中のidを差し替えて叩き分ける（他ユーザーのパスワードはseedでランダムなため）。

## Decision Log

- 2026-10-09: プラン作成後に `TaskGroupShare` 周辺がリファクタされた（`accept_handover!` のモデル移動、finder/ステータスガイドの整理）ため、着手時に現行コードと突き合わせた。`set_owned_task_group_share`・`render_custom_error`・`status_shared?` はプラン記載どおり存在し、Step1/Step2のスニペットは修正不要と判断。
- 2026-10-09: Bruno検証の「recipient」「第三者」ケースは、別ユーザーでサインインする代わりに test ユーザーが受け手／無関係となる共有idを対象にして再現する。Sign In.bru はtestユーザー固定で、他ユーザーの認証情報を追加するとCollectionに一時的な認証ファイルが増えるため。
- 2026-10-09: 親セッションのcode-reviewで、`destroy` の状態チェックと `destroy!` の間に引き継ぎ承認（状態変更・`user_id` 入れ替え）が割り込む競合が指摘された。`user_id` を控えたうえで `with_lock`（reloadを伴う）内で `status_shared?` と `user_id` 不変を再確認し、満たさなければ同じ422 `invalid_transition` を返す形に修正した。競合の発生源がStep1のため、Step1ブランチへ新規コミットとして積みrestackした。
- 2026-10-09: 同レビューの以下の指摘は対応しないと判断した。
  - RSpecが無い: テストは本プランの対象外（別途作成）と合意済みのため。
  - `Destroy.bru` が固定idを削除する破壊的リクエストである: 他の更新系 `.bru`（Create・Request Handover等）も固定idを使っており、それに揃えているため。
  - shared状態のガードが `request_handover` と重複している: `destroy` 側のチェックはロック内で行う必要があり、before_actionに切り出せないため。
  - `owned_or_shared_with` scope のjoinの書き方: プラン作成時に決めた方式（`.or` の両辺に `joins(:task_group)` を明示）のため。
  - ブロック中のオーナーに `without_blocked_owners` を適用していない: 可視性フィルタと当事者の離脱・解除権は別軸とするプラン合意済みの仕様のため。

## Validation and Acceptance

- Step1: `bru run` で、オーナーとしての解除が204、受け手としての解除が404（オーナー限定finderで見つからない）、`handover_pending` の共有の解除が422 + `invalid_transition` になる。1コミット。
- Step2: `bru run` で、オーナー204、受け手204、第三者404、`handover_pending` 422 になる。1コミット。
- `bundle exec rubocop` が変更ファイルで違反なし。

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

## Decision Log

### `destroy` の排他制御と状態チェックの設計（`d7093452`）

最終的な `destroy` は次の形とした。

```ruby
def destroy
  user_id = @task_group_share.user_id

  @task_group_share.with_lock do
    unless @task_group_share.status_shared? && @task_group_share.user_id == user_id
      return render_custom_error source: "status", type: "invalid_transition", message: "共有中の状態でのみ解除できます。"
    end

    @task_group_share.destroy!
  end

  head :no_content
end
```

各要素の意図:

- `status_shared?` チェック: 引き継ぎ依頼は独立したレコードではなく share 行の `status` で表現されるため、`handover_pending` の share を削除すると依頼ごと消える。状態遷移を `handover_pending →（取り消し／辞退／承認）→ shared → 削除` の一本道にし、削除と承認が同じ行を奪い合わない形にするために `shared` 時のみ解除可能とした。誤操作防止は副次的な効果に過ぎない（オーナーは取り消し後に解除できる）。
- `with_lock`: トランザクションを開き `SELECT ... FOR UPDATE` で行を再読込・ロックする。状態チェックから `destroy!` までの間に `accept_handover!` が割り込むことを防ぐ。
- `user_id` の退避と一致確認: before_action（`set_owned_task_group_share`）の認可はロック外で行われるため、認可からロック取得までの間に `accept_handover!` が完了し得る。完了後の share は `status=shared`・`user_id=元オーナー` となり `status_shared?` だけでは通過してしまい、もはやオーナーではないユーザーが意味の変わった share を削除できてしまう。`accept_handover!` は必ず `user_id` を書き換えるため、認可時点の値と比較して入れ替わりを検出し `invalid_transition` を返す。`with_lock` は同じオブジェクトを再読込で上書きするため、認可時点の値はブロックに入る前に変数へ退避しておく必要がある。なお `user_id` は共有先ユーザーの ID であり、ログインユーザー（オーナー）の ID ではない。

検討した代替案:

- ロック内で認可付きに取得する（`current_api_v1_user.owned_task_group_shares.lock.find(params[:id])`）: `user_id` の退避・比較が不要になり見通しは良くなる。しかし JOIN により `task_groups` 行もロックされ、`task_group → share` の順に更新する `accept_handover!` とロック順序が逆転してデッドロックし得る（未検証）。また競合時のレスポンスが 422 から 404 に変わる。share 1 行のみをロックする現行方式を採用した。
- 見通しを改善する場合は、ロジックを変えずに `cancel!(expected_user_id:)` のようなモデルメソッドへ切り出すのが無難。
