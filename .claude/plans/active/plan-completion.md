# 計画の完了の判定と完了の処理（plan-completion）

## Context/Purpose

計画（`.claude/plans/active/*.md`）が完了したかを、GitHubの情報（PR本文のRelated Documentsの`Plan:`の行、マージ先、状態）から機械的に判定するスクリプトと、完了した計画を`completed/`へ移すときにDecision Logの各項目の扱いとマージ後の確認の結果を残す手順と、その記録の欠けをコミットの前に止める検査を足す。古い仕組み（`execution-plan` skill、`.claude/hooks/plan-completion-check.sh`・`plan-branch-config-check.sh`、`.lefthook/pre-push/check-plan-steps.sh`、`.lefthook/pre-commit/check-docs.sh`）と`.github/pull_request_template.md`は変えず、並べて残す。

- 足すもの: `.claude/skills/plan-completion/`（`SKILL.md`、`scripts/judge-completion.sh`・`scripts/judge_completion.py`・`scripts/check-completion.py`・`scripts/tests/`）、`.claude/rules/plan-completion-local.md`、`lefthook.yml`のpre-commitの2つのジョブ
- `.claude/skills/plan-completion/`には、どのリポジトリでも同じに使える中身だけを置く。このリポジトリ独自の中身は、`.claude/rules/plan-completion-local.md`と`lefthook.yml`の引数に置く
- 試しは`python3 -B -m unittest discover -s .claude/skills/plan-completion/scripts/tests`で走らせる

## Progress

- [x] Step1: `judge-completion.sh`・`judge_completion.py`と試しを足し、実際のリポジトリで判定を走らせる
- [x] Step2: `check-completion.py`と試しを足す
- [ ] Step3: `SKILL.md`・`.claude/rules/plan-completion-local.md`・`lefthook.yml`のジョブを足し、`claude-md-maintenance`の比較テストを行う

## 検証結果

- Step1の試し（2026-11-08）: `python3 -B -m unittest discover -s .claude/skills/plan-completion/scripts/tests`が36件通った
- 実際のリポジトリでの判定（2026-11-08、main 7d702543）: 空の一時フォルダで`judge-completion.sh --repo P-manBrown/tascon-backend`を走らせ、標準出力`{"completed": [], "missing_marker": [], "unreadable": []}`、終了コード0だった。走らせた後もフォルダは空だった
- Step2の試し（2026-11-08）: `python3 -B -m unittest discover -s .claude/skills/plan-completion/scripts/tests`が77件通った（Task 1の36件＋検査の41件）
- 実際のリポジトリの書式での検査（2026-11-08）: 何もステージしない状態で`check-completion.py --link-dir docs/decisions --link-dir .claude/tech-debt`が終了コード0だった。一時のクローン（HEAD 1fe8845f）で`plan-branch-list-completion.md`をcompletedへ正しく移すと終了コード0、記録を1つ欠くと最初の項目の行・`needs exactly one 書き写した/書き写さない line`・`Follow the plan-completion skill to fix the plan before committing.`が出て終了コード1だった（この2つの結果は仕様レビュー担当が再現して確認）

## Decision Log

- 2026-11-07: 完了の記録は、Decision Logの各項目の下に入れ子で`書き写した`か`書き写さない`の1行を書き、マージ後の確認の結果は`## 検証結果`の`### マージ後の判定`に書く。確かめた結果を`検証結果`に書くという節の用途に合い、Decision Logの項目とは位置で対応づくため
- 2026-11-07: PR本文のコードブロックの中の`Plan:`の行は、Planの行として読まず`unreadable`として返す。例示の行で完了が出るのを防ぎつつ、`Plan:`を含む行を無視しないため
- 2026-11-07: `check-completion.py`は、completedの計画を消すコミットを止める。完了の記録を失ったうえで検査を逃れられるため
- 2026-11-07: completedの計画の記録の欠けは、`HEAD`とステージのDecision Logの項目を位置の順で対応づけて判定する。項目の数は減らせないので文の直しでは対応が切れず、項目を途中に足したときだけ誤って止まりうる（最後に足せば止まらない）ため
- 2026-11-07: 試しの`unittest`のジョブには、lefthookの`env`で`PYTHONDONTWRITEBYTECODE=1`を渡す。渡さないと`scripts/tests/__pycache__/`が作業ツリーに残るため
- 2026-11-07: リンクを確かめるこのリポジトリ独自のフォルダ（`docs/decisions`・`.claude/tech-debt`）は、スクリプトに書かず`lefthook.yml`の`--link-dir`で渡す。Skillのフォルダには、どのリポジトリでも同じに使える中身だけを置くため
- 2026-11-07: `scripts/`のファイルはそれだけではClaudeの行動を変えないため、`claude-md-maintenance`の比較テストは、Step3で`SKILL.md`・`.claude/rules/plan-completion-local.md`と合わせて、Step1の最初のコミットの前を変更前として行う

## Validation and Acceptance

- `.claude/skills/plan-completion/`の中（試しを含む）に、このリポジトリ独自の中身（Rails・db・テストのコマンド、`docs/decisions/`・`.claude/tech-debt/`等のこのリポジトリだけのパス）と、リポジトリの外の仕組みへの言及が無い
- `python3 -B -m unittest discover -s .claude/skills/plan-completion/scripts/tests`がすべて通る
- `judge-completion.sh --repo P-manBrown/tascon-backend`を空の一時フォルダで走らせた出力と終了コードが検証結果に記録され、走らせた後もフォルダが空である
- `lefthook.yml`のpre-commitの`jobs`に、globの無い`check-completion.py`のジョブ（`--link-dir docs/decisions --link-dir .claude/tech-debt`付き）と、Skillのフォルダをglobにした試しのジョブがあり、既存のジョブは変わっていない
- `git diff main -- .claude/skills/execution-plan .claude/hooks/plan-completion-check.sh .claude/hooks/plan-branch-config-check.sh .lefthook/pre-push/check-plan-steps.sh .lefthook/pre-commit/check-docs.sh .github/pull_request_template.md`が空
- `claude-md-maintenance`ルールの比較テストを`SKILL.md`と`.claude/rules/plan-completion-local.md`で行い、結果を検証結果に記録している
- マージ後に判定: 次の実際の計画の完了の処理で、`judge-completion.sh`の判定と`check-completion.py`の検査がそのとおりに働く
