# planとブランチの対応のgit設定への移行

## Context/Purpose

planの作業ブランチは、planの`## Branches`に書き、pre-commitで「planを変更するコミットのとき、今のブランチが一覧にあるか」を確かめている（`plan-branch-list-completion`）。完了検出フック（`.claude/hooks/plan-completion-check.sh`）は、mainの版のplanの`## Branches`を読んで完了を判定する。この方式では、一覧が抜け漏れなく正しく書かれているかを確かめられない。

- pre-commitの確認は、ステージしたplanだけを対象にする。planを変更しないコミットしかないブランチは、一覧になくても通る。ブランチとplanの対応がplanの中にしかないため、planを変更しないコミットからは、どのplanのブランチかを判定できない
- 改名したとき、古い名前が一覧に残っても検出しない
- PRにせず捨てたブランチが一覧に残っても検出しない
- Stepのブランチに`（StepN）`を書き忘れても検出しない

そこで、planとブランチの対応をgitのブランチ設定（`.git/config`の`branch.<name>.*`）に持たせ、`## Branches`を廃止する。gitはブランチの改名・削除に設定ごと追従するため、改名・削除の書き換え漏れが起きない。書き忘れは、設定のないブランチをClaude Codeのフックで検出する。

## 合意した方針

- planとブランチの対応は、gitのブランチ設定に持つ
  - `branch.<name>.plan`: そのブランチが関わるplanごとに1つの値（`git config --add`）。値はplanのslug（ファイル名から`.md`を除いたもの。`completed/`へ移っても変わらない）、Stepのブランチなら`<slug>:<N>`。planに属さないブランチは`none`
  - ブランチを作ったら設定する。別のplanの作業をした、または自分の作業が別のplanに影響してそのplanを更新したら、そのplanの値も足す。別のplanの作業は、できるだけそのplanのブランチで行う
  - 改名・削除はgitが設定ごと追従するので、手で直さない
  - （Step1・2では`plan`に1つの値と`planStep`で作った。Step3で複数の値の形に直す）
- planの`## Branches`と、pre-commitの`## Branches`の確認は廃止する
- 完了検出フックは次のとおり判定する
  - きっかけは今と同じく、ローカルのmainが前回の記録から早送りで進んだとき
  - mainの版のactive planごとに、次の両方を満たせば完了とする
    - `branch.<name>.plan`の値にそのplanのslug（`<slug>`または`<slug>:<N>`）を持つローカルブランチのうち、未マージのものが0本。マージ済みかは今の判定のまま（今回mainへ入ったコミットから`gh`で特定したブランチ、またはmainへマージ済みのPRがあり、その最後のコミットがローカルの先端と同じブランチ）
    - Progressに未チェックの項目（`- [ ]`）が残っていない
  - 対応表の写し（状態ファイル）は持たない
  - 完了なら、今と同じく`execution-plan`の完了処理を行うよう、stderrとexit 2で知らせる。`gh`が使えないときは、判定できなかったことを知らせる
- 設定のないブランチは、Claude Code側のフック（Bashの実行後）で検出する。main以外で`branch.<name>.plan`の値が1つもないローカルブランチを挙げ、設定するよう知らせる。Stepのブランチなら`<slug>:<N>`の形で設定するよう、あわせて知らせる
- pre-pushのStepの確認は、gitのフックのまま残す。`branch.<name>.plan`の`<slug>:<N>`の値ごとに、pushされるコミットのそのplanのProgressで、Step Nが`- [x]`かを確かめる。`:<N>`のない値は確かめない
- 完了検出に、planのファイルを変更した未マージのブランチ（gitの差分）を数える経路は足さない
- Branchesの行の`type/name`形式は検証しない
- `.claude/plan-completion-state/branches`（ブランチの削除を手がかりにしていた古い版の名残。今の版は読み書きしていない）は消す

## Progress

