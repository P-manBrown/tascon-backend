# Decisions 索引

複数タスクを跨ぐ永続的な設計判断（なぜこの技術・パターンを採用したか等）をここに記録する。書き方の基準は`.claude/rules/decisions-maintenance.md`を参照する。

- そのタスク単体の決定・経緯 → `.claude/plans/`内の各planのDecision Logへ
- AIの振る舞い方針（コーディング原則） → `AGENTS.md` / `.claude/CLAUDE.md`へ
- コードの現状構造（どこに何があるか） → `ARCHITECTURE.md`へ

上記のいずれにも当てはまらない、複数タスクを跨ぐ設計判断が生じた場合にここへファイルを追加する。

- [フィードバック・決定のプロジェクト昇格タイミング](feedback-reflection-timing.md)
- [plan完了検知の対象操作範囲](plan-completion-detection-scope.md)
- [rules遵守確認フックの対象範囲](rules-compliance-check-scope.md)
