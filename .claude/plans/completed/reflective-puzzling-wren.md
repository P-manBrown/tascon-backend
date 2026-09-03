# タスクグループ引き継ぎ機能 残作業計画（更新版）

## 背景

`claudedocs/workflow_task_group_handover.md`（既存計画書）とブランチ`feat/task-group-handover`実コードを突き合わせ、進捗ズレ確認。結果:

- Step0（ブランチ作成）・Step1（statusカラム追加）完了。`task_group_share.rb`に`enum :status, { shared: 0, handover_pending: 1 }, prefix: true, default: :shared, validate: true`実装済み、`only_one_handover_pending_per_task_group`バリデーションも実装済み。
- Step2（`owned_task_group_shares`関連＋所有者視点一覧エンドポイント）**未着手**。`user.rb`に該当アソシエーションなし、`routes.rb`にネストなし、`task_group_share_resource.rb`に`user`属性なし。
- Step3（`request_handover`）**コミット済みだが旧設計のまま**。現行`a38eab4`は`collection`ルート＋`task_group_id`/`user_id`ボディパラメータ方式（設計判断2で撤回済みの方式）。ルートも`member`化されておらず`collection do patch :request_handover end`のまま。
  - 旧`637396c`は既にamend/reset+再コミットで`a38eab4`化済み（reflogにのみ残存）。ただし中身は設計判断2未反映のまま。
- Step4（`cancel_handover_request`）・Step5（`accept_handover`）・Step6（`decline_handover`）**未実装**。
- Step7（シードデータ）**未実装**。`db/seeds.rb`のTaskGroupShare生成2ブロックとも`status:`未指定＝全件`shared`。`handover_pending`ケースなし。
- 環境確認済み: `git-spice`（v0.31.2）・`gs`とも使用可。`debride-whitelist.txt`（734B）・`.github/pull_request_template.md`（Summary/Changes/Testing/Related Issues (Optional)/Notes (Optional)構成）存在。
- `render_validation_error`/`render_custom_error`は`app/controllers/concerns/error_rendering.rb`の`ErrorRendering` concern定義済み、既存パターンのまま使用可。
- `ApplicationResource`（Alba）は`one`/`many` DSL使用（例: `contact_resource.rb`の`one :contact_user, resource: UserResource`、`task_group_resource.rb`の`many :shared_users, resource: UserResource, if: proc { ... }`）。Step2の`user`属性追加はこのパターンに合わせ`one :user, resource: UserResource`。

**方針確定**: Step2着手前に`a38eab4`を`git reset --soft`で巻き戻し・`git stash`退避。Step2をクリーンに積んでからStep3として`a38eab4`相当をmember設計で作り直す。`a38eab4`は未push・未PRのローカル限定コミットゆえ安全。最終的に「Step2→Step3」の依存順どおりの履歴になり、1コミット=1機能の原則も保てる。

**追記（ブランチ粒度、2026-08-21）:** Step2・Step3実施後、`git-spice log long`で既存スタック全体の粒度を確認したところ、既存ブランチは全て「1ブランチ=1機能=1〜2コミット」（例: `feat/task-group-shared-users`は2コミット、`feat/task-group-shares-calendar`も2コミット）。当初`feat/task-group-handover`1本にStep1〜3の5コミットを積んでいたのは既存粒度と不一致だったため、`git-spice branch split --at <commit>:<name>`で機能単位に分割し直した:
```
feat/restrict-shared-users-serialization (PR #583)
  └─ feat/task-group-share-status        (2b75953: Step1)
       └─ feat/task-group-shares-owner-index  (13a081f, 876ce8a: Step2)
            └─ feat/task-group-handover        (733625d, 0733aa9: Step3、現ブランチ名を維持)
```
**Step4以降もこの粒度に倣い、各Step着手前に`git-spice branch create <name>`で新しいブランチを切ってからコミットする**（1Stepを1ブランチ＝1〜2コミットとして積み、複数Stepを同一ブランチにまとめない）。

---

## Step構成（更新後）

```
Step 0: ブランチ作成                                    （完了済み）
Step 1: statusカラム追加                                （完了済み: 2b75953）
Step 2a: a38eab4巻き戻し・退避                          （作業のみ、コミットなし）
Step 2: owned_task_group_shares関連＋共有一覧エンドポイント → 新規コミット
Step 3: request_handoverエンドポイント（member化・作り直し） → 新規コミット
Step 4: cancel_handover_requestエンドポイント           → 新規コミット
Step 5: accept_handoverエンドポイント                   → 新規コミット
Step 6: decline_handoverエンドポイント                  → 新規コミット
Step 7: シードデータ追加                                → 新規コミット
Step 8: 最終品質ゲート・PR作成                          （コミットなし、lint修正のみ追加あり得る）
```

