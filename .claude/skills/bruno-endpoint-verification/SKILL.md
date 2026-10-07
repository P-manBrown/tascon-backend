---
name: bruno-endpoint-verification
description: APIエンドポイントの新規追加・変更時にBruno CLIで動作検証するスキル。「エンドポイントを検証して」「Bruno CLIでテストして」等の明示的な指示に加え、エンドポイント追加・変更作業の完了報告前にも使用する。
---

# bruno-endpoint-verification

APIエンドポイントの追加・変更を、正規のBruno Collectionリクエストで検証する。

## 検証ルール

- curlのみの検証で完了とせず、`.bruno/Collection`配下の適切な`.bru`リクエストファイルを使用して必ず`bru run`で検証する
- 新規・変更エンドポイントごとに対応するCollection内の`.bru`ファイルを追加・更新する。使い捨ての一時ファイルのみで済ませない

## サーバー起動・停止

- `.devcontainer/compose.devcontainer.yml`が`api` serviceの`command`をoverrideするため、Pumaは自動起動しない。`bin/bundle exec puma -C ./config/puma.rb &`で手動起動する
- 作業完了後→`pkill -f puma`で起動したRails serverを必ず停止する

## Bruno CLI接続

- `.env`の`WEB_HOST=localhost`はそのまま使用しない。nginx→Pumaへ接続するため、`--env-var "BASE_URL=http://host.docker.internal/api"`を指定する
- Sign Inから対象requestをchainし、BEARER_TOKENを引き継ぐ: `bru run "Auth/Sign In.bru" <target.bru> --env Development --env-var BASE_URL=http://host.docker.internal/api --env-var FRONTEND_ORIGIN=<origin>`
- `--env Development`実行時、Sign Inのpost-response scriptが実tokenを`.bruno/Collection/environments/Development.bru`へ書き込む。実行後に`git status`を確認し、scope外の変更なら同ファイルを`git restore`する

## 変更範囲

- 変更してよい対象: `.bruno/Collection`配下で追加・更新するrequestファイル、一時的なserver起動・停止
- 変更してはいけない対象: `.env`、実装コード
