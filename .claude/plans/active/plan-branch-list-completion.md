# planに書いた作業ブランチによる完了検出

## Context/Purpose

完了検出フック（`.claude/hooks/plan-completion-check.sh`、Bash実行後のPostToolUse）は、planの本文にある`` `type/name` ``形式の文字列をすべてブランチとして拾い、前回の実行からローカルブランチが消えたか、mainが進んだかで、完了処理の候補を知らせている。この方式には次の問題がある。

- 改名前の名前など、本文に残った古い名前が永久にマージされず、完了と判定できない
- ブランチの削除を手がかりにしているため、マージ済みブランチを消す手順（`git-spice repo sync`等）に依存する。mainの更新とブランチの削除を別々に行うと拾えない

そこで、planに作業ブランチの一覧（`## Branches`）を持たせ、mainに入ったコミットから`gh`でマージされたブランチを特定して、完了を判定する形に作り直す。

## 合意した方針

- planに`## Branches`を設け、そのplanで作業したブランチをすべて書く。ブランチを作ったら足し、改名したら書き換え、PRにせず捨てたら外す
- pre-commitで、`.claude/plans/active/`のplanを変更するコミットのとき、今のブランチがそのplanの`## Branches`にあることを確かめる
- 完了検出フックは次のとおり判定する
  - きっかけ: ローカルのmainが前回の記録から早送りで進んだとき（どのコマンドで進めたかは問わない）
  - 前回から今回までにmainへ入ったコミットごとに、`gh api repos/{owner}/{repo}/commits/<sha>/pulls`でmainへマージされたPRの元のブランチ名を取る（今回マージされたブランチ）
  - 今回マージされたブランチを`## Branches`に書いているactive planを対象にする。planとactive planの一覧は、mainの版（`git show main:<path>`）から読む
  - 対象のplanで、次の両方を満たせば完了とする
    - `## Branches`の全ブランチがマージ済み。今回マージされたブランチは、ローカルにあるかどうかを見ずにマージ済みとする。それ以外は、mainへマージ済みのPRがあり、そのPRの最後のコミットがローカルのブランチの先端と同じ（またはローカルにない）ならマージ済みとする
    - Progressに未チェックの項目（`- [ ]`）が残っていない
  - 完了なら、`execution-plan`の完了処理（Validation and Acceptanceの確認から）を行うよう、stderrとexit 2でエージェントに知らせる
  - `gh`が使えないときは、判定できなかったことを知らせる
  - ローカルブランチの削除は見ない。古い判定（本文中の`type/name`、ブランチの削除）はやめる
- 今あるactive planは、すべて`## Branches`を書き足し、Progressをチェックボックスの書式にそろえる
- 気をつける点
  - 最後のStepのブランチでは、自分のProgressにチェックを付けてからマージする。付け忘れても、後でチェックを付けるコミットのブランチが`## Branches`に入り、それがマージされたときに判定し直される
  - Progressがチェックボックスの書式でないplanは、完了を判定できない

## Branches

- docs/plan-branches-section（Step1）
- docs/git-spice-insert-no-restack
- docs/plan-branches-backfill（Step2）
- chore/plan-branch-precommit（Step3）
- docs/plan-step-progress-rules（Step4）
- docs/plan-progress-format（Step5）
- chore/plan-progress-checks（Step6）

## Progress

- [x] Step1: `plans-maintenance`ルールに`## Branches`の用途と保ち方（作成時に足す、改名で書き換え、PRにせず捨てたら外す）を足し、`execution-plan` skillのブランチを切る手順に、`## Branches`へ足すことを入れる。比較テストを行う。ブランチは比較テストの後に`chore/plan-completion-ignore-branch-deletes`の上へ挿入し、このplanファイルも一緒にコミットする。コミット後、作業ツリーがきれいになってから上の段を`git-spice upstack restack`する。`a717615e`としてコミットした
- [x] Step2: 今あるactive planすべてに`## Branches`を書き足した。Claude関連の段の`plan-work-records`・`todoist-task-runner`（Progressの節も新設）・このplanは`docs/plan-branches-backfill`で、機能側の11個のplanは、それぞれを最後に変更した機能ブランチ（`build/solid-queue`〜`feat/task-due-notification`）にコミットを足した
- [x] Step3: pre-commit（`.lefthook/pre-commit/check-docs.sh`）に、planを変更するコミットのとき今のブランチがそのplanの`## Branches`にあることの確認を足す。ブランチ名が取れないとき（detached HEAD）は確かめない
  - 機能側の`notification-creation`の「残作業: PR作成・マージ」は、マージ前にチェックできないため、チェックボックスを外した注記にした（`feat/notification-on-share-destroy`）。`push-subscription-registration`の未チェックのStep2は、チェック済みのStep2と重複した消し忘れの行だったので消した（`feat/vapid-public-key`）。どちらのコミットも新しいpre-commitを通った