---

## Step 2a: `a38eab4`巻き戻し・退避（作業のみ）

- [ ] `git status`で作業ツリークリーン確認
- [ ] `git log --oneline -3`で`a38eab4`がHEADであること再確認
- [ ] `git reset --soft 2b75953`実行（`routes.rb`の`collection do patch :request_handover end`とコントローラーの`request_handover`/`set_owned_task_group_share`/`ensure_status_shared`が未コミット状態に戻る）
- [ ] `git stash push -m "old request_handover design (collection based)"`で退避

---

## Step 2: owned_task_group_shares関連＋共有一覧エンドポイント（新規コミット）

前任者（オーナー）視点で「自分のタスクグループが誰に共有されているか」を`task_group_share.id`付きで取得可能にする。Step3以降の`member`ルート（`:id`ベース）の前提。

### 変更内容
- [ ] `config/routes.rb`: `task_groups`をブロック化しネスト追加:
  ```ruby
  resources :task_groups do
    resources :task_group_shares, only: :index
  end
  ```
- [ ] `app/controllers/api/v1/task_group_shares_controller.rb`の`index`をネスト時／非ネスト時で分岐:
  ```ruby
  def index
    task_group_shares = task_group_shares_scope.order(created_at: :desc)

    render json: TaskGroupShareResource.new(task_group_shares), status: :ok
  end

  private
    def task_group_shares_scope
      if params[:task_group_id]
        current_api_v1_user.task_groups.find(params[:task_group_id])
                            .task_group_shares.includes(user: :avatar_attachment)
      else
        current_api_v1_user.task_group_shares
                            .without_blocked_owners(current_api_v1_user)
                            .includes(task_group: { user: :avatar_attachment })
      end
    end
  ```
  既存`index`の`without_blocked_owners`呼び出しは非ネスト分岐に移動。`includes`も`task_group_shares_scope`の各分岐に必要な分だけ持たせる（ネスト時に`task_group`まで含めるとBulletが「findで確定済みの親を不要にeager loadしている」と検出し500エラーになるため、Bruno CLI確認時に判明・修正）。
- [ ] `app/resources/task_group_share_resource.rb`に共有相手（受け取り手）情報追加:
  ```ruby
  one :user, resource: UserResource
  ```

### チェックポイント
- [ ] `docker compose exec -T api bundle exec rubocop --autocorrect`
- [ ] Bruno CLIで`GET /api/v1/task_groups/:task_group_id/task_group_shares`実行、`task_group_share.id`と`user`返却確認
- [ ] 非オーナーの`task_group_id`指定時404確認
- [ ] 既存`GET /api/v1/task_group_shares`（非ネスト）の回帰確認

### コミット
```bash
git add app/models/user.rb config/routes.rb app/controllers/api/v1/task_group_shares_controller.rb app/resources/task_group_share_resource.rb
git-spice commit create -m "feat: add task group shares index scoped to owner"
```

---

## Step 3: request_handoverエンドポイント（member化・作り直し、新規コミット）

Step2aで退避した旧実装を`member`ルート＋`owned_task_group_shares`ベースで作り直す。

### 変更内容
- [ ] `git stash pop`で旧差分復元
- [ ] `app/models/user.rb`に追加（Step2では未使用のため追加せず、実際に使うこのStepでまとめて追加。debrideの未使用メソッド判定を避ける意図もある）:
  ```ruby
  has_many :owned_task_group_shares, through: :task_groups, source: :task_group_shares
  ```
- [ ] `config/routes.rb`: `collection do patch :request_handover end`削除、`member`ブロックへ移動:
  ```ruby
  resources :task_group_shares, only: %i[index show create] do
    member do
      get :tasks
      get "tasks/:task_id", to: "task_group_shares#task", as: :task
      get :calendar
      patch :request_handover
    end
  end
  ```
