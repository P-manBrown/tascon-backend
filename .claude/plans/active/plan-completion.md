# 計画の完了の判定と完了の処理（plan-completion）

## Context/Purpose

計画（`.claude/plans/active/*.md`）が完了したかを、GitHubの情報（PR本文のRelated Documentsの`Plan:`の行、マージ先、状態）から機械的に判定するスクリプトと、完了した計画を`completed/`へ移すときにDecision Logの各項目の扱いとマージ後の確認の結果を残す手順と、その記録の欠けをコミットの前に止める検査を足す。古い仕組み（`execution-plan` skill、`.claude/hooks/plan-completion-check.sh`・`plan-branch-config-check.sh`、`.lefthook/pre-push/check-plan-steps.sh`、`.lefthook/pre-commit/check-docs.sh`）と`.github/pull_request_template.md`は変えず、並べて残す。

- 足すもの: `.claude/skills/plan-completion/`（`SKILL.md`、`scripts/judge-completion.sh`・`scripts/judge_completion.py`・`scripts/check-completion.py`・`scripts/tests/`）、`.claude/rules/plan-completion-local.md`、`lefthook.yml`のpre-commitの2つのジョブ
- `.claude/skills/plan-completion/`には、どのリポジトリでも同じに使える中身だけを置く。このリポジトリ独自の中身は、`.claude/rules/plan-completion-local.md`と`lefthook.yml`の引数に置く
- 試しは`python3 -B -m unittest discover -s .claude/skills/plan-completion/scripts/tests`で走らせる

## Progress

- [x] Step1: `judge-completion.sh`・`judge_completion.py`と試しを足し、実際のリポジトリで判定を走らせる
- [x] Step2: `check-completion.py`と試しを足す
- [x] Step3: `SKILL.md`・`.claude/rules/plan-completion-local.md`・`lefthook.yml`のジョブを足し、`claude-md-maintenance`の比較テストを行う

## 検証結果

- Step1の試し（2026-11-08）: `python3 -B -m unittest discover -s .claude/skills/plan-completion/scripts/tests`が36件通った
- 実際のリポジトリでの判定（2026-11-08、main 7d702543）: 空の一時フォルダで`judge-completion.sh --repo P-manBrown/tascon-backend`を走らせ、標準出力`{"completed": [], "missing_marker": [], "unreadable": []}`、終了コード0だった。走らせた後もフォルダは空だった
- Step2の試し（2026-11-08）: `python3 -B -m unittest discover -s .claude/skills/plan-completion/scripts/tests`が77件通った（Task 1の36件＋検査の41件）
- 実際のリポジトリの書式での検査（2026-11-08）: 何もステージしない状態で`check-completion.py --link-dir docs/decisions --link-dir .claude/tech-debt`が終了コード0だった。一時のクローン（HEAD 1fe8845f）で`plan-branch-list-completion.md`をcompletedへ正しく移すと終了コード0、記録を1つ欠くと最初の項目の行・`needs exactly one 書き写した/書き写さない line`・`Follow the plan-completion skill to fix the plan before committing.`が出て終了コード1だった（この2つの結果は仕様レビュー担当が再現して確認）
- Step3の範囲確認（2026-11-08）: 試しが77件通った。`tascon|backend|rails`のgrepが`.claude/skills/plan-completion`で何も出さず終了コード1。古い仕組み6つの`git diff main`が0行。`lefthook.yml`の差分は足した9行だけで削除なし（計画は10行と書いたが、ブロックは9行）
- 比較テスト（2026-11-08、`claude-md-maintenance`の手順）: 対象は`SKILL.md`と`.claude/rules/plan-completion-local.md`。Task 3は変更をコミットしていないため、変更前はTask 1の最初のコミット（a6fa5564）の1つ前（main 7d702543）をdetachして取った。変更前は`plan-completion`のSkillを呼べず（`Unknown skill`）、変更後は`判定`と`コミット前の検査`を引用できた（`touch`して35秒以上おいた後）。ルールの差し込みはP4の答えの根拠に`plan-completion-local.md`が出て確かめた。判定はすべて「変更前に無く変更後にある」行動の有無だけで行った
  - P1（完了の判定）: 変更前は専用スクリプトに触れず、`git config`と`gh pr view`を挙げ、終了コード4を`gh`の認証要求と解釈した。変更後は`judge-completion.sh --repo P-manBrown/tascon-backend`を挙げ、4なら`missing_marker`・`unreadable`のPR本文を直し0になるまで完了の処理をしないと答えた。→ 指示を残した
  - P2（Decision Logと検証結果の書き方）: 変更前は自由文の1行で、`書き写した/書き写さない`の形も`結果:`/`根拠:`の形も無かった。変更後は1つ目の下に`- 書き写した: \`docs/decisions/...\``、2つ目の下に`- 書き写さない: <理由>`、`### マージ後の判定`に条件の本文と`結果:`・`根拠:`を書いた。→ 指示を残した
  - P3（Plan行）: 変更前は最後のStepのPRを🏃と答え、古いPRを閉じる前の手順は答えられなかった。変更後は✅（active）・✅（completed）と、閉じる前に本文の`Plan:`の行を消すと答えた。→ 指示を残した
  - P4（ブランチの置き場所・テスト）: 変更前は`git-spice-workflow`の`--insert`と`bin/bundle exec rspec`を挙げ、`plan-completion-branch-placement.md`も`AGENTS.md`も挙げなかった。変更後は`docs/a`の直上に挿入し、根拠に`plan-completion-branch-placement.md`を挙げ、テストは`AGENTS.md`と各skillに従うと答えた。→ 指示を残した（置き場所の結論は古い仕組みと同じで、差は根拠にする文書。古い仕組みも同じ行動を引き出す可能性はあるが、この比較では差が出たので取り消さない）
  - P5（検査に止められたときの直し方）: 変更前は書式不明のまま自由な直し方を推測した。変更後は項目の下に`書き写した`か`書き写さない`をちょうど1行書き、`git add`し直してコミットし直すと答えた。→ 指示を残した
  - 取り消した指示は無い。要求REQ-007・REQ-015・AC-5は満たす