- [x] Step4: `plans-maintenance`ルールに、`## Branches`のStepのブランチには`（StepN）`を書き添えること、Progressのチェックボックスは1つのStepに1つで、変化はその下に箇条書きで時系列に書き足し、Stepでない注記はチェックボックスにしないことを足す。`execution-plan` skillに、Stepを終えたら同じブランチでそのStepにチェックを付けてコミットすることを足す。比較テストを行う
  - `rule-tester`に`.claude/memory/`配下を読まない指示を足し、起動し直してから比較テストをやり直した（結果は検証結果）
- [x] Step5: 今あるplanの`## Branches`にStepを書き添え、Progressを新しい書式（1つのStepに1つのチェックボックス、`- [ ]`/`- [x] StepN:`）にそろえる。機能側のplanは、それぞれを最後に変更した機能ブランチで直す
- [x] Step6: pre-commitに、planを変更するコミットでProgressのチェックボックスの行の形と同じStepNの重複を確かめる処理を足す。pre-pushに、今のブランチの`## Branches`の行にStepがあれば、ProgressのそのStepが`- [x]`かを確かめる処理を足す
  - 2026-10-22: チェックボックスなしの`- StepN:`の行が素通りしていたため、pre-commitで止める確認を足した。一時リポジトリで、`- Step2: b`は止まり、入れ子の`  - Step2の補足`とトップレベルの`- 注記`は止まらないことを確かめた
- [ ] Step7: 完了検出フックを「合意した方針」のとおり作り直す。`gh`をスタブに差し替えた一時リポジトリで、Validation and Acceptanceの各場面を確かめる

## 検証結果

