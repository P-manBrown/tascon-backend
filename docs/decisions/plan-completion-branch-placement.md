# planの完了処理のブランチをPR作成済みのブランチの直上に挿入する

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-10-24
- **Related Files:** `.claude/skills/git-spice-workflow/SKILL.md`, `.claude/skills/execution-plan/SKILL.md`, `.claude/plans/completed/plan-completion-branch-placement.md`

## Context

新しい作業のブランチは、未マージのスタックの最上段に積む。planの完了処理のブランチもこれに従うと、上に未レビューの作業が積み上がっているほど、完了処理の変更がmainへ入るのが遅れる。完了処理の変更は、マージ済みのplanの記録を閉じるだけで、上に積まれた作業に依存しない。

## Decision

- 完了処理のブランチは、PR作成済みのブランチのうち最上段のものの直上へ`--insert`で挿入する。PR作成済みのブランチがなければ`main`の直上に挿入する
- 挿入後に上の段をrestackしたら、そのうちpush済みのブランチをpushし直す

## Considered Options

- **最上段に積む（従来）**: 完了処理の変更が、上に積まれた未レビューの作業のマージを待つ
- **PR作成済みのブランチの下（`main`の直上）に挿入する**: PR作成済みのブランチの土台が変わり、rebase・force push・CI再実行が要る。PRのマージ先も変わり、完了処理のPRが通るまでマージ待ちのPRを止める。完了処理はplanのブランチがmainへマージされた時点で行うため、別のPR群をマージしている途中に重なりうる
- **境界をpushの有無にする**: 今後エージェントが自律的に作業すると、レビューが追いつかずPR未作成のブランチが長く残りうる。ローカルの故障で作業を失わないよう、PR作成前でもpushしておく運用を見込む。PR未作成のブランチは、push済みでもCI（`pull_request`のみで起動）が走らず、レビュー中の差分もないため、下に挿入してpushし直すコストが小さい
- **採用: PR作成の有無を境界とし、PR作成済みのブランチのうち最上段のものの直上に挿入する**

## Consequences

- 完了処理のPRは、レビュー中のPRのすぐ後にマージできる
- 挿入した位置より上のpush済み・PR未作成のブランチは、restackのたびにpushし直す必要がある
