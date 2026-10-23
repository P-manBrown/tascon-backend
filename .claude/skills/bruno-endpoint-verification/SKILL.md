---
name: bruno-endpoint-verification
description: APIエンドポイントの新規追加・変更時にBruno CLIで動作検証するスキル。「エンドポイントを検証して」「Bruno CLIでテストして」等の明示的な指示に加え、エンドポイント追加・変更作業の完了報告前にも使用する。
---

# Bruno CLIの使用方法

APIエンドポイントの追加・変更を、正規のBruno Collectionリクエストで検証する。

## 検証ルール

- curlのみの検証で完了とせず、`.bruno/Collection`配下の適切な`.bru`リクエストファイルを使用して必ず`bru run`で検証する
- 新規・変更エンドポイントごとに対応するCollection内の`.bru`ファイルを追加・更新する。使い捨ての一時ファイルのみで済ませない

## サーバー起動・停止

- `.devcontainer/compose.devcontainer.yml`が`api` serviceの`command`をoverrideするため、Pumaは自動起動しない。`bin/bundle exec puma -C ./config/puma.rb &`で手動起動する
- git worktree（`.claude/worktrees/`配下等）から起動する場合は、worktreeのルートで以下を行う
  - `pgrep -af '^puma '`で他のPumaが起動していないことを確認し、起動していれば`pkill -f '^puma '`で停止する。同じsocketを使用するPumaは1つにする
  - `MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")`でメインcheckoutのパスを取得する
  - nginxが接続するsocketはメインcheckoutの`tmp/sockets`（名前付きvolume `puma-sockets`）に置く。`-b`で`config/puma.rb`の`bind`を置き換え、worktreeには`tmp/sockets`を作成しない
  - `config/master.key`をworktreeへコピー・symlinkせず、起動コマンドの`RAILS_MASTER_KEY`で渡す。キーを`echo`・`env`・`printenv`等で出力せず、閲覧ツールでも読み取らない
  - `RAILS_MASTER_KEY="$(cat "$MAIN/config/master.key")" bin/bundle exec puma -C ./config/puma.rb -b "unix://$MAIN/tmp/sockets/puma.sock" &`でバックグラウンド起動する
  - リクエストはworktreeのコードで処理される。ログはworktreeの`log/development.log`で確認する
- 作業完了後→`pkill -f '^puma '`で起動したRails serverを必ず停止する。`-f puma`のように先頭で固定しないパターンは使わない

## Bruno CLI接続

- `FRONTEND_ORIGIN`は起動中のPumaが読み込んだ値に合わせる。worktreeから起動したPumaはworktreeの`.env*`を読み込むため、メインcheckoutの`.env.local`と異なる場合がある。値が一致しないとSign Inが400になる
- `.env`の`WEB_HOST=localhost`はそのまま使用しない。nginx→Pumaへ接続するため、`--env-var "BASE_URL=http://host.docker.internal/api"`を指定する
- Sign Inから対象requestをchainし、BEARER_TOKENを引き継ぐ: `bru run "Auth/Sign In.bru" <target.bru> --env Development --env-var BASE_URL=http://host.docker.internal/api --env-var FRONTEND_ORIGIN=<origin>`
- Sign Inのpost-response scriptは`bru.setVar`でBEARER_TOKENをランタイム変数として設定する。ディスクへ永続化されないため、実行後の`Development.bru`のgit restoreは不要

## 変更範囲

- 変更してよい対象: `.bruno/Collection`配下で追加・更新するrequestファイル、一時的なserver起動・停止
- 変更してはいけない対象: `.env`、実装コード
