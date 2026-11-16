# 計画の完了をPR本文のRelated DocumentsのPlan行の✅で判定する

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-15
- **Related Files:** `.claude/skills/plan-completion/SKILL.md`, `.claude/skills/plan-completion/scripts/judge-completion.sh`, `.claude/skills/plan-completion/scripts/lib/markdown.jq`, `.lefthook/pre-commit/check-plan-completion.sh`, `.claude/hooks/plan-completion-trigger.sh`, `.github/pull_request_template.md`

## Context

[計画の完了をPR本文のRelated Documentsの印で判定する](plan-completion-by-pr-markers.md)では、PR本文の`### Related Documents`のPlan行・Spec行に、✅（計画・設計を最後まで終えたPR）・🏃（それ以外の段のPR）・⬜（計画・設計が無いPR）のどれかを必ず付けると決めた。書く人はPRごとに印を選ぶ必要があり、とくに完了の処理のPRにどの印を付けるかで迷いが生じた。一方、判定はPlan行の✅だけを見て完了を決めており、🏃・⬜は判定に使っていない。

## Decision

- 計画の完了は、PR本文の`### Related Documents`のPlan行と、GitHubのPRの状態だけで判定する。計画を指すPRがすべてmainにマージ済みで、そのうち1つ以上が✅でその計画を指していれば完了とする
- 書く印は✅だけにする。✅はPlan行にだけ付け、計画を最後まで終えたPR（計画の最後の段の、いちばん上のPR）に付ける。完了の処理のPRを含め、ほかのPRのPlan行と、すべてのSpec行には印を付けない。計画・設計が無いPRは、パスに`N/A`と書く（`- Plan: N/A`・`- Spec: N/A`）
- 判定は、印の無いPlan行と、前の決まりの印（🏃・⬜）の付いたPlan行を、どちらも✅の無い行として読む。前の印の付いたPRの本文は書き換えない
- 決まった形に合わないPlan行（全角の空白・末尾の空白・✅・🏃・⬜以外の印等）は、読めない行として人に知らせる
- ✅の付け忘れは、完了にならない側に倒れる。計画を指すPRがすべてmainにマージ済みなのに✅が無い計画は、判定の結果の`missing_marker`で見つけて人に知らせる
- 閉じただけのPRを除外して「全部マージ済み」とはしない。取りやめたPRが計画を指していれば、人が確かめてそのPRの本文を直す
- 進捗表・レビューの報告・実装のまとめを、恒久的な文書として増やさない。検証とレビューの証拠はPRに残す

## Considered Options

- **採用: 印を任意にし、✅・🏃・⬜のどれか、または印の無い行を読める行とする（完了は✅だけで判定する）**: 前の印の付いたPRを書き換えずに読め、読めない行の検出も今のまま保てる。正規表現に、これから書かない印（🏃・⬜）が残る
- **✅と印の無い行だけを読み、🏃・⬜の行は読めない行にする**: 前の決まりで書いたマージ済みのPRが、すべて読めない行として知らされ続ける
- **`Plan:`の前に何が付いていても、✅以外なら✅の無い行と読む**: 印の書き損じ（ほかの絵文字等）が知らされずに完了にならない側へ倒れ、読めない行の検出が弱まる

## Consequences

- 書く人が選ぶ印は、計画を最後まで終えたPRのPlan行の✅だけになる。完了の処理のPRにも印を付けない
- 前の印（🏃・⬜）の付いたPRは、本文を書き換えずに今までどおり判定できる
- 判定は`judge-completion.sh`が`gh api`の読み取りだけで行う。`gh pr merge`の後のhookと、リポジトリの外からの呼び出しのどちらでも同じ結果になる
- ✅の付け忘れ・読めないPlan行・取りやめたPRは自動で直さず、人が本文を直す
- Spec行は今までどおり判定に使わない。Spec行に付いた印は知らせない