- [ ] `set_owned_task_group_share`を`:id`のみで対象特定する実装に置き換え:
  ```ruby
  before_action :set_owned_task_group_share, only: :request_handover
  before_action :ensure_status_shared, only: :request_handover

  def request_handover
    if @task_group_share.update(status: :handover_pending)
      render json: TaskGroupShareResource.new(@task_group_share), status: :ok
    else
      render_validation_error(@task_group_share.errors)
    end
  end

  private
    def set_owned_task_group_share
      @task_group_share = current_api_v1_user.owned_task_group_shares.find(params[:id])
    end

    def ensure_status_shared
      return if @task_group_share.status_shared?

      render_custom_error source: "status", type: "invalid_transition", message: "共有中の状態でのみ引き継ぎを依頼できます。"
    end
  ```
  `request_handover`本体・`ensure_status_shared`は変更なし。変更点は`set_owned_task_group_share`のみ。

### チェックポイント
- [ ] `docker compose exec -T api bundle exec rubocop --autocorrect`
- [ ] Bruno CLIで`PATCH /api/v1/task_group_shares/:id/request_handover`実行、`200`確認
- [ ] `handover_pending`状態への再実行で`422 invalid_transition`確認
- [ ] 非オーナーの`task_group_share.id`指定時404確認
- [ ] `routes.rb`の`collection`ブロック完全削除を目視確認

### コミット
```bash
git add app/models/user.rb config/routes.rb app/controllers/api/v1/task_group_shares_controller.rb
git-spice commit create -m "feat: add task group share request handover endpoint"
```

---

## Step 4: cancel_handover_requestエンドポイント（新規コミット）

前任者が依頼キャンセル。Step3の`before_action`拡張。

### 変更内容
- [ ] `config/routes.rb`: `member`ブロックに`patch :cancel_handover_request`追加
- [ ] コントローラー:
  ```ruby
  before_action :set_owned_task_group_share, only: %i[request_handover cancel_handover_request]
  before_action :ensure_status_handover_pending, only: :cancel_handover_request

  def cancel_handover_request
    if @task_group_share.update(status: :shared)
      render json: TaskGroupShareResource.new(@task_group_share), status: :ok
    else
      render_validation_error(@task_group_share.errors)
    end
  end

  private
    def ensure_status_handover_pending
      return if @task_group_share.status_handover_pending?

      render_custom_error source: "status", type: "invalid_transition", message: "引き継ぎ依頼中の状態でのみ実行できます。"
    end
  ```

### チェックポイント
- [ ] `docker compose exec -T api bundle exec rubocop --autocorrect`
- [ ] Bruno CLIで正常系（`handover_pending`→`shared`）・異常系（`shared`状態での実行→`422`）確認

### コミット
```bash
git add config/routes.rb app/controllers/api/v1/task_group_shares_controller.rb
git-spice commit create -m "feat: add task group share cancel handover request endpoint"
```

---

## Step 5: accept_handoverエンドポイント（新規コミット）

後任者が引き継ぎ承認、所有権移転。機能中核。**このアクションのみ`ActiveRecord::Base.transaction`＋bangメソッド使用**（設計判断1の例外＝ロールバック必要なケース）。`member`ルート、`set_task_group_share`（受け取り手視点`:id`ベース）は既存のままStep2/3の影響を受けない。

### 変更内容
- [ ] `config/routes.rb`: `member`ブロックに`patch :accept_handover`追加
- [ ] コントローラー:
  ```ruby
  before_action :set_task_group_share, only: %i[show accept_handover]
  before_action :ensure_status_handover_pending, only: %i[cancel_handover_request accept_handover]

  def accept_handover
    task_group = @task_group_share.task_group
    successor_id = @task_group_share.user_id
    predecessor_id = task_group.user_id

    ActiveRecord::Base.transaction do
      task_group.update!(user_id: successor_id)
      @task_group_share.destroy!
      task_group.task_group_shares.create!(user_id: predecessor_id)
    end

    render json: TaskGroupResource.new(task_group, params: { include_shared_users: true }), status: :ok
  end
  ```
  `TaskGroupResource`の既存`many :shared_users, resource: UserResource, if: proc { params[:include_shared_users] }`をそのまま利用。

### チェックポイント
- [ ] `docker compose exec -T api bundle exec rubocop --autocorrect`
- [ ] 副作用大きい処理ゆえBruno CLI手動確認必須（実行後: 旧オーナーが`shared_users`に含まれる／旧オーナーの`task_group_shares`削除済み／`task_group.user_id`が後任者に変わっている、を確認）
- [ ] 異常系（`only_one_handover_pending_per_task_group`抵触等）でトランザクションロールバック確認