- [x] Step1: `plans-maintenance`ルールと`execution-plan` skillを書き換える（`## Branches`の廃止、ブランチを作ったときのgit設定）。比較テストを行う
  - ブランチを作ったときの設定は、ブランチ作成時に読み込まれる`git-spice-workflow` skillの「ブランチ作成ルール」に書き、`execution-plan`の手順5はそれを参照する形にした。planに属さないブランチ（`none`）は`execution-plan`も`plans-maintenance`も読み込まれない場面で作られるため。3ファイルの編集をCodexへ委譲した
  - 比較テストを終え（検証結果）、`chore/record-check-no-match-reply`の上に`docs/plan-branch-config-rules`を`--insert --no-restack`で作った。Claude関連の段に積んだ。`## Branches`はStep5までは今の方式（pre-commitの確認）のため残し、このブランチを書き足した。新しい方式の設定（`plan`・`planStep`）も入れた
  - gitの設定のキーは、最後の部分の大文字と小文字を区別せず、`planStep`は`.git/config`に`planstep`と書かれる。`git config branch.<name>.planStep`では読める。Step2・3でキーを`--get-regexp`等で照合するときは、小文字で照合する
- [x] Step2: pre-commitの`## Branches`の確認を外し、pre-pushがStepを`branch.<name>.planStep`から引くように変える。今のpre-commitは`## Branches`に今のブランチがないと止めるため、Step5で`## Branches`を消すより前に行う
  - `docs/plan-branch-config-rules`の上に`chore/plan-branch-config-git-hooks`を`--insert --no-restack`で作り、設定を入れた。2スクリプトの編集と、一時リポジトリでの直接実行の確認をCodexへ委譲した。直接実行で確かめた（検証結果）。pre-pushは、`planStep`があるのにpushされるコミットに`.claude/plans/active/<plan>.md`がないときも止める形にした
- [x] Step3: `branch.<name>.plan`を複数の値（`<slug>`・`<slug>:<N>`）の形にし、`planStep`をやめる。`git-spice-workflow` skillの文言（比較テストを行う）と、pre-pushの`check-plan-steps.sh`を直し、Step1・2のブランチの設定を新しい形に直す。`plans-maintenance`に、別のplanの作業はできるだけそのplanのブランチで行い、行ったとき・影響したときはそのplanの値も足すことを書く
  - 3ファイル（`git-spice-workflow`・`plans-maintenance`・`check-plan-steps.sh`）の編集と、pre-pushの直接実行の確認をCodexへ委譲した（未コミット、ブランチは比較テストの後に作る）
  - 直接実行と比較テストを終え（検証結果）、`chore/plan-branch-config-git-hooks`の上に`chore/plan-branch-multi-plan`を`--insert --no-restack`で作った。Step1・2のブランチの設定は`planStep`を消し、`plan`を`plan-branch-config:1`・`plan-branch-config:2`に直した
- [x] Step4: 既存のローカルブランチに設定を入れる（active planの`## Branches`から。どのplanにも載っていないブランチは`none`）。完了検出フックを設定から判定する形に作り直し、設定のないブランチの検出を足す。`.claude/plan-completion-state/branches`を消す。`hooks-authoring`ルールの確認（直接実行・実セッションでの発火）を行う。worktreeの間でブランチ設定が共有されるかもここで確かめる
  - 着手前に既存の`## Branches`を洗い出すと、1本のブランチが複数のplanに載っていた（`feat/notification-model`は`notification-creation`のStep1と`notification-index`のStep0、`feat/cable-ticket`は`notification-realtime-delivery`のStep2と`lefthook-debride-scope-change`、`docs/plan-branches-backfill`・`docs/plan-progress-format`は3つのplan）。`plan`・`planStep`を1つずつ持つ今の設計では表せないため、ブランチを作る前に止めて、ユーザーに方式を相談している（複数の値を持たせる案と、1ブランチ1planに限る案）
  - 複数の値を持たせる形に決まった（Decision Log）。その変更をStep3として挟み、この作業はStep4にした。移行では、載っているplanをすべて値に入れる
  - `chore/plan-branch-multi-plan`の上に`chore/plan-completion-from-config`を`--insert --no-restack`で作った。Claude関連の段（HEAD）と機能側の最上段（`docs/cbm-daemon-recurrence`）のactive planの`## Branches`から対応表を作り、ローカルにあるブランチへ`git config --add`で入れた（`（StepN）`付きは`<slug>:<N>`）。どちらにも載っていない13本は`none`にした。設定のないローカルブランチ（main以外）は0本、`planStep`の残りは0件になった。`## Branches`に載っていてローカルにない6本（`todoist-task-runner`のマージ済みとみられるブランチ）は入れていない
  - 例: `feat/notification-model`は`notification-creation:1`と`notification-index:0`、`feat/cable-ticket`は`lefthook-debride-scope-change`と`notification-realtime-delivery:2`、`docs/plan-progress-format`は`plan-branch-list-completion:5`・`plan-work-records`・`todoist-task-runner`
  - 完了検出フックの作り直し、設定のないブランチを検出する新しいフック`.claude/hooks/plan-branch-config-check.sh`（PostToolUse・Bash）、`settings.json`への登録、`gh`をスタブにした一時リポジトリでの直接実行の確認をCodexへ委譲した（未コミット）。完了検出は、対象を今回マージされたブランチのplanに絞らず、mainの版のactive planをすべて判定し、Progressに未チェックがあるplanは`gh`を呼ばずに飛ばす形にした
  - 直接実行・実セッションでの発火・worktreeの間の共有を確かめた（検証結果）。`.claude/plan-completion-state/branches`を消した（gitの管理外）
