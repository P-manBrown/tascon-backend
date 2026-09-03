---
name: todoist-task-conventions
description: Todoistで新規タスクを作成する際のラベル付与・子タスク構成ルールを扱うスキル。Todoistタスクを新規作成する場面（機能実装タスク、技術的負債の記録、派生タスクの起票等）で使用する。
---

# todoist-task-conventions

Todoistで新規タスクを作成する際の共通ルール。個々のワークフローskill（`todoist-task-runner`、`tech-debt-tracker`等）は、タスク作成時にここを参照する。

## ラベル

- `tascon-backend`: リポジトリ判別用。このリポジトリに関連する新規タスクには常に付与する（複数リポジトリのタスクが同じTodoist上に混在するため必要）
- `Claude Code`: 人間がAI処理を許可した明示的opt-in。`tascon-backend`だけでは「AIに処理してほしいタスクかどうか」を判定できないため必要（`Claude`という別ラベルはClaude.ai経由での処理用に別途温存しており、これとは別物）
  - 人間が明示的に許可する場合のみ付与する
  - AIが自ら新規作成するタスク（派生タスクの起票、技術的負債の記録等）には付けない。人間のトリアージを経ないタスクに付けると、次回の対象タスク取得で意図せず自動処理対象になってしまうため

## 子タスク構成

- **機能実装タスク**（`execution-plan`の対象になるもの）: 親タスクに「作業する（AI）」「最終確認する（人間）」「プルリクエストする（人間）」の3つを必ず付与する
- **技術的負債・派生タスクの記録**（`tech-debt-tracker`経由等）: 子タスクは付けない。descriptionに詳細を記載するのみでよい

## 他skillとの関係

- `todoist-task-runner`: 機能実装タスクの新規作成時、このskillのルールに従う
- `tech-debt-tracker`: 技術的負債発見時のタスク作成、このskillのルールに従う