- マージ済みPRの確認のコスト（2026-10-21、このリポジトリ）: `gh pr list --state merged --head <branch>`は1本で約0.6秒、`gh pr list --state merged --limit 200 --json headRefName`は200件で約1.0秒だった
- mainのコミットから元のPRを引けるか（2026-10-21）: `gh api repos/{owner}/{repo}/commits/<d365244cのSHA>/pulls`で`#692 feat/task-group-share-self-leave base=main`が返った。1コミットあたり約0.5秒
- Step1の比較テスト（2026-10-21）: planを退避し、「3ステップのplanのStep2用に新しいブランチ`feat/example-step2`を作った。planファイルのどの節に何を書き足すか」を問うと、変更前はProgressのStep2の項目にブランチ名をバッククォート付きで書くと答え（根拠は既存planの書き方と、今の完了検出フックが本文中の`type/name`を拾うこと）、変更後は`Branches`節に`- feat/example-step2`の1行を足すと答えた（根拠は`plans-maintenance`と`execution-plan`）
- `branch create --insert`でステージが外れる原因（2026-10-21、一時リポジトリ）: 上の段が`needs restack`の状態で、変更ファイル1つと新規ファイル1つをステージし、`git-spice branch create c --insert --no-commit`を実行すると、上の段がrestackされ、変更ファイルはステージが外れ（` M`）、新規ファイルはステージされたまま（`A `）だった。上の段が`needs restack`でないときは、restackが起きず、両方ともステージされたままだった。`--no-restack`も付けると、`needs restack`の状態でも両方ステージされたままで、`commit create`で両方がコミットに入り、その後の`upstack restack`も通った
- `--insert`時に`--no-restack`を付ける手順（`git-spice-workflow`）の比較テスト: planを退避し、「上の段が`needs restack`の状態で、ステージした変更を、途中に挿入する新しいブランチの1つのコミットにするコマンド」を問うと、変更前は`branch create --insert --no-commit`（`--no-restack`なし）と答え、変更後は`branch create --insert --no-restack --no-commit`、`commit create --no-restack`、作業ツリーがきれいになってから`upstack restack`と答えた（根拠はSKILL.md）
- ステージが外れる仕組み（2026-10-21、一時リポジトリで`GIT_TRACE`を取得）: `git-spice branch create --insert`は、上の段のrestackで`git rebase --onto <新しい親> --autostash <旧base> <上の段のブランチ>`を実行する。gitの`--autostash`は`git stash create`で作業ツリーとステージを退避し、rebase後に`git stash apply`（`--index`なし）で戻す。`--index`なしのapplyはステージを戻さないため、変更ファイルはステージが外れ、新規ファイルだけがステージされた状態で戻る
- Step2の確認（2026-10-21）: スタックの最上段（`feat/task-due-notification`）で、`.claude/plans/active/`の14個のplanすべてに`## Branches`があり、1本以上のブランチが書かれていることを確かめた。機能側の11個のコミットのあと、`needs restack`は出なかった。Progressはすべてチェックボックスの書式だった
- Step3のpre-commitの確認（2026-10-21、一時リポジトリ）: `bash -n`が通った。一覧にある→exit 0、一覧にない→exit 1と「does not list the current branch」、`## Branches`がない→exit 1、active planをステージしていない→exit 0、detached HEAD→確かめずexit 0、バッククォートと空白付きの記載→exit 0、ステージ済みの内容が正しく作業ツリーが誤り→exit 0、その逆→exit 1、`active/`配下のサブディレクトリのplan→対象外でexit 0、の9場面とも期待どおりだった
- 文書チェックの実行箇所（2026-10-21、設定ファイルで確認）: `.lefthook/pre-commit/check-docs.sh`は、lefthookのpre-commitと、Claude Codeの`PostToolUse`（`Edit|Write`）の`.claude/hooks/check-docs-hook.sh`の両方から実行される
- `rule-tester`がmemoryを読まないか（2026-10-21、起動し直し後）: 「できるだけ多くの文書を探して読め」と指示しても、トランスクリプトのツール呼び出し24回に`.claude/memory/`配下を読んだものはなかった。ファイルを探す検索の結果にmemoryのファイル名の一覧だけは出たが、中身は入らなかった
- Step4の比較テスト（planと`rule-tester.md`以外の変更を退避）: 「Step2を途中で方針を一部変えつつブランチ`feat/example-step2`で終えた。`## Branches`と`## Progress`に何をどう書くか」を問うと、変更前は`- feat/example-step2`（Stepなし）を足し、Step2の行の文面を書き換えて経緯も同じ行に書いた。変更後は`- feat/example-step2（Step2）`とし、Step2のチェックボックスにチェックを付け、方針の変更はその下に箇条書きで書き足し、同じブランチでコミットすると答えた（根拠は`plans-maintenance`と`execution-plan`）。memoryが混ざった最初の変更前テストは無効にした
- Stepの書き添えとStep3のpre-commitの確認（2026-10-21）: `## Branches`に`- docs/plan-step-progress-rules（Step4）`と書いてコミットすると、Step3の確認が行全体を完全一致で比べていたため「does not list the current branch」で止まった。末尾の`（…）`を取り除いてから比べる形に直し、一時リポジトリで`- test-branch（Step2）`・`` - `test-branch`（Step2） ``・`- test-branch`は通り、`- other-branch（Step2）`と節がない場合は止まることを確かめた。Step3のときの9場面も、直した後に同じ結果だった
- Step5の確認（2026-10-21、スタックの最上段`feat/task-due-notification`）: 14個のplanすべてで、Progressのチェックボックスの行が`- [ ]`/`- [x] StepN: `の形で、同じStepNの重複がなく、`## Branches`にStepの書き添えが1つ以上あった。各コミットは新しいpre-commitの確認を通り、restack後に`needs restack`は出なかった。最初のコミットは、planを変更するブランチ（`docs/plan-progress-format`）が`plan-work-records`・`todoist-task-runner`の一覧になく止まったため、両planに足した
- Step6のpre-commitとpre-pushの確認（2026-10-21、一時リポジトリ）: `bash -n`が通った。pre-commitは、正しいProgress→0、字下げしたチェックボックス・Stepでないチェックボックス・コロンのないStep行・大文字の`[X]`・同じStepの重複→1、Progress以外の節のチェックボックス→0、detached HEADでも書式の誤り→1、ステージ済みの内容で判定、サブディレクトリのplanは対象外、の11場面とも期待どおりだった。pre-pushは、`（Step2）`でStep2がチェック済み→0、未チェック→1、Stepの書き添えなし・一覧にない・削除のpush・ブランチ以外のref→0、2本のうち1本が未チェック→1、pushするコミット時点のplanで判定する（作業ツリーとは逆の結果）、の11場面とも期待どおりだった。実際のリポジトリでは、全ローカルブランチを入力してexit 0、`lefthook run pre-push`経由でも標準入力が渡り、Step4を未チェックにした一時コミットで止まることを確かめた