- [x] Step5: Claude関連の段にあるactive planから`## Branches`を消す。機能側のブランチにしかないplanは、そのplanを最後に変更した機能ブランチで消す
  - `chore/plan-completion-from-config`の上に`docs/drop-plan-branches-sections`を`--insert --no-restack`で作った。`plan`には`plan-branch-config:5`と、書き換える4つのplan（`plan-branch-list-completion`・`plan-work-records`・`rule-and-hook-change-tests`・`todoist-task-runner`）の値を入れた。5つのplanから`## Branches`を消す編集をCodexへ委譲し、削除だけの差分（追加行0、`## Branches`0件）であることを確かめた（未コミット）
  - 機能側のブランチにしかない11のplan（`notification-*`・`push-*`・`solid-queue-introduction`・`task-due-notification`・`lefthook-debride-scope-change`）は、最後に変更したブランチが11本に分かれている。それぞれで消すか、各planの完了処理の時に消すかをユーザーに相談している
  - Claude関連の段の5つのplanの削除を`b851394c`としてコミットした。機能側は今消すことになった（Decision Log）。前回の`## Branches`の書き足し（`plan-branch-list-completion`）と同じく、各planを最後に変更した機能ブランチに、1planずつコミットを積む。節の削除はCodexが作ったscratchpadのスクリプトで行う
  - 11本の機能ブランチ（`build/solid-queue`から`feat/task-due-notification`まで、下の段から順に）で、それぞれのplanの`## Branches`を消してコミットした（削除だけの差分であることと、変更したファイルがそのplanだけであることを、コミットの前に確かめた）。`git-spice upstack restack`はコンフリクトなく終わり、`needs restack`は0件、最上段（`docs/cbm-daemon-recurrence`）のactive planに`## Branches`は残っていない
- [x] Step6: Step1・3の`plans-maintenance`の変更（`Branches`節の削除、「ブランチとの対応」節の追加）を、`rule-and-hook-change-tests`のStep4で作るダミーplanの仕組みで比較テストする。変更前は、それぞれのStepのコミットの1つ前へdetachして作る
  - 2つの比較テストを終え、どちらも行動が変わったため変更を残す（検証結果）。テストのたびにダミーplanを置き、終わったら消した。`chore/rule-test-fixture`の上に`docs/plan-branch-config-rule-tests`を作り、結果をコミットする
  - 定義を確かめるための`rule-tester`の起動（定義の指示文を引用させる形）は、ユーザーの許可の後もauto modeの判定で拒否された。代わりに、テストのプロンプトでダミーplanを読ませ、読めたこと（新しい定義でしか読めない）で今の定義で動いていることを確かめた

## 検証結果

