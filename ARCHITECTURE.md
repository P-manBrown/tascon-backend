# アーキテクチャ概要

この文書は、コードを探すための大まかな地図である。挙動の authoritative source はコード自体である。

## この文書の目的

Tascon Backend の機能がリポジトリ内のどこに置かれ、主要な層がどう接続されるかを示す。
個々の処理、制約、エンドポイント、レスポンス項目の仕様は扱わない。

## 全体像

Tascon Backend は、タスク管理システムの Rails API サーバーである。通常のリクエストはルーティング定義から Controller、Model、Resource へ流れ、JSON として返される。

- Controller 層：HTTP、認証・認可、入力、処理の組み立て。
- Model 層：永続化、関連、データの整合性、再利用する問い合わせ。
- Resource 層：Model から公開用 JSON への変換。
- Validator 層：複数箇所から利用できる追加の検証。
- 設定：ルーティング、環境設定、Gem の初期設定。
- スキーマとマイグレーション：データベース構造とその変更履歴。
- 拡張：Rails 標準の拡張点に収まらない処理は monkey patch として `monkey_patches` に置く。
- テスト：各層の振る舞いを検証する。

API 専用構成を基本とするが、認証メールと OAuth の補助画面のために Mailer と View も持つ。

## 各層

### Controller 層

HTTP リクエストを受け、認証済みユーザーを起点に Model の操作と Resource の描画を調整する。基底は `ApplicationController`、共通のエラー描画は `ErrorRendering` である。

バージョン付き API は `Api::V1` 名前空間にある。代表的な入口は `Api::V1::TasksController`、`Api::V1::TaskGroupsController`、`Api::V1::ContactsController`、`Api::V1::BlocksController`、`Api::V1::UsersController` である。認証フロー固有の拡張は `Api::V1::Auth` 名前空間に分離され、`Api::V1::Auth::SessionsController`、`Api::V1::Auth::RegistrationsController`、`Api::V1::Auth::PasswordsController`、`Api::V1::Auth::ConfirmationsController`、`Api::V1::Auth::TokenValidationsController`、`Api::V1::Auth::OmniauthCallbacksController` が並ぶ。

### Model 層

Active Record モデルと、永続化データに密接な関連・整合性・検索条件を置く。基底は `ApplicationRecord`、主要なモデルは `User`、`TaskGroup`、`Task`、`Contact`、`Block` である。

中心となる所有関係は `User → TaskGroup → Task` である。`Contact` と `Block` は `User` 間の関係を表し、Avatar は Active Storage が管理する。Model に組み込む拡張は concern として置き、Devise の挙動を上書きする `UserOverride` がその例である。

### Resource 層

Alba を使い、Model を API の JSON 表現へ変換する。共通基底は `ApplicationResource` で、代表的な Resource は `TaskResource`、`TaskGroupResource`、`UserResource`、`AccountResource`、`ContactResource`、`BlockResource` である。

### Validator 層

Rails 標準だけでは表しにくい再利用可能な属性検証を置く。添付ファイルの形式検証には `MimeTypeAndExtensionConsistencyValidator` がある。

### Mailer と View

認証関連メールは `ApplicationMailer` と `DeviseMailer` が担い、テンプレートとレイアウトは View にある。View は通常の API 画面層ではなく、メールと認証フローの補助用途である。

### Job と Channel

`ApplicationJob`、`ApplicationCable::Connection`、`ApplicationCable::Channel` が Active Job と Action Cable の基底となる境界である。アプリケーション固有の非同期処理や Channel を追加する場合は、これらの基底が入口になる。

## ルーティングの地図

URL、HTTP Method、Controller の対応はルーティング定義が authoritative source である。

## レイヤー間の責務

- Controller：HTTP とアプリケーションの境界を担当し、認証・認可、入力解釈、Model の呼び出し、HTTP Status とレスポンス生成を調整する。
- Model：データベース関連、整合性、再利用する検索条件、永続化データに密接な処理を担当する。
- Resource：API に公開する JSON 表現と関連の埋め込みを担当する。
- Validator：Model から利用する再利用可能な追加検証を担当する。

Controller から Resource へは描画に必要な文脈を渡せるが、Resource は永続化や認可を行わない。Model は HTTP の入力形式やレスポンス形式を扱わない。

## 横断的な仕組み

### 認証と認可

認証は Devise、Devise Token Auth、OmniAuth を中心に構成され、設定は各 Gem の初期化ファイル、アプリ固有の HTTP 処理は `Api::V1::Auth` 名前空間、認証主体は `User` にある。

汎用の Policy レイヤーは意図的に置かれていない。データ範囲と認可は、各 Controller が `current_api_v1_user` を起点に関連を辿るか、`ApplicationController` の共通処理を使って制限する。

### JSON とエラー

成功レスポンスの Model 表現は Resource 層に集約する。共通のエラー描画は `ErrorRendering` が担い、リクエスト固有の判断は Controller に残す。

### ページネーション

一覧のページネーションには Pagy を使う。導入点は `ApplicationController` と Pagy の初期化設定である。

### 添付ファイル

`User` の Avatar は Active Storage の境界に置かれる。モデル側の入口は `User`、追加検証は Validator 層、保存先設定は Active Storage の初期設定である。

### オリジン制御

フロントエンドからのクロスオリジンリクエストは rack-cors の初期化設定が境界となり、許可オリジンは環境変数 `FRONTEND_ORIGIN` で指定する。

## 変更時の参照先

- URL や HTTP Method：ルーティング定義と対応する Controller。
- 入力、認可、HTTP Status：`Api::V1` 配下の Controller。
- 永続化ルール、関連、検索条件：Model 層。
- JSON の公開項目や関連の埋め込み：Resource 層。
- 再利用可能な追加検証：Validator 層。
- 認証フロー：`Api::V1::Auth` 配下の Controller、`User`、各 Gem の初期化ファイル。
- エラー JSON：`ErrorRendering`。
- メール本文とレイアウト：`ApplicationMailer`、`DeviseMailer`、対応する View。
- データベース構造：データベーススキーマとマイグレーション。
- 環境ごとの差分：環境別の設定ファイル。
