# アーキテクチャ概要

この文書は、コードを探すための大まかな地図である。挙動の authoritative source はコード自体である。

## この文書の目的

Tascon Backend の機能がリポジトリ内のどこに置かれ、主要な層がどう接続されるかを示す。
個々の処理、制約、エンドポイント、レスポンス項目の仕様は扱わない。

## 全体像

Tascon Backend は、ユーザー間の連絡先管理・ブロック機能を備えたタスク管理システムの Rails API サーバーである。通常のリクエストは `config/routes.rb` から Controller、Model、Resource へ流れ、JSON として返される。

- `app/controllers/`：HTTP、認証・認可、入力、処理の組み立て。
- `app/models/`：永続化、関連、データの整合性、再利用する問い合わせ。
- `app/resources/`：Model から公開用 JSON への変換。
- `app/validators/`：複数箇所から利用できる追加の検証。
- `config/`：ルーティング、環境設定、Gem の初期設定。
- `db/`：スキーマとマイグレーション。
- `lib/`：Rails標準の拡張点に収まらない処理。Devise の挙動を上書きする monkey patch は `lib/monkey_patches/` にある。
- `spec/`：各層の振る舞いを検証するテスト。

API 専用構成を基本とするが、認証メールと OAuth の補助画面のために Mailer と View も持つ。

## `app/` 配下のレイヤー

### `app/controllers/`

HTTP リクエストを受け、認証済みユーザーを起点に Model の操作と Resource の描画を調整する。基底は `application_controller.rb`、共通のエラー描画は `concerns/error_rendering.rb` である。

バージョン付き API は `api/v1/` にある。代表的な入口は `tasks_controller.rb`、`task_groups_controller.rb`、`contacts_controller.rb`、`blocks_controller.rb`、`users_controller.rb` である。認証フロー固有の拡張は `api/v1/auth/` に分離されている。

### `app/models/`

Active Record モデルと、永続化データに密接な関連・整合性・検索条件を置く。主要なモデルは `user.rb`、`task_group.rb`、`task.rb`、`contact.rb`、`block.rb` である。

中心となる所有関係は `User → TaskGroup → Task` である。Contact と Block は User 間の関係を表し、Avatar は Active Storage が管理する。Model に組み込む拡張は `models/concerns/` に置く。

### `app/resources/`

Alba を使い、Model を API の JSON 表現へ変換する。共通基底は `application_resource.rb` で、代表的な Resource は `task_resource.rb`、`task_group_resource.rb`、`user_resource.rb`、`account_resource.rb`、`contact_resource.rb`、`block_resource.rb` である。

### `app/validators/`

Rails 標準だけでは表しにくい再利用可能な属性検証を置く。添付ファイルの形式検証には `mime_type_and_extension_consistency_validator.rb` がある。

### `app/mailers/` と `app/views/`

認証関連メールは `application_mailer.rb` と `devise_mailer.rb` が担い、テンプレートとレイアウトは `app/views/` にある。`app/views/` は通常の API 画面層ではなく、メールと認証フローの補助用途である。

### `app/jobs/` と `app/channels/`

Active Job と Action Cable の基底クラスを置く境界である。アプリケーション固有の非同期処理や Channel を追加する場合は、それぞれのディレクトリが入口になる。

## ルーティングの地図

URL、HTTP Method、Controller の対応は `config/routes.rb` が authoritative source である。

## レイヤー間の責務

- Controller：HTTP とアプリケーションの境界を担当し、認証・認可、入力解釈、Model の呼び出し、HTTP Status とレスポンス生成を調整する。
- Model：データベース関連、整合性、再利用する検索条件、永続化データに密接な処理を担当する。
- Resource：API に公開する JSON 表現と関連の埋め込みを担当する。
- Validator：Model から利用する再利用可能な追加検証を担当する。

Controller から Resource へは描画に必要な文脈を渡せるが、Resource は永続化や認可を行わない。Model は HTTP の入力形式やレスポンス形式を扱わない。

## 横断的な仕組み

### 認証と認可

認証は Devise、Devise Token Auth、OmniAuth を中心に構成され、設定は関連 Initializer、アプリ固有の HTTP 処理は `app/controllers/api/v1/auth/`、認証主体は `User` にある。

汎用の Policy レイヤーは意図的に置かれていない。データ範囲と認可は、各 Controller が `current_api_v1_user` を起点に関連を辿るか、`ApplicationController` の共通処理を使って制限する。

### JSON とエラー

成功レスポンスの Model 表現は `app/resources/` に集約する。共通のエラー描画は `ErrorRendering` が担い、リクエスト固有の判断は Controller に残す。

### ページネーション

一覧のページネーションには Pagy を使う。導入点は `ApplicationController` と `config/initializers/pagy.rb` である。

### 添付ファイル

User の Avatar は Active Storage の境界に置かれる。モデル側の入口は `User`、追加検証は `app/validators/`、保存先設定は `config/storage.yml` である。

### オリジン制御

フロントエンドからのクロスオリジンリクエストは `config/initializers/cors.rb`（rack-cors）が境界となり、許可オリジンは環境変数 `FRONTEND_ORIGIN` で指定する。

## 変更時の参照先

- URL や HTTP Method：`config/routes.rb` と対応する Controller。
- 入力、認可、HTTP Status：`app/controllers/api/v1/`。
- 永続化ルール、関連、検索条件：`app/models/`。
- JSON の公開項目や関連の埋め込み：`app/resources/`。
- 再利用可能な追加検証：`app/validators/`。
- 認証フロー：`app/controllers/api/v1/auth/`、`User`、関連 Initializer。
- エラー JSON：`app/controllers/concerns/error_rendering.rb`。
- メール本文とレイアウト：`app/mailers/` と `app/views/`。
- データベース構造：`db/schema.rb` と `db/migrate/`。
- 環境ごとの差分：`config/environments/`。
