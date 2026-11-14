# planの完了処理のブランチも依存で切る場所を決める

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-11-13
- **Related Files:** `.claude/skills/git-spice-workflow/SKILL.md`, `.claude/skills/plan-completion/SKILL.md`, `.claude/plans/active/new-work-branch-placement.md`

## Context

[planの完了処理のブランチをPR作成済みのブランチの直上に挿入する](plan-completion-branch-placement.md)は、新しい作業のブランチを未マージのスタックの最上段に積む決まりを前提に、完了処理のブランチだけを例外として途中へ`--insert`で挿入すると定めた。その後、新しい作業のブランチは、ほかの作業に依存しなければ`main`から切る別のスタックにし、依存する作業だけ依存する作業のスタックの上に積む決まりに変わった（`.claude/plans/active/new-work-branch-placement.md`）。完了処理の変更は、マージ済みのplanの記録を閉じるだけで、ほかの未マージの作業に依存しない。

## Decision

- 完了処理のブランチも、ほかの作業と同じく依存で切る場所を決める。依存しなければ`main`から切る
- 完了処理のブランチを、PR作成済みのブランチの直上へ挿入する例外はなくす

## Considered Options

- **例外を残し、PR作成済みのブランチのうち最上段のものの直上に挿入する**: スタックが複数並ぶと「最上段のもの」がどのスタックを指すか定まらない。完了処理が依存しない作業のため、挿入せず`main`から切れば、上の段のrestackとpushし直しも要らない
- **採用: 例外をなくし、依存しなければ`main`から切る**

## Consequences

- 完了処理のPRは、ほかの未マージのスタックと切り離して、独立にレビュー・マージできる
- 挿入に伴う、上の段のrestackとpush済みブランチのpushし直しがなくなる
