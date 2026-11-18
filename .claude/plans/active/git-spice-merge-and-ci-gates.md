# スタックのマージをgit-spiceのマージのコマンドに替え、確かめの関門をCIに移す

Spec: N/A（設計と要件はGas Cityのbuildの成果物にあり、リポジトリには写していない）

## Context/Purpose

スタックのPRのマージは、`git-spice-workflow` skillの「スタックPRのマージ」で、1本ずつ`gh pr merge`→`git-spice repo sync --restack=aboves`→`git-spice branch submit`を繰り返し、マージの前に手元でrspecと、✅を付けたPRのTestingに計画の確かめの結果があるかを確かめていた。完了処理のhook（`.claude/hooks/plan-completion-trigger.sh`）は`gh pr merge`の後にだけ動いた。確かめの関門はlefthookのpre-commit（手元・差分だけ）とマージ前の手元のrspecで、PRごとのCIはPRタイトルとRelated Documentsの検査だけだった。

この計画は次の5つを、mainから一直線の5段のスタックで入れる。

1. `ci/add-ci-workflow`: `.github/workflows/ci.yml`（ワークフロー`CI`、job`rspec`・`checks`）で、rspec（DB付き）とpre-commitの確かめを、PRごとにリポジトリ全体に走らせる。今のmainでCIに落ちる3件（rubocop 2件、htmlbeautifier 1件）を直す。`lefthook.yml`は変えない
2. `chore/report-missing-validation`: `plan-completion` skillの`judge-completion.sh`の出力に`missing_validation`を足し、mainにマージ済みの✅のPRのTestingに計画の確かめの結果の行が無い、または行のコミットがPRのheadと違うことを報告する（マージは止めない）
3. `build/configure-git-spice-in-setup`: `project-setup` skillの`setup.sh`で、`spice.forge.github.stacks=true`・`spice.experiment.merge=true`・`spice.merge.method=squash`をリポジトリのlocalの設定に入れる
4. `chore/trigger-plan-completion-on-git-spice-merge`: 完了処理のhookの起点を、git-spiceのマージのコマンド（`git-spice` + `branch`/`b`・`downstack`/`ds`・`stack`/`s` + `merge`/`m`）に替え、PostToolUseFailureにも登録する。`missing_validation`を人に知らせる行を足す
5. `docs/merge-stacks-with-git-spice`: `git-spice-workflow` skillの「スタックPRのマージ」を`git-spice downstack merge`・`git-spice branch merge`の手順に替え、「プルリクエスト作成ルール」にTestingの行の形を足す。決定の記録を足す

mainの必須チェックへの`rspec`・`checks`の登録と、Actions secretとDependabot secretの両方への`RAILS_MASTER_KEY`の登録は、人がGitHubの設定で行う。

## Decision Log

