---
name: tech-debt-tracker
description: 技術的負債・懸念事項を`.claude/tech-debt/`へ記録し、Todoistタスクと紐付けて追跡するスキル。作業中に技術的負債・設計上の妥協・既知の制約を発見した場合、既存tech-debtを解消・却下した場合に使用する。
---

# tech-debt-tracker

技術的負債・設計上の妥協・既知の制約を`.claude/tech-debt/`へ、1件1ファイルで記録し、Todoistの実行タスクと紐付けて追跡する。ファイル書式・保存規則は`.claude/rules/tech-debt-maintenance.md`を参照する。

## 新規記録の手順

1. `.claude/tech-debt/active/`のファイル一覧を確認する。似た対象範囲・カテゴリのものがあれば中身を読んで同等の項目でないか確認する。同等の項目であれば新規追加せず終了
2. `.claude/tech-debt/active/<slug>.md`を`tech-debt-maintenance`ルールの形式で新規作成する
3. `todoist-task-conventions` skillに従い、`add-tasks`でTodoistのインボックスへ新規タスクを作成する。タスクのdescriptionにファイル名と概要を記載する
4. 発行されたTodoistタスクIDを、手順2で作成したファイルの`Todoist Task ID`欄へ書き戻す

## 解消・却下時の手順

対応済みのtech-debtは、単にTodoistタスクを完了させるだけでは扱いが終わらない。以下の手順で必ずファイル側も更新する。

- **Resolved（解消済み）**: コード上で実際に負債が解消されたことを確認する。確認できたら`Status`を`Resolved`に変更し、`Resolution`と`Resolved`を追記して、ファイルごと`.claude/tech-debt/active/<slug>.md`から`.claude/tech-debt/completed/<slug>.md`へ移動
- **Accepted（意図的に残す）**: 検討の結果、対応せず現状のまま残すと判断した場合は`Status`を`Accepted`に変更し、その判断理由を`Resolution`相当の記述として追記する。ファイルは移動せず`.claude/tech-debt/active/`内に留める
- どちらの場合も**ファイルを削除しない**。ファイル名もそのまま維持する
