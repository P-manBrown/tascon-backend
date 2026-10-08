---
name: doc-gardening
description: `ARCHITECTURE.md`・`docs/decisions/`・`.claude/plans/`・`.claude/tech-debt/`の記述がそれぞれの一次ルール・実装・実際の状態と乖離していないかを検知し、修正案を提示するスキル。「ドキュメントの陳腐化をチェックして」「doc-gardeningを実行して」等の指示があった場合に加え、大きめのPR作成前後にも使用する。
---

# doc-gardening

既存のドキュメントの健全性を維持する。

## 対象と確認基準

- `ARCHITECTURE.md` → 基準: `.claude/rules/architecture-md-maintenance.md`
- `docs/decisions/` → 基準: `.claude/rules/decisions-maintenance.md`
- `.claude/plans/` → 基準: `.claude/skills/execution-plan/SKILL.md`
- `.claude/tech-debt/` → 基準: `.claude/skills/tech-debt-tracker/SKILL.md`

## 調査方法

- 各対象について、対応する基準に沿っているか、かつ実コード・実際の状態と矛盾していないかを確認する
- `ARCHITECTURE.md`: 記載されたレイヤー構成・モジュール構成と、リポジトリ全体の実際のコード構造を突き合わせる
- `docs/decisions/`・`.claude/tech-debt/`: 記録された`Status`と実際の対応状況の食い違いを確認する
- `.claude/plans/active/`は完了済みなのに`completed/`未移動がないか、`.claude/plans/completed/`は横断的な決定が`docs/decisions/`へ未抽出のまま残っていないかを確認する
- 検出した不整合を一覧化し、それぞれについてどう直すべきか修正案を提示する
- 調査中に、今すぐ対応しないが将来問題化しうる技術的負債・設計上の妥協に気づいた場合、`tech-debt-tracker` skillの手順で記録する

## 変更範囲

- 変更してよい対象: `ARCHITECTURE.md`・`docs/decisions/`・`.claude/plans/`配下のファイル内容修正、`tech-debt-tracker` skill経由での`.claude/tech-debt/`への記録・状態更新・Todoistタスク作成。検出した不整合のうちドキュメント側の追従で解決するものは、ユーザーへ確認を求めずブランチ作成〜コミットまで自律的に行う
- 変更してはいけない対象: 実装コード。不整合の原因がコード側にあってもコードは修正せず、ドキュメント側の追従、またはコードとドキュメントのどちらを直すべきかの提案に留める。コード側修正が必要と判断した場合は自律的に進めず、提案として報告する

## 完了条件

- 検出した不整合の一覧化と、それぞれの修正案の提示が完了している