- CIは、GitHub Actionsの1つのワークフローで、`ruby:4.0.0`のコンテナと`mysql:8.4.8`のサービス`db`を使い、確かめをステップごとに直接走らせる形にした。`config/database.yml`の`host: db`と既存のスクリプトを変えずに済み、どの確かめが落ちたかがPRの画面で分かる。CIで`compose.yml`を起動する案は、`mysql.env`やイメージの作成で準備が重く遅く、`api`のイメージにjqも無いため採らなかった。`lefthook run pre-commit --all-files`を走らせる案は、rubocopの`--autocorrect`とhtmlbeautifierが作業ツリーを直して通ってしまい、`check-plan-completion.sh`はステージが空だと何も見ないため採らなかった
- lefthookは手元の速い知らせと自動の直しのために今のまま残し、関門にはしない。`lefthook.yml`は変えない
- CIの`check-plan-completion.sh`は、PRのheadを履歴付きで取り出し、PRのbaseの先端とheadのmerge-baseへ`git reset --soft`してから走らせる。スクリプトはindexと`HEAD`の差分を読むため、PRの全コミットの変更をまとめて確かめられ、スクリプトを変えずに済む
- CIのrspecは並列にせず、テスト用のDBの名前（`MYSQL_TEST_DATABASE`）とサービスが作るDBの名前（`MYSQL_DATABASE`）を同じにする。サービスのユーザーが権限を持つのは、サービスが作るDBだけのため。`Docker/db/initdb.d/`の初期化のスクリプトはCIでは使わない
- CIのrspecのjobには、Actionsのsecret `RAILS_MASTER_KEY`を環境変数で渡す。`config/master.key`は追跡されず、鍵が無いと`config/initializers/devise.rb`と`omniauth.rb`が`credentials.gmail[:address]`等で起動時に落ちるため。`credentials`を鍵なしでも通す形（`dig`）にする案は、`production.rb`の`require_master_key`が無効のため本番で設定漏れが黙って通るので採らなかった。人がリポジトリのActions secretとDependabot secretの両方に`RAILS_MASTER_KEY`を登録する必要がある（DependabotのPRにはActions secretが渡らず、Dependabot secretが同じ`secrets`の文脈で渡るため、両方に登録すればDependabotのPRでもrspecが走る）。forkのPRにはsecretが渡らずrspecが落ちるが、個人のリポジトリでforkのPRを想定しないため受け入れる（R3と同じ扱い）
- `app/resources/application_resource.rb`の`select`は、Albaがこの名前で呼ぶため改名できない。その行だけで`Naming/PredicateMethod`を無効にする
- ✅のPRのTestingの確かめは、マージの前の手作業から、マージの後の判定（`judge-completion.sh`の`missing_validation`）の報告に移す。マージは止めず、人に知らせるだけにする。判定したコミットがPRのheadと同じかの比べも残す（積み直しの後に判定し直していないPRを見つけるため）。atomicにマージできずに1本ずつのマージに戻った✅のPRは、積み直しでheadが変わり、中身が同じでも「SHAが違う」と出るが、報告だけでマージは止めないため受け入れる
- Testingの行の形は`` Validation and Acceptance of `<計画のパス>`, judged at <40桁のSHA> ``にする。#797で既に使っている形で、判定が機械で読めるようにするため
- `setup.sh`は、場所を求める→git-spiceの設定→Linuxでなければ終わる→依存のインストール、の順にする。人がLinux以外のhostでClaudeを始めた場合も設定が入るようにするため。この順の変更で、場所を求める失敗（hookの入力の`cwd`が読めない、gitのリポジトリでない）は、Linux以外でも失敗の文を出して1で終わるようになる（前はLinux以外では何もせず0で終わっていた）。この変化は意図したもの
- `setup.sh`は`spice.experiment.merge=true`と`spice.merge.method=squash`も設定する。マージのコマンドは`spice.experiment.merge`が無いと使えず、squashだけを許すこのリポジトリでforgeの既定の`merge`を使わせないため
- 完了処理のhookは、git-spiceのマージのコマンドの後にだけ動かし、`gh pr merge`の起点は残さない。マージの手順はもう`gh pr merge`を使わないため
- hookの起点の対象はコマンド名`git-spice`と、その直後のサブコマンドだけにする（シンボリックリンク`gs`と、`git-spice`とサブコマンドの間の大域フラグは対象外）。手順は`git-spice`と書き、大域フラグをサブコマンドの前に置かないため
- hookの起点の前の区切りは`gh pr merge`のときと同じ（行の先頭、`;`・`&`・`|`・`(`・バッククォート・空白の直後）にし、後ろは`merge`/`m`の次が英数字・`_`・`-`以外か行末とした。git-spiceのマージのコマンドは引数なしでも走るため、`$(git-spice ds m)`や`echo "x; git-spice b m"`も起点にする
- 完了処理のhookをPostToolUseFailureにも登録する。git-spiceのマージのコマンドは、一部のブランチをマージした後に失敗すると終了コード1で終わり、そのときPostToolUseは動かないため
- マージの手順で、CIのチェックの成功をマージの前に手順の中で確かめる。mainの保護（必須チェック）の有無に頼らないため。手順の文章は保護や承認があることを前提にせず、保護を越える手当ても書かない
- マージのコマンドは前面で走らせ、Bashの時間の上限を600000 msにする。完了処理のhookはBashのtoolが終わった後に動くため、バックグラウンドで走らせるとマージが終わる前に判定してしまう
- マージのコマンドが0以外で終わったとき、マージされなかったブランチを別の手段でマージしない。git-spiceのスタックの状態とずれ、積み直しと完了処理の起点を取りこぼすため。時間の上限で打ち切られたときは、原因が解けた後に同じコマンドを走らせれば、マージ済みのブランチは飛ばされる

