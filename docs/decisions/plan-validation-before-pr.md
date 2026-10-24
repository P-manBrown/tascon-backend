# planの受け入れ判定を最後のPR作成前に行い、マージ前に確かめる

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-10-24
- **Related Files:** `.claude/skills/execution-plan/SKILL.md`, `.claude/skills/git-spice-workflow/SKILL.md`, `.claude/rules/plans-maintenance.md`, `.claude/hooks/plan-completion-check.sh`, `.claude/plans/completed/plan-validation-before-pr.md`

## Context

planの`Validation and Acceptance`は、planの全ブランチをmainへマージした後の完了処理でだけ判定していた。満たさない項目が見つかっても取り消せず、直すには新しいPRが要る。完了処理は記録を閉じる作業のため、不合格を受け入れてしまいやすい。また、マージの手順はplanの完了を確かめないため、planの途中のブランチだけを先にマージできた。

## Decision

- `Validation and Acceptance`は、planの最後のブランチのPRを作る前に判定し、結果をplanの`検証結果`にコミットする。不合格ならPRを作らない。最後のブランチかどうかは、ブランチの先端でplanが`.claude/plans/active/`にあり`Progress`に未チェックがないことで判定する
- 判定の結果はPRのTestingに書かない
- スタックのマージを始める前に、マージする範囲全体について1回だけ、planの全Stepが範囲に揃い、判定に合格した記録があり、判定後に変更が加わっていないことを確かめる。満たさなければマージを始めない
- mainへのマージ後でないと確かめられない項目は、plan作成時に`Validation and Acceptance`へ「マージ後に判定」と明記し、完了処理ではその項目だけを判定する

## Considered Options

- **完了処理で全項目を判定する（従来）**: 不合格を取り消せず、新しいPRが要る
- **マージの直前に判定する**: 不合格のとき、レビュー済みのスタックを直すことになる
- **同じplanのほかのブランチにPR未作成のものがないことで最後のPRを判定する**: まだブランチを作っていないStepを数えられず、途中のStepのPRで判定が走る
- **マージ後でないと判定できない項目を判定時に見分けて記録する**: ローカルで判定できるかはplan作成時にほぼ分かり、明記を漏らしても最後のPR作成前の判定で判定できずに気づける
- **採用: 最後のPR作成前に判定し、マージ前に合格の記録を確かめ、「マージ後に判定」と明記した項目だけを完了処理で判定する**

## Consequences

- 不合格の項目は、レビューの前にスタックの中で直せる
- planの途中のブランチだけを先にマージすることを、エージェントが行うマージでは防げる。GitHubの画面から人が直接マージする場合は防げない。CIで確かめるには、ローカルの`.git/config`にしかないブランチとplanの対応が要る
