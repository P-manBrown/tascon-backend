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

- docs/plan-branches-section
- docs/git-spice-insert-no-restack

## Progress

- [x] Step1: `plans-maintenance`ルールに`## Branches`の用途と保ち方（作成時に足す、改名で書き換え、PRにせず捨てたら外す）を足し、`execution-plan` skillのブランチを切る手順に、`## Branches`へ足すことを入れる。比較テストを行う。ブランチは比較テストの後に`chore/plan-completion-ignore-branch-deletes`の上へ挿入し、このplanファイルも一緒にコミットする。コミット後、作業ツリーがきれいになってから上の段を`git-spice upstack restack`する。`a717615e`としてコミットした
- [ ] Step2: 今あるactive plan（`plan-work-records.md`・`todoist-task-runner.md`・`lefthook-debride-scope-change.md`）に`## Branches`を書き足し、Progressをチェックボックスの書式にそろえる
- [ ] Step3: pre-commit（`.lefthook/pre-commit/check-docs.sh`）に、planを変更するコミットのとき今のブランチがそのplanの`## Branches`にあることの確認を足す。ブランチ名が取れないとき（detached HEAD）は確かめない
- [ ] Step4: 完了検出フックを「合意した方針」のとおり作り直す。`gh`をスタブに差し替えた一時リポジトリで、Validation and Acceptanceの各場面を確かめる

## 検証結果

- マージ済みPRの確認のコスト（2026-10-21、このリポジトリ）: `gh pr list --state merged --head <branch>`は1本で約0.6秒、`gh pr list --state merged --limit 200 --json headRefName`は200件で約1.0秒だった
- mainのコミットから元のPRを引けるか（2026-10-21）: `gh api repos/{owner}/{repo}/commits/<d365244cのSHA>/pulls`で`#692 feat/task-group-share-self-leave base=main`が返った。1コミットあたり約0.5秒
- Step1の比較テスト（2026-10-21）: planを退避し、「3ステップのplanのStep2用に新しいブランチ`feat/example-step2`を作った。planファイルのどの節に何を書き足すか」を問うと、変更前はProgressのStep2の項目にブランチ名をバッククォート付きで書くと答え（根拠は既存planの書き方と、今の完了検出フックが本文中の`type/name`を拾うこと）、変更後は`Branches`節に`- feat/example-step2`の1行を足すと答えた（根拠は`plans-maintenance`と`execution-plan`）
- `branch create --insert`でステージが外れる原因（2026-10-21、一時リポジトリ）: 上の段が`needs restack`の状態で、変更ファイル1つと新規ファイル1つをステージし、`git-spice branch create c --insert --no-commit`を実行すると、上の段がrestackされ、変更ファイルはステージが外れ（` M`）、新規ファイルはステージされたまま（`A `）だった。上の段が`needs restack`でないときは、restackが起きず、両方ともステージされたままだった。`--no-restack`も付けると、`needs restack`の状態でも両方ステージされたままで、`commit create`で両方がコミットに入り、その後の`upstack restack`も通った
- `--insert`時に`--no-restack`を付ける手順（`git-spice-workflow`）の比較テスト: planを退避し、「上の段が`needs restack`の状態で、ステージした変更を、途中に挿入する新しいブランチの1つのコミットにするコマンド」を問うと、変更前は`branch create --insert --no-commit`（`--no-restack`なし）と答え、変更後は`branch create --insert --no-restack --no-commit`、`commit create --no-restack`、作業ツリーがきれいになってから`upstack restack`と答えた（根拠はSKILL.md）
- ステージが外れる仕組み（2026-10-21、一時リポジトリで`GIT_TRACE`を取得）: `git-spice branch create --insert`は、上の段のrestackで`git rebase --onto <新しい親> --autostash <旧base> <上の段のブランチ>`を実行する。gitの`--autostash`は`git stash create`で作業ツリーとステージを退避し、rebase後に`git stash apply`（`--index`なし）で戻す。`--index`なしのapplyはステージを戻さないため、変更ファイルはステージが外れ、新規ファイルだけがステージされた状態で戻る

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

## Validation and Acceptance

- `plans-maintenance`ルールと`execution-plan` skillの変更は、`claude-md-maintenance`ルールの新規ルール追加時の手順を満たす
- 今あるactive planすべてに`## Branches`があり、Progressがチェックボックスの書式になっている
- pre-commitが、planを変更するコミットで今のブランチが`## Branches`にないときに止め、あるときとplanを変更しないときは通す
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
