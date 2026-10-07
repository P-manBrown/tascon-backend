---
paths:
  - "app/**"
  - "config/**"
  - "db/**"
---

# Codexへの実装委譲

- 実装（ファイル編集・コミット作成）→Codexへ委譲。Claudeは直接編集しない
- Git操作（`git reset`、`git stash`、`git commit`、git-spice操作等）→ClaudeがBashで直接実行。Codex実行環境では`.git`が実質read-onlyとなり、Git操作が失敗するため
- 複数ステップの実装計画→1ステップずつCodexへ委譲。全ステップの一括委譲禁止
- Codex実行環境にはDockerなし。`docker compose exec`形式のコマンドは使用不可
- rubocop等の品質チェック→Claudeホストで直接実行（例: `bundle exec rubocop <target files>`）
