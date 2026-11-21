# スタックのマージをgit-spiceのマージのコマンドで行い、確かめの関門をCIに移す

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-17
- **Related Files:** `.claude/skills/git-spice-workflow/SKILL.md`, `.devcontainer/postCreateCommand.sh`, `.claude/hooks/plan-completion-trigger.sh`, `.claude/settings.json`, `.github/workflows/ci.yml`, `.claude/skills/plan-completion/SKILL.md`

## Context

スタックのPRは、1本ずつ`gh pr merge`→`git-spice repo sync --restack=aboves`→`git-spice branch submit`を繰り返してマージしていた。1本ごとの積み直しとpushに手間がかかり、手順の誤りも起きやすかった。確かめの関門は、lefthookのpre-commit（手元の、ステージした差分だけ）と、マージ前に手元で走らせるrspecで、PRごとのCIはPRタイトルとRelated Documentsの検査だけだった。✅を付けたPRのTestingに計画の確かめの結果があるか（判定したコミットがheadと同じか）も、マージの前に手で確かめていた。完了処理のhookは`gh pr merge`の後にだけ動いた。

git-spice 0.33.0は、ネイティブのスタック（`spice.forge.github.stacks`）と、下から指定したブランチまでをまとめてマージするコマンド（`git-spice downstack merge`・`git-spice branch merge`、`spice.experiment.merge`）を持つ。atomicにマージできないPRは1本ずつマージし、上を積み直して再submitする。一部のブランチをマージした後に失敗すると、終了コード1で終わる。

[計画の完了をPR本文のRelated DocumentsのPlan行の✅で判定する](plan-completion-by-check-mark-only.md)の判定（Decision）はそのまま使う。この決定は、その判定を走らせる起点だけを変える。

## Decision

- スタックのマージは、`git-spice downstack merge --branch <範囲の一番上のブランチ>`（1本だけなら`git-spice branch merge --branch <ブランチ>`）でまとめて行う。マージの後は、範囲のすぐ上のブランチだけを`git-spice upstack restack`と`git-spice upstack submit --update-only`で更新する。`gh stack`は使わない
- ネイティブのスタック・マージのコマンド・squashでのマージ（`spice.merge.method=squash`）の設定は、全worktreeで共有の`.git/config`に、`.devcontainer/postCreateCommand.sh`でコンテナを作るときに1回入れる。squashだけを許すこのリポジトリで、forgeの既定の`merge`を使わせないため
- rspec（DB付き）とpre-commitの確かめは、PRごとにGitHub Actionsのワークフロー`CI`（job`rspec`・`checks`）でリポジトリ全体に走らせ、mainの必須チェックにする（登録は人が行う）。lefthookは手元の速い知らせと自動の直しのために残し、関門にはしない。マージの手順からrspecを外す
- マージの手順は、マージの前にCIのチェックがすべて成功していることを手順の中で確かめる。mainの保護（必須チェック）の有無に頼らないため。手順は保護や承認があることを前提にせず、保護を越える手当ても書かない
- マージのコマンドは前面で走らせ、Bashの時間の上限を600000 msにする。完了処理のhookはBashのtoolが終わった後に動くため
- 完了処理のhookは、git-spiceのマージのコマンドの後に動かし、PostToolUseに加えてPostToolUseFailureにも登録する。一部をマージした後に終了コード1で終わったときも判定を走らせるため
- ✅のPRのTestingに計画の確かめの結果があるかの確かめは、マージの手順にも、CIにも、完了の判定にも足さない。PRを出す前の確かめは、`git-spice-workflow` skillの「プルリクエスト作成ルール」が担う

## Considered Options

- **採用: CIをGitHub Actionsの1つのワークフローにし、`ruby:4.0.0`のコンテナと`mysql:8.4.8`のサービス`db`で、確かめをステップごとに直接走らせる（方式A）**: `config/database.yml`の`host: db`と既存のスクリプトを変えずに済み、落ちた確かめがPRの画面で分かり、速い。CIの環境（jq・gitの名前・`safe.directory`・libvips）を開発のDockerと別に整える必要がある
- **CIで`compose.yml`を起動し、`api`のコンテナの中で走らせる（方式B）**: 開発と同じDockerfileを使えるが、`mysql.env`の作成やイメージの作成で準備が重く遅い。`api`のイメージにjqが無く、結局足す必要がある
- **CIで`lefthook run pre-commit --all-files`を走らせる（方式C）**: 確かめの一覧を`lefthook.yml`の1か所に保てるが、rubocopの`--autocorrect`とhtmlbeautifierが作業ツリーを直して通ってしまう。`check-plan-completion.sh`はステージが空だと何も見ない
- **完了処理のhookの起点に`gh pr merge`も残す**: 手順の外で`gh pr merge`したときも判定が走るが、マージの手順はもう`gh pr merge`を使わず、手順の外のマージを手順の一部のように扱うことになるため採らなかった
- **✅のPRのTestingの確かめを、完了の判定（`judge-completion.sh`の`missing_validation`）で報告する**: 行が無い、または行のコミットがPRのheadと違うPRを、マージの後に人に知らせられる。しかし、行があるかを台本で数えても中身が正しいかは分からず、自動のrebaseでheadのSHAが変わるため、正しく書いたPRまで誤って知らせてしまう。PRを出す前に受け入れ基準を1件ずつ確かめ、満たさなければPRを出さずに止まる決まりが既にあるため採らなかった

## Consequences

- スタックは1つのコマンドでまとめてマージされ、1本ごとの積み直しとpushの繰り返しが無くなる
- atomicにマージできなかったときは、git-spiceが1本ずつマージして上のPRのCIを待つため、合計がBashの時間の上限を超えうる。そのときは状態を確かめて報告し、原因が解けた後に同じコマンドを走らせる（マージ済みのブランチは飛ばされる）
- 人が`rspec`・`checks`をmainの必須チェックに登録するまで、CIの失敗はGitHub上ではマージを止めない。マージの手順の中のCIの確かめが補う
- CIの`checks`は、lefthookの確かめと同じコマンドをリポジトリ全体に走らせる。lefthookの確かめを足し・変えたときは、`ci.yml`も合わせて変える
