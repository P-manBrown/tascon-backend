# スタックのマージをgit-spiceのマージのコマンドに替え、確かめの関門をCIに移す

Spec: N/A（設計と要件はGas Cityのbuildの成果物にあり、リポジトリには写していない）

## Context/Purpose

スタックのPRのマージは、`git-spice-workflow` skillの「スタックPRのマージ」で、1本ずつ`gh pr merge`→`git-spice repo sync --restack=aboves`→`git-spice branch submit`を繰り返し、マージの前に手元でrspecと、✅を付けたPRのTestingに計画の確かめの結果があるかを確かめていた。完了処理のhook（`.claude/hooks/plan-completion-trigger.sh`）は`gh pr merge`の後にだけ動いた。確かめの関門はlefthookのpre-commit（手元・差分だけ）とマージ前の手元のrspecで、PRごとのCIはPRタイトルとRelated Documentsの検査だけだった。

この計画は次の4つを、mainから一直線の4段のスタックで入れる。

1. `ci/add-ci-workflow`: `.github/workflows/ci.yml`（ワークフロー`CI`、job`rspec`・`checks`）で、rspec（DB付き）とpre-commitの確かめを、PRごとにリポジトリ全体に走らせる。今のmainでCIに落ちる3件（rubocop 2件、htmlbeautifier 1件）を直す。`lefthook.yml`は変えない
2. `build/configure-git-spice-in-setup`: `.devcontainer/postCreateCommand.sh`で、`spice.forge.github.stacks=true`・`spice.experiment.merge=true`・`spice.merge.method=squash`・`spice.submit.navigationComment=false`をリポジトリのlocalの設定に入れる（コンテナを作るときに1回）
3. `chore/trigger-plan-completion-on-git-spice-merge`: 完了処理のhookの起点を、git-spiceのマージのコマンド（`git-spice` + `branch`/`b`・`downstack`/`ds`・`stack`/`s` + `merge`/`m`）に替え、PostToolUseFailureにも登録する
4. `docs/merge-stacks-with-git-spice`: `git-spice-workflow` skillの「スタックPRのマージ」を`git-spice downstack merge`・`git-spice branch merge`の手順に替え、決定の記録を足す

mainの必須チェックへの`rspec`・`checks`の登録と、Actions secretとDependabot secretの両方への`RAILS_MASTER_KEY`の登録は、人がGitHubの設定で行う。

## Decision Log

- CIは、GitHub Actionsの1つのワークフローで、`ruby:4.0.0`のコンテナと`mysql:8.4.8`のサービス`db`を使い、確かめをステップごとに直接走らせる形にした。`config/database.yml`の`host: db`と既存のスクリプトを変えずに済み、どの確かめが落ちたかがPRの画面で分かる。CIで`compose.yml`を起動する案は、`mysql.env`やイメージの作成で準備が重く遅く、`api`のイメージにjqも無いため採らなかった。`lefthook run pre-commit --all-files`を走らせる案は、rubocopの`--autocorrect`とhtmlbeautifierが作業ツリーを直して通ってしまい、`check-plan-completion.sh`はステージが空だと何も見ないため採らなかった
- lefthookは手元の速い知らせと自動の直しのために今のまま残し、関門にはしない。`lefthook.yml`は変えない
- CIの`check-plan-completion.sh`は、PRのheadを履歴付きで取り出し、PRのbaseの先端とheadのmerge-baseへ`git reset --soft`してから走らせる。スクリプトはindexと`HEAD`の差分を読むため、PRの全コミットの変更をまとめて確かめられ、スクリプトを変えずに済む
- CIのrspecは並列にせず、テスト用のDBの名前（`MYSQL_TEST_DATABASE`）とサービスが作るDBの名前（`MYSQL_DATABASE`）を同じにする。サービスのユーザーが権限を持つのは、サービスが作るDBだけのため。`Docker/db/initdb.d/`の初期化のスクリプトはCIでは使わない
- CIのrspecのjobには、Actionsのsecret `RAILS_MASTER_KEY`を環境変数で渡す。`config/master.key`は追跡されず、鍵が無いと`config/initializers/devise.rb`と`omniauth.rb`が`credentials.gmail[:address]`等で起動時に落ちるため。`credentials`を鍵なしでも通す形（`dig`）にする案は、`production.rb`の`require_master_key`が無効のため本番で設定漏れが黙って通るので採らなかった。人がリポジトリのActions secretとDependabot secretの両方に`RAILS_MASTER_KEY`を登録する必要がある（DependabotのPRにはActions secretが渡らず、Dependabot secretが同じ`secrets`の文脈で渡るため、両方に登録すればDependabotのPRでもrspecが走る）。forkのPRにはsecretが渡らずrspecが落ちるが、個人のリポジトリでforkのPRを想定しないため受け入れる（R3と同じ扱い）
- `app/resources/application_resource.rb`の`select`は、Albaがこの名前で呼ぶため改名できない。その行だけで`Naming/PredicateMethod`を無効にする
- ✅のPRのTestingに計画の確かめの結果があるかの確かめは、マージの手順にも、CIにも、完了の判定にも足さない。PRを出す前に計画の受け入れ基準を1件ずつ確かめ、満たさなければPRを出さずに止まる決まりは、`git-spice-workflow` skillの「プルリクエスト作成ルール」が担っている。行があるかを台本で数えても中身が正しいかは分からず、自動のrebaseでheadのSHAが変わるため、正しく書いたPRまで誤って知らせてしまう
- 判定の出力（`judge-completion.sh`の`missing_validation`）にこの確かめを足す案（`chore/report-missing-validation`、#819）は、上の理由でマージせずに閉じ、このスタックから外した。Testingの`Validation and Acceptance of ..., judged at <SHA>`の行の形も、その判定が読むために決めたものなので、「プルリクエスト作成ルール」には足さない
- 当初は`project-setup` skillの`setup.sh`にgit-spiceの設定を入れ、場所を求める→git-spiceの設定→Linuxでなければ終わる→依存のインストール、の順にしていた。これをやめ、`setup.sh`と`project-setup`の`SKILL.md`はmainのままにする。設定は`.devcontainer/postCreateCommand.sh`に置く方が、設定の置き場がコンテナを作るときの1か所に収まり、`setup.sh`が場所を求める失敗の振る舞い（Linux以外で0で終わる）を変えずに済むため
- git-spiceの設定は、`project-setup` skillの`setup.sh`ではなく、`.devcontainer/postCreateCommand.sh`でコンテナを作るときに1回、`git config --local`で入れる。`.git/config`は全worktreeで共有のため、1回で足りる。`spice.experiment.merge`はマージのコマンドに要り、`spice.merge.method=squash`はsquashだけを許すこのリポジトリでforgeの既定の`merge`を使わせないため、`spice.submit.navigationComment=false`はsubmitがPRにナビゲーションのコメントを足さないために入れる。`spice.submit.updateOnly`・`spice.branchCreate.commit`・個人の好みの設定は、リポジトリで決めずに入れない
- 完了処理のhookは、git-spiceのマージのコマンドの後にだけ動かし、`gh pr merge`の起点は残さない。マージの手順はもう`gh pr merge`を使わないため
- hookの起点の対象はコマンド名`git-spice`と、その直後のサブコマンドだけにする（シンボリックリンク`gs`と、`git-spice`とサブコマンドの間の大域フラグは対象外）。手順は`git-spice`と書き、大域フラグをサブコマンドの前に置かないため
- hookの起点の前の区切りは`gh pr merge`のときと同じ（行の先頭、`;`・`&`・`|`・`(`・バッククォート・空白の直後）にし、後ろは`merge`/`m`の次が英数字・`_`・`-`以外か行末とした。git-spiceのマージのコマンドは引数なしでも走るため、`$(git-spice ds m)`や`echo "x; git-spice b m"`も起点にする
- 完了処理のhookをPostToolUseFailureにも登録する。git-spiceのマージのコマンドは、一部のブランチをマージした後に失敗すると終了コード1で終わり、そのときPostToolUseは動かないため
- マージの手順で、CIのチェックの成功をマージの前に手順の中で確かめる。mainの保護（必須チェック）の有無に頼らないため。手順の文章は保護や承認があることを前提にせず、保護を越える手当ても書かない
- マージのコマンドは前面で走らせ、Bashの時間の上限を600000 msにする。完了処理のhookはBashのtoolが終わった後に動くため、バックグラウンドで走らせるとマージが終わる前に判定してしまう
- マージのコマンドが0以外で終わったとき、マージされなかったブランチを別の手段でマージしない。git-spiceのスタックの状態とずれ、積み直しと完了処理の起点を取りこぼすため。時間の上限で打ち切られたときは、原因が解けた後に同じコマンドを走らせれば、マージ済みのブランチは飛ばされる

