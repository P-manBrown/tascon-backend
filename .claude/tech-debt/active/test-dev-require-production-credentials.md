# テストと開発でも本番のcredentialsを読むため、master.keyが作業場所とCIに要る
- **Status:** Open
- **Priority:** Medium
- **Category:** Security
- **Area:** `config/initializers/devise.rb`、`config/initializers/omniauth.rb`、`.worktreeinclude`、`.github/workflows/ci.yml`（`RAILS_MASTER_KEY`）
- **Detected:** 2026-11-20
- **Description:** 起動時に読む設定（`devise.rb`・`omniauth.rb`）が、どの環境でも`Rails.application.credentials`の本番の秘密（Gmail・Twitter・Google）を読む。そのため、テスト・開発でも`config/master.key`（または`RAILS_MASTER_KEY`）が要る。現在は、`.worktreeinclude`で`config/master.key`を各作業場所へ写し、CIにも`RAILS_MASTER_KEY`のsecretを置いている。本番の秘密を解く鍵が、作業場所とCIに置かれている。
- **Impact:** 本番の秘密を解く鍵が、作業場所（複数のworktree）とCIに広がり、漏れたときの影響が本番の秘密全体に及ぶ。鍵が無い環境ではテスト・開発の起動自体が失敗する。
- **Proposed Resolution:** Railsの環境ごとのcredentials（`config/credentials/test.yml.enc`・`development.yml.enc`と、それぞれの鍵）にする。テストは中身のないダミーの値、開発は開発用の値にし、本番の鍵は本番だけに置く。直した後、`.worktreeinclude`の`config/master.key`とGitHub Actionsの`RAILS_MASTER_KEY`を外し、CIはテスト用の鍵だけを使う。直す時期は未定。
- **Related:** —
