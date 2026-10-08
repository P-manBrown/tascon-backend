---
name: doc-gardening
description: `ARCHITECTURE.md`・`docs/decisions/`・`.claude/plans/`・`.claude/tech-debt/`の記述が実装・実際の状態から乖離（陳腐化）していないかを検知し、修正案を提示するスキル。「ドキュメントの陳腐化をチェックして」「doc-gardeningを実行して」等の指示があった場合に使用する。
---

# doc-gardening

既存のドキュメントの陳腐化（実装・実際の状態との乖離）を検知する。書式・必須項目等の形式的な規約準拠は`check-docs.sh`（lefthook pre-commit）が機械的に検証するため、このスキルでは対象としない。

## 対象と参照先

各対象について、記述内容が実コード・実際の状態と矛盾していないかを検出する。対象がディレクトリの場合は配下の全ファイルを確認する。基準ファイルは、その対象が何を記述すべきかを把握するために参照する。

- `ARCHITECTURE.md`（基準: `.claude/rules/architecture-md-maintenance.md`）
- `docs/decisions/`（基準: `.claude/rules/decisions-maintenance.md`）
- `.claude/plans/`（基準: `.claude/rules/plans-maintenance.md`）
- `.claude/tech-debt/`（基準: `.claude/rules/tech-debt-maintenance.md`）

## 手順

- 検出した不整合を一覧化し、それぞれについてどう直すべきか修正案を提示する
- 調査中に、今すぐ対応しないが将来問題化しうる技術的負債・設計上の妥協に気づいた場合、`tech-debt-tracker` skillの手順で記録する

## 変更範囲

- 変更してよい対象: `ARCHITECTURE.md`・`docs/decisions/`・`.claude/plans/`配下のファイル内容修正、`tech-debt-tracker` skill経由での`.claude/tech-debt/`への記録・状態更新・Todoistタスク作成
- 変更してはいけない対象: 実装コード。不整合の原因がコード側にあってもコードは修正せず、ドキュメント側の追従、またはコードとドキュメントのどちらを直すべきかの提案に留める。コード側修正が必要と判断した場合は自律的に進めず、提案として報告する

## 完了条件

- 検出した不整合の一覧化と、それぞれの修正が完了している
