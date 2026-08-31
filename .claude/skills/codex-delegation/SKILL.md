---
name: codex-delegation
description: Codexへ実装を委譲する際の具体的な手順（Git操作の分担、Docker不在時の対処、品質チェックの実行方法、成果物確認）を扱うスキル。実装作業をCodexへ委譲する場面、Codexの成果物を確認する場面で使用する。
---

# codex-delegation

Codexへ実装を委譲する際の実務手順を扱う。何を委譲するかの方針は`CLAUDE.md`の「実装の委譲」を参照。

## Git操作の分担

- Git操作（`git reset`、`git stash`、`git commit`、git-spice操作等）→ClaudeがBashで直接実行する
- 理由: Codex実行環境では`.git`が実質read-onlyとなり、Git操作が失敗するため

## 委譲の粒度

- 複数ステップの実装計画→1ステップずつCodexへ委譲する。全ステップの一括委譲は禁止

## Codex実行環境の制約

- Codex実行環境にはDockerがない。`docker compose exec`形式のコマンドは使用不可
- rubocop等の品質チェックはClaudeホストで直接実行する（例: `bundle exec rubocop <target files>`）

## 成果物確認

- Codexの成果物は、コミット前に必ずClaudeが`Read`で確認する
- 対象パスに該当する`.claude/rules/*.md`が自動ロードされるため、規約違反がないか照合できる

## 他skillとの責務分離

- `codex-delegation`はCodexへの委譲そのものの実務手順を担当する
- `git-spice-workflow`はコミット・ブランチ・PR操作を担当する
- `execution-plan`は複雑タスクの計画文書管理を担当する
