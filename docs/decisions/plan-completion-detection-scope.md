# plan完了検知の対象操作範囲

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-09-05
- **Related Files:** `.claude/hooks/plan-completion-doc-reminder.sh`

## Context

`.claude/plans/active/`から`.claude/plans/completed/`への移動検知は、当初`git mv`/`mv`コマンドのパターンマッチのみだった。

## Decision

`plans/active/`と`plans/completed/`双方がコマンド文字列中に現れるかという判定に加え、`Write`ツールでの`plans/completed/`配下への直接作成検知を追加した。

## Considered Options

- **`git mv`/`mv`コマンドのパターンマッチのみ**（当初案）: `cp`・`rsync`等の他の移動手段や`Write`ツールでの直接作成を取りこぼす
- **採用: コマンド文字列中の両パス出現判定＋`Write`ツール検知の併用**

## Consequences

- より広い移動手段（`cp`・`rsync`・`Write`直接作成）を捕捉できるようになった
