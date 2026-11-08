# 計画の完了をPR本文のRelated Documentsの印で判定する

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-03
- **Related Files:** `.claude/skills/plan-completion/SKILL.md`, `.claude/skills/plan-completion/scripts/judge-completion.sh`, `.claude/skills/plan-completion/scripts/check-completion.sh`, `.claude/hooks/plan-completion-trigger.sh`, `.github/pull_request_template.md`

## Context

計画の完了は、ローカルの`.git/config`のブランチ設定`branch.<name>.plan`と、計画の`Progress`のチェックで判定していた。この対応はその環境にしか無く、GitHubの画面からのマージや別の環境、リポジトリの外からは判定できない。また、完了の処理の結果を機械的に確かめる仕組みが無く、`Decision Log`の転記漏れや、項目を削ってから計画を移す変更を止められなかった。

## Decision

- 計画の完了は、PR本文の`### Related Documents`のPlan行と、GitHubのPRの状態だけで判定する。計画を指すPRがすべてmainにマージ済みで、そのうち1つ以上が✅でその計画を指していれば完了とする。✅は計画を最後まで終えたPR（計画の最後の段の、いちばん上のPR）にだけ付け、それ以外の段のPRは🏃、計画が無いPRは`⬜ Plan: N/A`と書く
- ✅の付け忘れは、完了にならない側に倒れる。計画を指すPRがすべてmainにマージ済みなのに✅が無い計画は、判定の結果の`missing_marker`で見つけて人に知らせる
- 閉じただけのPRを除外して「全部マージ済み」とはしない。取りやめたPRが計画を指していれば、人が確かめてそのPRの本文の印を直す
- 進捗表・レビューの報告・実装のまとめを、恒久的な文書として増やさない。検証とレビューの証拠はPRに残す

## Considered Options

- **計画とブランチの対応をブランチ設定に持つ（従来）**: 対応がローカルの`.git/config`にしか無く、GitHubの画面からのマージや別の環境、リポジトリの外では判定できない
- **閉じたPRを除外して判定する**: 取りやめたPRと、閉じて作り直している途中のPRを見分けられず、作業の残る計画を完了と誤る
- **採用: PR本文の印とPRの状態で判定する**: GitHubの読み取りだけでどこからでも同じに判定でき、印の誤りは完了にならない側に倒れる

## Consequences

- 判定は`judge-completion.sh`が`gh api`の読み取りだけで行う。`gh pr merge`の後のhookと、リポジトリの外からの呼び出しのどちらでも同じ結果になる
- ✅の付け忘れ・読めないPlan行・取りやめたPRは自動で直さず、人が本文の印を直す
- 完了の処理の記録の欠けは、pre-commitの`check-completion.sh`がコミットの前に止める
- 計画の書式から`Progress`・`検証結果`の節を除き、検証の結果はPRのTestingに書く