## Validation and Acceptance

1. `.devcontainer/postCreateCommand.sh`の`git config --local spice.`の4行を、使い捨てのgitリポジトリで2回走らせると、`git config --get`で`spice.forge.github.stacks=true`・`spice.experiment.merge=true`・`spice.merge.method=squash`・`spice.submit.navigationComment=false`が読め、2回目の前後で`.git/config`の内容が同じ。`project-setup`の`setup.sh`と`SKILL.md`がmainと同じで、git-spiceの設定を含まない。コンテナを作り直して設定が入ることは、人のウォークスルーで確かめる
2. `git-spice-workflow` skillの「スタックPRのマージ」に、`gh pr merge`、マージ前のrspec、マージ前の✅のPRのTestingの確かめ、理由の文、保護・承認を前提にする書き方、保護を越える手当て、`gh stack`が無い。`git-spice downstack merge --branch`（2本以上）と`git-spice branch merge`（1本）でマージし、CIの成功を手順の中で確かめ、範囲のすぐ上のブランチを`git-spice upstack restack`と`git-spice upstack submit --update-only`で更新する
3. `.claude/hooks/tests/test-plan-completion-trigger.sh`が合格する（git-spiceのマージのコマンドでPostToolUse・PostToolUseFailureの両方の入力で判定が走り、`gh pr merge`・ほかのgit-spiceのコマンド・`gs`・大域フラグ付きでは何も出さず0で終わる）
4. `ci.yml`の`rspec`のjobと`checks`の各ステップと同じコマンドを、開発コンテナでこの作業の変更の上で走らせると成功する（rspecは`RAILS_ENV=test`）。`checks`の各ステップは、手元でわざと違反を1件ずつ入れた状態で失敗する
5. 実際のPRの上で、`CI`の`rspec`と`checks`が成功する
6. 変えたSkill（`git-spice-workflow`、`plan-completion`）について、`claude-md-maintenance`ルールの比較テストで、変更後にだけ期待する行動が出る
7. `docs/decisions/`に新しい決定が1ファイルあり、Considered Optionsに方式A〜C・`gh pr merge`の起点を残す案・✅のPRのTestingの確かめを完了の判定で報告する案があり、`docs/decisions/index.md`から辿れる。`docs/decisions/plan-completion-by-check-mark-only.md`は変わっていない
8. hookの登録を変えた状態の実セッションで、git-spiceのマージのコマンドの後に判定が走る（マージ後に判定）
9. ネイティブのスタックでsubmitしたスタックを`git-spice downstack merge`でマージし、範囲のPRがまとめてマージされ、範囲のすぐ上のPRの積み直しとpushが手順どおりに済む（マージ後に判定）
