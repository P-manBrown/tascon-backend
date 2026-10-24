# planとブランチの対応をgitのブランチ設定に持つ

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-10-22
- **Related Files:** `.claude/hooks/plan-completion-check.sh`, `.claude/hooks/plan-branch-config-check.sh`, `.lefthook/pre-push/check-plan-steps.sh`, `.claude/skills/git-spice-workflow/SKILL.md`, `.claude/rules/plans-maintenance.md`, `.claude/settings.json`

## Context

planの完了処理は、そのplanに関わる全ブランチがmainへマージされた時点で行う。そのため、どのブランチがどのplanの作業かを機械的に引ける必要がある。以前はplanの`## Branches`節に作業ブランチを列挙し、pre-commitで今のブランチが載っているかを確かめていたが、次の漏れを検出できなかった。

- planを変更しないコミットしかないブランチは、一覧になくても通る
- 改名・PRにせず捨てたブランチの古い名前が一覧に残る
- Stepのブランチに`（StepN）`を書き忘れる

また、1本のブランチが複数のplanに関わることがある（自分の作業が別のplanに影響し、そのplanを更新する場合等）。

## Decision

- planとブランチの対応は、gitのブランチ設定`branch.<name>.plan`に持ち、planの`## Branches`は廃止する。値はそのブランチが関わるplanごとに1つ（`git config --add`）で、planのslug、Stepのブランチなら`<slug>:<N>`、planに属さないブランチは`none`とする
- 改名・削除はgitが設定ごと追従するので、手で直さない
- 設定のないブランチは、Claude CodeのPostToolUse（Bash）フック`plan-branch-config-check.sh`で検出し、設定するよう知らせる
- Stepの確認はpre-push（`check-plan-steps.sh`）で行う。`<slug>:<N>`の値ごとに、pushされるコミットのそのplanのProgressでStep Nがチェック済みかを確かめる
- 完了検出（`plan-completion-check.sh`）は、ローカルのmainが早送りで進んだときに、mainの版のactive planをすべて判定する。そのplanの値を持つローカルブランチのうち未マージのものが0本で、Progressに未チェックがなければ完了と知らせる。マージ済みかは、今回mainへ入ったコミットから`gh`で引いたPRのブランチか、mainへマージ済みのPRの最後のコミットがローカルの先端と同じかで判定する

## Considered Options

- **planの`## Branches`を続け、検査を足す**: 対応がplanの中にしかなく、planを変更しないコミットからはどのplanのブランチかを判定できない
- **`branch.<name>.plan`に1つの値と`planStep`**: 1本のブランチが複数のplanに関わる場合を表せない
- **planのファイルを変更した未マージのブランチ（gitの差分）も完了検出で数える**: 全ブランチの差分とsquashマージ済みのブランチの`gh`の問い合わせが要り、判定とテストが煩雑になる
- **設定のないブランチの検出・Stepの確認をgitのフックで行う**: ブランチを登録したかはコミットの中身ではないため、設定のないブランチの検出はClaude Codeのフックにした。一方、Stepの確認はpushされるコミットの中身を見るもので、Claude Codeのフックではpushのコマンドを挙げきれないため、pre-pushに残した
- **採用: 複数の値を持つ`branch.<name>.plan`**

## Consequences

- 対応はローカルの`.git/config`にしか残らない。cloneで別の環境へ移したときは、設定のないブランチの検出で紐付け直す
- 別のplanに関わったブランチでそのplanの値を足し忘れると、そのブランチが未マージでもそのplanが完了と判定されうる。足したかは意味の判断が要り、機械的には確かめられない。後でマージしたときに、`completed/`へ移したファイルとぶつかって気づける
- 完了したplanは、`completed/`へ移すまで、mainが進むたびに知らされる
- マージをバックグラウンドのコマンドで行うと、完了の通知はその後に何かツールを呼んだときに出る