- ブランチ設定の追従（2026-10-22、scratchpadの一時リポジトリ）: `git config branch.feat/a.plan p.md`の後、`git branch -m feat/a feat/b`で`branch.feat/b.plan p.md`に移り、`gs branch rename feat/c`で`branch.feat/c.plan p.md`に移った。`git branch -D feat/c`で設定も消えた
- Step1の比較テスト（2026-10-22、対象: `git-spice-workflow`・`execution-plan`・`plans-maintenance`）: 「`rule-and-hook-change-tests`のplanにStep4を足し、Step4用の`docs/rule-test-step4`を`--no-commit`で作った。最初のコミットまでに、ブランチを作ったことに関してやることは」を問い、期待する行動を「`branch.<name>.plan`と`planStep`を設定する」とした。変更前はplanの`Branches`に書き足すと答え、変更後は`branch.docs/rule-test-step4.plan`に`rule-and-hook-change-tests`、`planStep`に`4`を設定すると答えた。行動が変わったため変更を残す。どちらもskillはSkillツールで読み込んでいた
  - 1回目の変更前テストは、stashで変更を退避した直後に起動すると、Skillツールが変更後の`git-spice-workflow`を返し、変更後と同じ答えになった。ディスク上は変更前だった。少し置いてから`rule-tester`にSkillツールでブランチ作成ルールを引用させ、変更前に戻ったことを確かめてからやり直した。変更後のテストの前も、同じ方法で変更後の内容になったことを確かめた。エージェント定義と同じく、skillもファイルの変更から少し遅れて読み込み直されるとみられる（仕組みは確かめていない）
  - `plans-maintenance`の変更（`Branches`節の削除）は、`rule-tester`では確かめられなかった。新しいplanの節の構成を問うと、変更前のテストで`plans-maintenance`が差し込まれず、節の構成は分からないと答えた。このルールは`.claude/plans/`配下を読んだときに差し込まれるが、`rule-tester`はガードで`.claude/plans/`を読めないため。削除しないと、廃止した`Branches`を書く指示が残り、変更後の手順と食い違うため、変更を残す
- Step3のpre-pushの直接実行（2026-10-22、scratchpadの一時リポジトリ、Codexの確認とClaudeの再実行）: `plan`の値が`demo:2`でStep2が`- [ ]`のとき、`missing:1`でplanのファイルがないときはエラーを出してexit 1、`demo:2`でチェック済みのとき、`demo`だけ・`none`だけ・値なしのとき、削除のpush、tagのrefではexit 0で何も出さなかった。`demo:2`（チェック済み）と`other:1`（未チェック）の2つの値では、`other`のエラーだけを出してexit 1になった。`bash -n`を通った
- Step3の比較テスト（2026-10-22、対象: `git-spice-workflow`・`plans-maintenance`）: Step1と同じ場面で、実行するコマンドまで答えさせた。期待する行動は「Stepを`<slug>:<N>`の形で`plan`に入れる」。変更前は`plan`に`rule-and-hook-change-tests`、`planStep`に`4`を設定すると答え、変更後は`git config branch.docs/rule-test-step4.plan rule-and-hook-change-tests:4`と答え、`--add`は関わるplanが複数のときだけ使うと答えた。行動が変わったため変更を残す。変更前のテストの前に、Skillツールの内容が変更前に戻ったことを`rule-tester`の引用で確かめた。変更後の前の同じ確認は、auto modeの判定でサブエージェントの起動が拒否されたため行っていない。変更後の答えが新しい形だったので、変更後の内容で動いていた
  - `plans-maintenance`に足した「ブランチとの対応」は、Step1と同じ理由（`rule-tester`は`.claude/plans/`を読めず、このルールが差し込まれない）で確かめられなかった。別のplanに関わったときに値を足す手順は、ほかに書く場所がなく、ないと足すきっかけがないため残す