- lefthookでの検査（2026-11-08）: Step3のコミット（6f477b07）で`check-plan-completion`と`test-plan-completion`が通った。`lefthook-debride-scope-change.md`をactiveから外すだけのステージで`lefthook run pre-commit`は`check-plan-completion`が`.claude/plans/active/lefthook-debride-scope-change.md: deleted without adding .claude/plans/completed/lefthook-debride-scope-change.md (move the plan instead)`で失敗した（ステージは戻して`git status --short`は空）。最初のコミットの試しは、hookが渡す`GIT_DIR`・`GIT_INDEX_FILE`を試しが引き継ぎ、本物のリポジトリに`commit`というコミットが積まれて失敗した。コミットを`21a5ee8f`へ`reset --mixed`で戻し、試しから`GIT_*`を外して直した
- Step3の受け入れ条件の判定（2026-11-08、「マージ後に判定」を除く、いずれも再実行）:
  - Skillのフォルダに独自の中身が無い: `tascon|backend|rails|docs/decisions|tech-debt`のgrepが何も出さず終了コード1。満たす
  - 試しがすべて通る: 77件、OK。満たす
  - `judge-completion.sh`の出力と終了コードの記録: Step1の項目に記録済み。満たす
  - lefthookのジョブ: globの無い`check-plan-completion`（`--link-dir`2つ付き）とSkillのフォルダをglobにした`test-plan-completion`があり、既存のジョブの削除は0行。満たす
  - 古い仕組みと`pull_request_template.md`の`git diff main`: 0行。満たす
  - 比較テストの記録: 上の比較テストの項目。満たす

## Decision Log

- 2026-11-07: 完了の記録は、Decision Logの各項目の下に入れ子で`書き写した`か`書き写さない`の1行を書き、マージ後の確認の結果は`## 検証結果`の`### マージ後の判定`に書く。確かめた結果を`検証結果`に書くという節の用途に合い、Decision Logの項目とは位置で対応づくため
- 2026-11-07: PR本文のコードブロックの中の`Plan:`の行は、Planの行として読まず`unreadable`として返す。例示の行で完了が出るのを防ぎつつ、`Plan:`を含む行を無視しないため
- 2026-11-07: `check-completion.py`は、completedの計画を消すコミットを止める。完了の記録を失ったうえで検査を逃れられるため
- 2026-11-07: completedの計画の記録の欠けは、`HEAD`とステージのDecision Logの項目を位置の順で対応づけて判定する。項目の数は減らせないので文の直しでは対応が切れず、項目を途中に足したときだけ誤って止まりうる（最後に足せば止まらない）ため
- 2026-11-07: 試しの`unittest`のジョブには、lefthookの`env`で`PYTHONDONTWRITEBYTECODE=1`を渡す。渡さないと`scripts/tests/__pycache__/`が作業ツリーに残るため
- 2026-11-07: リンクを確かめるこのリポジトリ独自のフォルダ（`docs/decisions`・`.claude/tech-debt`）は、スクリプトに書かず`lefthook.yml`の`--link-dir`で渡す。Skillのフォルダには、どのリポジトリでも同じに使える中身だけを置くため
- 2026-11-07: `scripts/`のファイルはそれだけではClaudeの行動を変えないため、`claude-md-maintenance`の比較テストは、Step3で`SKILL.md`・`.claude/rules/plan-completion-local.md`と合わせて、Step1の最初のコミットの前を変更前として行う
- 2026-11-08: `check-completion.py`の試しの`git`呼び出しと検査の起動は、環境変数の`GIT_*`を引き継がない。引き継ぐと、lefthookのhookから走らせたとき（`GIT_DIR`・`GIT_INDEX_FILE`が入る）試しの一時リポジトリの操作が本物のリポジトリを書き換え、ブランチに`commit`というコミットが積まれたため

## Validation and Acceptance

- `.claude/skills/plan-completion/`の中（試しを含む）に、このリポジトリ独自の中身（Rails・db・テストのコマンド、`docs/decisions/`・`.claude/tech-debt/`等のこのリポジトリだけのパス）と、リポジトリの外の仕組みへの言及が無い
- `python3 -B -m unittest discover -s .claude/skills/plan-completion/scripts/tests`がすべて通る
- `judge-completion.sh --repo P-manBrown/tascon-backend`を空の一時フォルダで走らせた出力と終了コードが検証結果に記録され、走らせた後もフォルダが空である
- `lefthook.yml`のpre-commitの`jobs`に、globの無い`check-completion.py`のジョブ（`--link-dir docs/decisions --link-dir .claude/tech-debt`付き）と、Skillのフォルダをglobにした試しのジョブがあり、既存のジョブは変わっていない
- `git diff main -- .claude/skills/execution-plan .claude/hooks/plan-completion-check.sh .claude/hooks/plan-branch-config-check.sh .lefthook/pre-push/check-plan-steps.sh .lefthook/pre-commit/check-docs.sh .github/pull_request_template.md`が空
- `claude-md-maintenance`ルールの比較テストを`SKILL.md`と`.claude/rules/plan-completion-local.md`で行い、結果を検証結果に記録している
- マージ後に判定: 次の実際の計画の完了の処理で、`judge-completion.sh`の判定と`check-completion.py`の検査がそのとおりに働く