## Decision Log

- 2026-10-21: 完了検出を、planに書いた作業ブランチの一覧（`## Branches`）と、`gh`で特定したマージ済みのPRで判定する形に作り直す。本文中の`type/name`とローカルブランチの削除による古い判定はやめる（ユーザー指示）。古い名前が残ると完了と判定できず、削除を手がかりにすると、マージ済みブランチを消す別の手順に依存するため。
- 2026-10-21: きっかけはローカルのmainが進んだときとし、マージされたブランチは、mainに入ったコミットから`gh`で元のPRのブランチ名を取って特定する。ローカルブランチの削除は見ない（ユーザー指摘）。`git-spice repo sync`等の別の手順の前提に依存させず、mainの更新とブランチの削除を別々に行っても判定できるようにするため。
- 2026-10-21: 対象は、今回マージされたブランチを`## Branches`に書いているactive planだけにする（ユーザー指示）。planが増えても、全planを調べずに済むため。
- 2026-10-21: 今回マージされたブランチは、ローカルにあるかどうかを見ずにマージ済みとする（ユーザー指摘）。`gh`で特定した時点でマージが確定しているため。それ以外のブランチは、mainへマージ済みのPRがあり、その最後のコミットがローカルの先端と同じ（またはローカルにない）ならマージ済みとする。PRがないローカルだけのブランチや、同じ名前で作り直した作業中のブランチを、未完了と判定するため。この条件なら名前の使い回しで誤判定しないので、ブランチ名の重複は禁止しない。
- 2026-10-21: 完了の条件に、Progressに未チェックの項目が残っていないことを足す（ユーザー指摘）。まだ手を付けていないStepにはブランチがなく、`## Branches`だけでは判定に入らないため。
- 2026-10-21: Validation and Acceptanceはフックの条件に入れず、フックは完了処理（Validationの確認から）を行うよう知らせるだけにする（ユーザー指摘）。Validationは文の箇条書きで機械的に判定できず、`execution-plan`の完了処理の手順1でエージェントが確かめるため。
- 2026-10-21: planとactive planの一覧は、作業ツリーではなくmainの版から読む（ユーザー同意）。完了は「mainに全部入った」ことで、開いているブランチの版はmainと違いうるため。
- 2026-10-21: `## Branches`の正しさは、pre-commitで、planを変更するコミットのとき今のブランチが一覧にあるかで確かめる。PRにせず捨てたブランチは一覧から外す（ユーザー同意）。一覧にないブランチは判定の外になり、捨てたブランチが残るといつまでも完了にならないため。
- 2026-10-21: 今あるactive planは、すべて`## Branches`を書き足す新しいやり方に更新する（ユーザー指示）。
- 2026-10-21: `git-spice branch create`でスタックの途中に挿入するときは`--no-restack`も付け、上の段のrestackはコミット後に作業ツリーがきれいになってから行う旨を`git-spice-workflow` skillに足す（ユーザー指示）。挿入時に上の段がrestackされると、ステージした変更ファイルのステージが外れ、コミットから漏れるため（Step1のコミットで実際に起きた）。
- 2026-10-21: 既存planの`## Branches`は、Claude関連の段にあるplan（`plan-work-records`・`todoist-task-runner`・このplan）は`docs/plan-branches-backfill`で、機能側のブランチにしかないplanは、そのplanを最後に変更した機能ブランチに足すコミットで書き足す（ユーザー同意）。機能側のplanはClaude関連の段に存在せず、最後に変更したブランチに足せば、上の段のrestackで衝突しないため。`lefthook-debride-scope-change`は機能側（`build/debride-full-scope`・`feat/cable-ticket`）で更新されているので、機能側で扱う。一覧には、そのplanのStepとして作業したブランチと、planのファイルを変更したブランチを入れる。
- 2026-10-21: Stepとブランチの対応は`## Branches`の行に`（StepN）`を書き添えて表し、Stepの行にはブランチ名を書かない（ユーザー同意）。1つのStepに1つのブランチとは限らず（Stepでないブランチもある）、ブランチ名を書く場所を2か所にすると、両方に書いたかの確認が別に要るため。
- 2026-10-21: Progressのチェックボックスは1つのStepに1つとし、Stepの変化はチェックボックスを増やさず、その下に箇条書きで時系列に書き足す。Stepでない注記はチェックボックスにしない（ユーザー提案）。Stepでない「PR作成・マージ」や、重複したStepの行が未チェックで残り、planが完了にならなかったため。
- 2026-10-21: 書き方が守られているかを機械的に確かめる（ユーザー指摘）。pre-commitで、planを変更するコミットのときProgressのチェックボックスの行の形と同じStepNの重複を確かめる。pre-pushで、今のブランチの`## Branches`の行にStepがあれば、ProgressのそのStepが`- [x]`かを確かめる。pushはStepを終えてレビューへ出すときなので、作業途中のコミットは止めないため。planを変更しないStepのブランチも、Stepを終えたらチェックを付けるコミットでplanを変更するので、pre-commitの一覧の確認を通る。
- 2026-10-21: `rule-tester`に、`.claude/memory/`配下を読まない指示を足す（ユーザー指示）。`omitClaudeMd`でmemoryの自動の差し込みは外れるが、`.claude/memory/`は作業ディレクトリ内にありReadで読めてしまい、gitignoreのため`git stash -u`でも退避されない。Step4の変更前テストで実際に`feedback_plan_section_usage.md`を根拠に読んでいた。
- 2026-10-21: pre-pushの確認は、今のブランチではなく、pushされる各ブランチ（pre-pushの標準入力）を対象にし、planはそのブランチのコミット時点の内容で読む。git-spiceは別のブランチを開いたままpushすることがあり、作業ツリーのplanはpushされるブランチの内容と違いうるため。
- 2026-10-22: pre-commitで、Progressのトップレベルにチェックボックスなしで`- StepN:`と書いた行も止める（ユーザー指摘）。チェックボックスを含む行だけを確かめていたため、Stepの行をチェックボックスなしで書くと素通りしていた。入れ子の箇条書きと、トップレベルのStepでない注記は止めない。