## Validation and Acceptance

1. `setup.sh`を走らせた後、`git config --get`で`spice.forge.github.stacks=true`・`spice.experiment.merge=true`・`spice.merge.method=squash`が読める。2回目の実行の前後で`.git/config`の内容が同じ。`Darwin`を出す`uname`をPATHの先頭に置いて走らせても3つの設定が入り、`bundle`は走らず0で終わる。同じPATHでgitのリポジトリでない`cwd`から走らせると、`project-setup: not a git repository: <cwd>`を標準出力に出して1で終わる
2. `git-spice-workflow` skillの「スタックPRのマージ」に、`gh pr merge`、マージ前のrspec、マージ前の✅のPRのTestingの確かめ、理由の文、保護・承認を前提にする書き方、保護を越える手当て、`gh stack`が無い。`git-spice downstack merge --branch`（2本以上）と`git-spice branch merge`（1本）でマージし、CIの成功を手順の中で確かめ、範囲のすぐ上のブランチを`git-spice upstack restack`と`git-spice upstack submit --update-only`で更新する。「プルリクエスト作成ルール」にTestingの行の形がある
3. `.claude/hooks/tests/test-plan-completion-trigger.sh`が合格する（git-spiceのマージのコマンドでPostToolUse・PostToolUseFailureの両方の入力で判定が走り、`gh pr merge`・ほかのgit-spiceのコマンド・`gs`・大域フラグ付きでは何も出さず0で終わる。`missing_validation`があると人に知らせるよう促す行が出る）
4. `.claude/skills/plan-completion/scripts/tests/run.sh`が合格する（`missing_validation`の例: 行が無い・別の計画の行だけ・コードフェンスの中だけ・SHAが違う→載る、headと同じSHAの行→載らない、終了コード4。`completed`・`missing_marker`・`unreadable`の結果は変わらない）
5. `ci.yml`の`rspec`のjobと`checks`の各ステップと同じコマンドを、開発コンテナでこの作業の変更の上で走らせると成功する（rspecは`RAILS_ENV=test`）。`checks`の各ステップは、手元でわざと違反を1件ずつ入れた状態で失敗する
6. 実際のPRの上で、`CI`の`rspec`と`checks`が成功する
7. 変えたSkill（`git-spice-workflow`、`plan-completion`、`project-setup`）について、`claude-md-maintenance`ルールの比較テストで、変更後にだけ期待する行動が出る
8. `docs/decisions/`に新しい決定が1ファイルあり、Considered Optionsに方式A〜C・`gh pr merge`の起点を残す案・headのSHAの比べを落とす案があり、`docs/decisions/index.md`から辿れる。`docs/decisions/plan-completion-by-check-mark-only.md`は変わっていない
9. hookの登録を変えた状態の実セッションで、git-spiceのマージのコマンドの後に判定が走る（マージ後に判定）
10. ネイティブのスタックでsubmitしたスタックを`git-spice downstack merge`でマージし、範囲のPRがまとめてマージされ、範囲のすぐ上のPRの積み直しとpushが手順どおりに済む（マージ後に判定）