- Step4のフックの直接実行（2026-10-22、scratchpadの一時リポジトリ、`gh`はスタブ、Codexの確認）: 完了検出フックは、planの全ブランチがマージ済み（ローカルに残る・mainの更新より先に削除の両方）、planのブランチが0本、別のplanの値だけを持つ未マージのブランチがあるとき、数字でないStepの値・slugの部分一致の値（対象外）のとき、作業ツリーだけProgressが未チェックのとき（mainの版で判定）に完了を知らせ（exit 2）、未マージのブランチがある（`<slug>`・`<slug>:<N>`のどちら側でも）、Progressに未チェックがある（planごとの`gh pr list`を呼ばない）、同じ名前で作り直した作業中のブランチがある、mainが進んでいないときは何も出さなかった。`gh api`・`gh pr list`の失敗では判定できなかったことを知らせ、復旧後の再実行で同じ範囲を判定し直した。設定のないブランチの検出は、値のないブランチを挙げてexit 2、すべて設定済み（`none`を含む）とgitリポジトリ外のcwdでは何も出さなかった。両スクリプトの`bash -n`と`jq . .claude/settings.json`が通った。記録は`/tmp/claude-1000/-home-ruby-tascon-backend/caa74a36-e710-4009-9c65-5d319cdca67e/scratchpad/plan-hooks-qc1r96_1/results.md`
- Step4のフックの実セッション（2026-10-22、`settings.json`へ登録した状態）: 設定のないブランチの検出は、実リポジトリで直接実行して何も出さず、`git branch chore/hook-probe-unset`のBashの後に、そのブランチを挙げて発火した。消した後のBashでは何も出なかった。完了検出は、状態ファイルのmainを`main^`に戻してBashを実行すると、mainの版の未チェックのないplan（`lefthook-debride-scope-change`・`todoist-task-runner`）に未マージのブランチがあるため何も出さず、状態ファイルはmainに更新された。`build/debride-full-scope`・`feat/cable-ticket`から`lefthook-debride-scope-change`の値を一時的に外して同じ操作をすると、`lefthook-debride-scope-change.md`の完了を知らせた。値はその後に戻した
- worktreeの間のブランチ設定（2026-10-22、scratchpadの一時リポジトリ）: `git worktree add`で作ったworktreeから`git config --add branch.feat/w.plan p:1`とすると、元のcheckoutから同じ値が読め、`--show-origin`は`file:.git/config`（共通の設定）だった
- Step6の比較テスト1（2026-10-22、対象: `plans-maintenance`の`Branches`節の削除、変更前は`1db484ed^`へdetach）: `.claude/plans/rule-test-fixture.md`にダミーplanを置き、「それを読み、雛形にして通知の再送処理の新しいplanを作る。入れる節を順に挙げて」を問い、期待する行動を「`## Branches`を挙げない」とした。変更前は`plans-maintenance`の6節として`## Branches`（`- feat/notification-retry（Step1）`の形）を挙げ、変更後は`## Branches`を挙げず、ブランチとの対応はブランチ設定に入れると答えた。どちらもダミーplanのReadで`plans-maintenance`が差し込まれていた。変更後はgitStatusの直近のコミット（`b851394c docs: drop the Branches section from plans`）にも触れていた。行動が変わったため変更を残す
- Step6の比較テスト2（2026-10-22、対象: `plans-maintenance`の「ブランチとの対応」節、変更前は`d53099f0^`へdetach）: ダミーplanを置き、「これはplan `rule-test-fixture`とする。別のplan `notification-retry`のStep1用のブランチ`feat/notification-retry`で作業した結果、このplanの前提が変わったので更新する。ほかにコミットまでにすることは」を問い、期待する行動を「今のブランチの`branch.<name>.plan`に`rule-test-fixture`の値を足す」とした。変更前は`rule-test-fixture`用に別のブランチを作ってそこでコミットすると答え、今のブランチの値には触れなかった。変更後は「ブランチとの対応」を根拠に、`git config --add branch.feat/notification-retry.plan rule-test-fixture`（Stepのブランチではないので番号なし）と答えた。行動が変わったため変更を残す
  - Step1・3の比較テストで確かめられなかったとしていた`plans-maintenance`の2つの変更は、これで確かめた
- 複数の値の追従（2026-10-22、scratchpadの一時リポジトリ）: `git config --add`で`branch.feat/a.plan`に`p1:1`と`p2`を入れると、`git branch -m`・`gs branch rename`の後も`--get-all`で両方が残り、`git branch -D`で両方消えた
- ブランチ設定の置き場所（2026-10-22）: `git config branch.<name>.plan`等は、このリポジトリの`.git/config`の`[branch "<name>"]`節に書かれた（`git config --show-origin`で`file:.git/config`）。`planStep`はファイルには書いたとおりの大文字小文字で残り、`--get-regexp`の出力では`planstep`になる。`extensions.worktreeConfig`は未設定
- Step2のpre-pushの直接実行（2026-10-22、scratchpadの一時リポジトリ、Codexの確認とClaudeの再実行）: pre-pushの標準入力の形の行を与えると、`planStep`のStepがProgressで`- [ ]`のときと、pushされるコミットにplanのファイルがないときはエラーを出してexit 1、`- [x]`のとき、`planStep`がない・`plan`が`none`・設定がない・`plan`が空のとき、削除のpush、tagのrefではexit 0で何も出さなかった。Progress節の外にある`- [x] Step2:`は数えなかった。`check-docs.sh`・`check-plan-steps.sh`とも`bash -n`を通った

