# リマインダー型hookの廃止

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-09-08
- **Related Files:** `.claude/settings.json`, `.claude/hooks/check-docs-hook.sh`, `.lefthook/pre-commit/check-docs.sh`, `.claude/skills/execution-plan/SKILL.md`

## Context

plan完了時のドキュメント処理、`.claude/rules/*.md`の遵守確認、`AskUserQuestion`で得た設計判断の記録は、それぞれhookで促していた。いずれもcommand hookの`additionalContext`、またはprompt hookによって、メインエージェントへ確認を促す文言を注入するだけの仕組みだった。注入された文言は他のコンテキストに埋もれやすく、実際に何度も見落とされていた。

## Decision

文言を注入して確認を促すだけのhookはすべて廃止した。hookは、失敗時にexit code 2でブロックする決定的な処理に限定する。廃止したhookの役割は次の手段で担う。

- ルールの遵守確認: `.claude/rules/*.md`の`paths`による自動ロードに任せる
- ドキュメントの形式チェック: `check-docs.sh`に集約し、lefthook pre-commitと、Edit/Write後のPostToolUse hookで実行する
- plan完了時の処理・設計判断の記録漏れ: `execution-plan` skillの完了処理で、claude-memを照会して監査する

## Considered Options

- **command hookの`additionalContext`による注入を維持**: 文言が埋もれ、見落としを防げない。確実に動作しない仕組みはノイズになる
- **prompt hookへの置き換え**: 判定はLLMに任せられるが、結果を伝える方法は文言の注入であり、埋もれる問題は解決しない
- **採用: 注入型hookを廃止し、決定的なチェックと手順に置き換える**

## Consequences

- 確認の促しは自動では行われない。遵守はネイティブのrules機構と各skillの手順に依存する
- 形式違反は、編集直後とコミット時の両方で機械的にブロックされる
- 新しいhookを追加する場合は、文言の注入ではなくブロックまたは自動修正で完結するものに限る
