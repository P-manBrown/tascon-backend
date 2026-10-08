# rules遵守確認フックの対象範囲

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-09-05
- **Related Files:** `.claude/hooks/rules-compliance-check-reminder.sh`, `.claude/rules/claude-md-maintenance.md`

## Context

当初は`.claude/rules/`・`.claude/skills/`配下の編集のみを対象にした専用チェックだった。

## Decision

`.claude/rules/*.md`各ファイルのfrontmatter`paths:`に一致する変更全般を対象にする汎用チェックへ拡張した。`claude-md-maintenance.md`自身の`paths`に`.claude/rules/**/*.md`等が含まれるため、専用チェックはこの汎用チェックに包含される。

## Considered Options

- **Pythonでの`**`globパターンマッチ**（当初実装）: 実行環境にPythonが存在する保証がないため採用を撤回
- **採用: bashの`[[ $str =~ $regex ]]`（正規表現マッチ）**: 追加インタプリタへの依存を避けられる

## Consequences

- `.claude/rules/`・`.claude/skills/`専用のチェックは不要になった（汎用チェックに包含されるため）
- 新しいルールファイルを追加するだけで、対象範囲の拡張がフック側の実装変更なしに行える
