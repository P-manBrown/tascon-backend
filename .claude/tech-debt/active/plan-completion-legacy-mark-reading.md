# 完了判定スクリプトが前の印（🏃・⬜）の書き方のPRも読んでいる
- **Status:** Open
- **Priority:** Low
- **Category:** Code
- **Area:** `.claude/skills/plan-completion/scripts/lib/markdown.jq`, `.claude/skills/plan-completion/scripts/judge-completion.sh`, `.claude/skills/plan-completion/scripts/find-completion-pr.sh`, `.claude/skills/plan-completion/scripts/tests/test-judge-completion.sh`, `.claude/skills/plan-completion/scripts/tests/test-find-completion-pr.sh`
- **Detected:** 2026-11-16
- **Description:** 完了の判定は、PR本文のRelated DocumentsのPlan行の✅だけで決める（[計画の完了をPR本文のRelated DocumentsのPlan行の✅で判定する](../../../docs/decisions/plan-completion-by-check-mark-only.md)）。一方、完了判定のスクリプト（`judge-completion.sh`・`find-completion-pr.sh`）が使う`lib/markdown.jq`の`plan_lines`は、前の書き方の印🏃・⬜が付いたPlan行も読む（`_plan_line_re`の`(?:(?<mark>✅|🏃|⬜) )?`と、`plan_lines`・`unreadable_lines`のコメント）。前の書き方のPRが今も指す計画を判定できるようにするためである。この読み取りを確かめる試しも残っている。`tests/test-judge-completion.sh`は🏃・⬜のPlan行を含むPR本文で判定の結果を確かめ（66・73・86行目付近）、読めない行の試し（98・100行目付近）と、`tests/test-find-completion-pr.sh`（19行目付近）にも🏃の行がある。
- **Impact:** 前の書き方のPRが指す計画が残っている間は必要な読み取りである。すべて`completed`へ移った後も残すと、使われない分岐と試しがスクリプトに残り、現在の書き方（✅の有無だけ）を読む人が🏃・⬜の意味を気にする必要が生じる。
- **Proposed Resolution:** 前の書き方のPRが指す`active`の計画がすべて完了して`.claude/plans/completed/`へ移った時点で、`lib/markdown.jq`の`_plan_line_re`から🏃・⬜を外し、`plan_lines`・`unreadable_lines`のコメントも直す。あわせて、🏃・⬜の読み取りを確かめる上記の試しを外す。外した後は🏃・⬜が付いた行が読めない行（`unreadable`）になるため、読めない行の試しは🏃の行を「読めない行」として期待する形に直す。
- **Related:** [計画の完了をPR本文のRelated DocumentsのPlan行の✅で判定する](../../../docs/decisions/plan-completion-by-check-mark-only.md)