### コミット
```bash
git add config/routes.rb app/controllers/api/v1/task_group_shares_controller.rb
git-spice commit create -m "feat: add task group share accept handover endpoint"
```

---

## Step 6: decline_handoverエンドポイント（新規コミット）

後任者が引き継ぎ拒否。4アクション揃い機能完結。

### 変更内容
- [ ] `config/routes.rb`: `member`ブロックに`patch :decline_handover`追加
- [ ] コントローラー:
  ```ruby
  before_action :set_task_group_share, only: %i[show accept_handover decline_handover]
  before_action :ensure_status_handover_pending, only: %i[cancel_handover_request accept_handover decline_handover]

  def decline_handover
    if @task_group_share.update(status: :shared)
      render json: TaskGroupShareResource.new(@task_group_share), status: :ok
    else
      render_validation_error(@task_group_share.errors)
    end
  end
  ```

### チェックポイント
- [ ] `docker compose exec -T api bundle exec rubocop --autocorrect`
- [ ] Bruno CLIで正常系・異常系確認
- [ ] `cancel_handover_request`（前任者視点・`set_owned_task_group_share`）と`decline_handover`（後任者視点・`set_task_group_share`）の使い分け正しいかコードレビュー確認

### コミット
```bash
git add config/routes.rb app/controllers/api/v1/task_group_shares_controller.rb
git-spice commit create -m "feat: add task group share decline handover endpoint"
```

---

## Step 7: シードデータ追加（新規コミット）

Step2〜6完成後にまとめて実施（`handover_pending`シードは対応エンドポイント揃って初めて意味を持つ、途中追加は手戻り発生のため）。`db/seeds.rb`のTaskGroupShare生成2ブロックとも`status:`未指定＝全件`shared`。

### 変更内容
- [ ] `db/seeds.rb`のTaskGroupShare生成部分（`test_user`→contact向け、または contact→`test_user`向けいずれか）の一部に`status: :handover_pending`明示ケース追加。既存`shared`ロジックは維持、サンプル数のうち1〜2件のみ変更。`only_one_handover_pending_per_task_group`バリデーション抵触回避のため、同一`task_group`内で複数`handover_pending`が同時生成されないよう注意。

### チェックポイント
- [ ] `docker compose exec -T api bundle exec rails db:seed`正常完了確認
- [ ] `TaskGroupShare.status_handover_pending.count`が想定件数か確認
- [ ] `docker compose exec -T api bundle exec rubocop --autocorrect`

### コミット
```bash
git add db/seeds.rb
git-spice commit create -m "feat: add handover pending seed data for task group shares"
```

---

## Step 8: 最終品質ゲート・PR作成

- [ ] `docker compose exec -T api bundle exec rubocop`（全体）
- [ ] `docker compose exec -T api bundle exec debride --rails -w debride-whitelist.txt`（`set_owned_task_group_share`/`ensure_status_shared`/`ensure_status_handover_pending`、`owned_task_group_shares`アソシエーションがデッドコード判定されないか確認。必要ならwhitelist追記も1コミット扱い）
- [ ] `docker compose exec -T api bundle exec rspec`（既存テスト回帰確認のみ、今回追加機能自体のテストなし）
- [ ] `git log --oneline`で最終コミット構成確認（Step2〜7が1コミットずつ、設計崩れ残存なし）
- [ ] `git-spice branch submit`でPR作成（`.github/pull_request_template.md`準拠、関連Issueなければ`Related Issues: N/A`、Notesに「テストは別途追加予定」明記）

---

## スコープ外（変更なし）

- 共有削除（`DELETE /task_group_shares/:id`）エンドポイント
- 引き継ぎ通知機能
- 既存`task_group`/`task_group_share`関連コードのうち今回触れない部分のテスト後追い
- フロントエンド側（`tascon-frontend`）`ShareTaskGroupContactList`実装変更（別リポジトリ・別セッション）

---

## 対象ファイル

- `app/controllers/api/v1/task_group_shares_controller.rb`
- `config/routes.rb`
- `app/models/user.rb`
- `app/resources/task_group_share_resource.rb`
- `db/seeds.rb`

## 検証方法

各Stepのチェックポイント（rubocop・Bruno CLI手動確認）実施後コミット。全Step完了後Step8で`rubocop`・`debride`・`rspec`（回帰確認のみ）実行しPR作成。
