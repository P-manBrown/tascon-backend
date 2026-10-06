---
name: codex-delegation
description: Codexへ実装を委譲する際の具体的な手順を扱うスキル。実装作業をCodexへ委譲する場面、Codexの成果物を確認する場面で使用する。
---

# Codexへの委譲

Codexへ実装を委譲する際の実務手順。

## Git操作の分担

- Git操作（`git reset`、`git stash`、`git commit`、git-spice操作等）→ClaudeがBashで直接実行する

## 成果物確認

- Codexの成果物は、コミット前に必ずClaudeが`Read`で確認する
- `Read`実行時に対象パスの`.claude/rules/*.md`が自動ロードされた場合、その内容に従えているか明示的に確認する
- レビューで問題を見つけた場合、コミットせず修正をCodexへ再委譲する
- これは実装レベルの粗を先に潰す工程であり、要件充足・ビジネスロジック観点での人間レビュー（`todoist-task-runner`の「最終確認する」タスク）を代替しない