## Validation and Acceptance

- `plans-maintenance`ルールと`execution-plan` skillの変更は、`claude-md-maintenance`ルールの新規ルール追加時の手順を満たす
- 今あるactive planすべてに`## Branches`があり、Progressがチェックボックスの書式になっている
- pre-commitが、planを変更するコミットで今のブランチが`## Branches`にないときに止め、あるときとplanを変更しないときは通す
- pre-commitが、Progressのチェックボックスの行の形が違うとき、同じStepNが重複するときに止める
- pre-pushが、今のブランチの`## Branches`の行にStepがあり、ProgressのそのStepが未チェックのときに止める
- 完了検出フックが、`gh`をスタブにした一時リポジトリで次のとおり動く
  - planの全ブランチがマージ済みで、Progressに未チェックがない: 完了処理を知らせる（exit 2）
  - 一部のブランチだけマージ済み: 知らせない
  - 全ブランチがマージ済みでも、Progressに未チェックがある: 知らせない
  - mainの更新とブランチの削除を別々に行った: 完了を正しく判定する
  - マージ済みのブランチがローカルに残っている: 完了を正しく判定する
  - 同じ名前で作り直した作業中のブランチが一覧にある: 未完了とする
  - 改名、不要なブランチの削除（mainは進まない）: 知らせない
  - `gh`が使えない: 判定できなかったことを知らせる
- `bash -n`でフックスクリプトの構文エラーがない
