---
name: tech-debt-tracker
description: 技術的負債・懸念事項を`.claude/tech-debt/`へ記録し、Todoistタスクと紐付けて追跡するスキル。作業中に技術的負債や将来のリスクを発見した場合、既存項目を解消・却下した場合に使用する。
---

# tech-debt-tracker

「今は動いているが将来問題化しうるもの」を`.claude/tech-debt/`へ、1件1ファイルで記録し、Todoistの実行タスクと紐付けて追跡する。

`.claude/plans/`とは別ディレクトリで管理する。plansはexecution-plan（実装計画）専用で、性質の異なるtech-debtを混ぜない。

- `.claude/tech-debt/active/TD-XXX.md`：`Open`・`Accepted`の項目
- `.claude/tech-debt/completed/TD-XXX.md`：`Resolved`の項目

1ファイル1件にしているのは、解消済み項目が増え続けても個々のファイルは小さいまま保たれ、重複チェックや過去の確認時に全件を読み込まず必要なファイルだけ選んで読めるようにするため。単一ファイルにまとめると、`completed`側がどれだけ増えても常に全文を読むしかなくなり、コンテキストを圧迫する。

## 対象範囲

- 今すぐの対応は不要だが、放置すると将来問題として表面化しうる技術的負債・設計上の妥協・既知の制約
- 既に問題として表面化しているものはここではなく通常のTodoistタスク（インボックス起票）で扱う。「今動いているか」が分岐点

## 新規記録の手順

1. `.claude/tech-debt/active/`のファイル一覧（`ls`または`Glob`）を確認する。ファイル名（TD番号）だけでは中身は分からないため、似た対象範囲・カテゴリのものがあれば中身を読んで同等の項目でないか確認する。あれば新規追加せず終了
2. `.claude/tech-debt/active/`・`.claude/tech-debt/completed/`両方のファイル名から最大のTD番号を確認し、`TD-<連番>`を採番する
3. `.claude/tech-debt/active/TD-XXX.md`を以下のフォーマットで新規作成する（本文は日本語で記述する）

```markdown
# TD-XXX — <一行要約>
- **Status:** Open
- **Priority:** High / Medium / Low
- **Category:** Architecture / Code / Test / Performance / Security / Infrastructure / Dependency / Documentation
- **Area:** <対象ファイル・ディレクトリ>
- **Detected:** <YYYY-MM-DD>
- **Todoist Task ID:** <手順4で作成したタスクのID>
- **Description:** <何が負債なのか>
- **Impact:** <なぜ問題なのか。放置すると何が起きるか>
- **Proposed Resolution:** <どう直すか>
- **Related:** <関連ADR/ExecPlan/Issue/PR、無ければ「—」>
```

   - `Description`だけで終わらせず`Impact`まで必ず書く。「何が」だけでは、数か月後に再調査が必要になる
   - `Category`・`Priority`・`Status`は必ず上記の固定値から選ぶ。自由記述にしない（表記揺れで同種の項目が分裂するのを防ぐ）

4. `add-tasks`でTodoistのインボックスへ新規タスクを作成する（プロジェクト・セクション未指定）。タスクのdescriptionに`TD-XXX`のIDと概要を記載する。`tascon-backend`ラベル（リポジトリ判別）を付ける。`Claude`ラベルは付けない（人間のトリアージ前に自動処理対象になるのを防ぐため）
5. 発行されたTodoistタスクIDを、手順3で作成したファイルの`Todoist Task ID`欄へ書き戻す

## 解消・却下時の手順

対応済みのTDは、単にTodoistタスクを完了させるだけでは扱いが終わらない。以下の手順で必ずファイル側も更新する。

- **Resolved（解消済み）**: 対応するコード変更がコミットされた後、コード上で実際に負債が解消されたことを確認する。確認できたら`Status`を`Resolved`に変更し、`Resolution`（実際にどう解決したか、日本語で記述）と`Resolved`（解消日）を追記して、ファイルごと`.claude/tech-debt/active/TD-XXX.md`から`.claude/tech-debt/completed/TD-XXX.md`へ移動する（`git mv`推奨）。Todoistタスク自体の完了操作（`complete-tasks`）はいつも通り行ってよいが、それとは別にこの更新を必ず行う（タスク完了＝負債解消の確認、ではない）
- **Accepted（意図的に残す）**: 検討の結果、対応せず現状のまま残すと判断した場合は`Status`を`Accepted`に変更し、その判断理由を`Resolution`相当の記述として追記する。ファイルは移動せず`.claude/tech-debt/active/`内に留める（今も意識し続けるべき項目のため）
- どちらの場合も**ファイルを削除しない**。TD番号もそのまま維持する。削除すると、将来別セッションが同じ問題を再発見・再提起してしまう
- 更新のタイミングは、execution-plan完了時・該当Todoistタスクの完了処理時など、対応が実際にコードへ反映された直後に行う

## 他skillとの関係

- `todoist-task-runner`: 作業中に派生タスクを発見した場合、このskillの手順でtracker記録とTodoist作成を行う
- `execution-plan`: 完了処理時に、実装過程で生じた設計上の妥協・既知の制約があればこのskillの手順で新規記録し、解消した既存の負債があれば`completed/`へ移動する
- `doc-gardening`: 調査中に技術的負債を発見した場合、このskillの手順で新規記録する