## Decision Log

- 2026-10-22: planとブランチの対応を、planの`## Branches`ではなくgitのブランチ設定（`branch.<name>.plan`・`branch.<name>.planStep`）に持たせ、`## Branches`を廃止する（ユーザー提案）。gitはブランチの改名・削除に設定ごと追従し、書き換え・外し忘れが起きないため。gitの知らないキーはgitが読まないだけで、既存のキー（`remote`・`merge`・`description`等）と名前がかぶらなければ影響しない。対応はローカルにしか残らないが、このリポジトリは個人開発で、別の環境へはフォルダごと（`.git`ごと）コピーして移すため、共有の必要はない。cloneで移したときは、設定のないブランチの検出で紐付け直す
  - これにより、`plan-branch-list-completion`のDecision Logのうち、`## Branches`による完了検出、pre-commitの`## Branches`の確認、`（StepN）`の書き添えに関する決定（2026-10-21）を置き換える
- 2026-10-22: 完了検出は、そのplanの未マージのローカルブランチが0本で、Progressに未チェックがないことで判定する（ユーザー提案）。マージ後に削除されたブランチは設定も消えるが、終わったブランチなので覚えておく必要がなく、未マージで消えたブランチはPRにせず捨てたものなので数えなくてよい。必要な情報が今ある設定から取れるため、対応表の写しを持たない。単純に「そのplanのブランチが0本」とせず未マージに絞るのは、マージ済みブランチがローカルに残っている間も完了と判定でき、ブランチの削除に依存しないため。Progressの条件を残すのは、Stepのブランチがマージされてから次のStepのブランチを作るまでの間も0本になるため
  - マージされたブランチは、mainの更新と同じコマンドで削除されて設定が消えていることがある（`git-spice repo sync`等）。そのため対象のplanを今回マージされたブランチから選ばず、mainの版のactive planをすべて判定する。完了したplanは、`completed/`へ移すまで、mainが進むたびに知らされる
- 2026-10-22: 設定のないブランチの検出と、Stepの書き添えの確認は、Claude Codeのフックで行う（ユーザー指示）。ブランチを登録したかはコミットの中身ではなく、gitの差分に乗らないものをgitのフックで確かめるのは筋が違うため。Stepの書き添えが正しいかは意味の判断が要り機械的には確かめられないため、設定のないブランチを知らせるときに、Stepなら`<slug>:<N>`の形で設定するよう思い出させる
- 2026-10-22: pre-pushのStepの確認は、gitのフックのまま残す（ユーザー同意）。Claude Codeのフックでpushを見分けるには、Bashのコマンドから`git push`・`git-spice`の各submitと省略形を挙げる必要があり、挙げきれず取りこぼすため（完了検出フックのきっかけを絞らない決定と同じ理由）。確かめる対象はpushされるコミットのProgressで、コミットの中身にあたる。gitの設定はどのStepかを引くのに使うだけ
- 2026-10-22: Branchesの行の`type/name`形式は検証しない（ユーザー同意）。行そのものがなくなり、ブランチ名はgitが持つため
- 2026-10-22: `plan-branch-list-completion`にStepを足さず、新しいplanにする。`## Branches`の方式を置き換える作業で、置き換えたことをこのplanのDecision Logに残す方が追いやすいため
- 2026-10-22: `branch.<name>.plan`は、そのブランチが関わるplanごとに1つの値を持つ（複数の値）。値は`<slug>`、Stepのブランチなら`<slug>:<N>`とし、`planStep`はやめる（ユーザー指摘）。既存の`## Branches`には、1本のブランチが複数のplanに載っているものがあった。多くは別のplanの作業をそのブランチで混ぜたもので、望ましくない（`feat/cable-ticket`で`lefthook-debride-scope-change`の確認と記録をした等）。一方、自分のplanの作業が別のplanに影響し、そのplanを更新するのは正当で、1ブランチ1planには限れない。1つの値ではそもそも表せない。Stepをplanと同じ値に入れるのは、どのplanのStepかを取り違えないため。gitは複数の値も改名・削除で追従する（検証結果）
  - 別のplanの作業は、できるだけそのplanのブランチで行う。行ったとき、または影響してそのplanを更新したときは、そのplanの値も足す
- 2026-10-22: 完了検出に、planのファイルを変更した未マージのブランチ（gitの差分）を数える経路は足さない（ユーザー指摘）。ローカルの全ブランチについて差分と、squashマージ済みで残るブランチの`gh`の問い合わせが要り、フックの判定とテストが煩雑になるため。防げるのは「別のplanの値を足し忘れ、そのplanのファイルを変更したブランチが未マージのまま、そのplanが完了処理される」場合だけで、まれで、後でマージしたときに`completed/`へ移したファイルとぶつかって気づける
  - 既知の制約: 別のplanに関わったブランチでそのplanの値を足し忘れると、そのplanは、このブランチが未マージでも完了と判定されうる。足したかは意味の判断が要り、機械的には確かめられない。planのファイルに何も書かなかった場合は、そのplanはその作業を知らないので、どの仕組みでも拾えない

- 2026-10-22: 機能側のブランチにしかないplanの`## Branches`も、今消す（ユーザー指示）。前回の書き足しと同じく、各planを最後に変更した機能ブランチに1planずつコミットを積む
- 2026-10-22: `rule-tester`で確かめられなかった`plans-maintenance`の変更（Step1の`Branches`節の削除、Step3の「ブランチとの対応」節）は、テストしないまま残さず、何らかの方法でテストする（ユーザー指摘）。同じ状況になったときも、テストできないまま残さず、テストする方法を作る。方法は、`rule-tester`のガードに`.claude/plans/rule-test-fixture.md`の1ファイルだけ読める例外を足し、テストの時だけそこに中身のないダミーplanを置いて`plans-maintenance`を差し込ませる形にする（ユーザー同意）。ガードの例外と、比較テストの手順への追記は`rule-and-hook-change-tests`のStep4で行い、このplanのStep6でテストする
- 2026-10-23: 完了処理で、planとブランチの対応・Stepの確認・完了検出の方式を`docs/decisions/plan-branch-mapping-in-git-config.md`にまとめた。値の足し忘れによる誤った完了判定（既知の制約）は、対処しないと決めたため（2026-10-22）tech-debtにせず、decisionのConsequencesに書いた。マージをバックグラウンドで行うと完了の通知が後のツール呼び出しまで出ないことも、49本のPRのマージで分かったため書き足した

## Validation and Acceptance

- `plans-maintenance`ルールと`execution-plan` skillの変更は、`claude-md-maintenance`ルールの手順（比較テスト）を満たす
- pre-commitが`## Branches`を確かめない
- pre-pushが、pushされるブランチの`plan`の`<slug>:<N>`の値ごとに、そのplanのStep NがProgressで未チェックのときに止め、チェック済みのときと`:<N>`のない値だけのときは通す
- 完了検出フックが、`<slug>`と`<slug>:<N>`の両方の形の値を、そのplanのブランチとして数える
- 完了検出フックが、`gh`をスタブにした一時リポジトリで次のとおり動く
  - planの全ブランチがマージ済み（ローカルに残っていても）で、Progressに未チェックがない: 完了処理を知らせる（exit 2）
  - マージ済みのブランチがmainの更新より先に削除された: 完了を正しく判定する
  - 未マージのブランチが1本でもある: 知らせない
  - 全ブランチがマージ済みでも、Progressに未チェックがある: 知らせない
  - 同じ名前で作り直した作業中のブランチがある: 知らせない
  - `gh`が使えない: 判定できなかったことを知らせる
- 設定のないブランチの検出が、main以外で`branch.<name>.plan`のないローカルブランチがあれば挙げ、すべて設定済みなら何も出さない
- 実セッションで、完了検出フックと設定のないブランチの検出が想定した場面に発火する
- `bash -n`でフックスクリプトの構文エラーがない
- active planに`## Branches`が残っていない
