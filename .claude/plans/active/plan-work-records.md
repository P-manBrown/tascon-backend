# 作業中の記録漏れを防ぐ確認フック

## Context/Purpose

作業中に生じた決定・指摘・教訓・技術的負債等が、定められた記録先に書かれないまま漏れることがある。漏れると、後から確認する手段がない。

当初は、execution-planの完了処理でclaude-memを照会して漏れを監査する前提だった。照会の絞り込みには、planの`Worktree:`行から作るclaude-memのproject識別子を使う想定だった。task-group-share-cancellationの完了処理（2026-10-19）で、次のことが判明した。

- claude-mem 14.0.1は、フック入力の`cwd`より環境変数`CLAUDE_PROJECT_DIR`（メインリポジトリ）を優先するため、worktree内の作業もすべてproject=`tascon-backend`として記録される
- claude-memの通常のインターフェース（MCPの`search`・`timeline`・`get_observations`・`build_corpus`等）は、セッション・ターン・agentで絞り込めず、出力にもそれらのキーが含まれない（実際に呼び出して確認）
- キーで正確に引けるのは、ワーカーの内部HTTP APIかDBの直接読み込みだけで、どちらも通常の使い方ではなく、claude-memの実装変更で使えなくなる

そのため、完了処理でclaude-memから正確に記録を引くことはできない。記録の主軸を、作業中のその場での記録に移す。メインセッションのStopと、サブエージェントのSubagentHandbackへのPreToolUseのタイミングで、各skill・ruleが定める「その場で記録すべきもの」をすべて記録したかを確認させる。完了処理でのclaude-memの照会は、通常の検索で追加の記録候補を探す補助とする。

## 合意した方針

- メインセッションではStopで、確認用フックが毎ターン1回だけ`decision: block`で止める。`stop_hook_active`がtrueなら何もしない。サブエージェントではSubagentHandbackへのPreToolUseで1回目を拒否し、2回目は状態ファイルを削除して通す
- 確認させる対象は、各skill・ruleが作業中のその場での記録を定めているもの。具体的な内容はそれぞれのskill・ruleに任せ、フックには書き写さない
  - planの`Decision Log`・`Progress`（`plans-maintenance`ルール）
  - 技術的負債の新規記録・更新（`tech-debt-tracker` skill）
  - Todoistへの進捗コメント（`todoist-task-runner` skill）
  - memory（ユーザーの指摘・好み・プロジェクトの事情）
- `docs/decisions/`・rules/skill・`ARCHITECTURE.md`への反映は、従来どおり完了処理で行う（`docs/decisions/feedback-reflection-timing.md`）
- 作業記録ログ（agent・セッションのキー）、その記録用フック、claude-memの照会スクリプトは廃止する
- 完了処理の手順2は、claude-memを通常の検索ツールで照会し、planに関係していてまだ記録されていない決定・教訓等があれば記録する、という指示にする
- `Worktree:`行は廃止する（照会に使えないため）
- 完了検出フック（`plan-completion-check.sh`）の状態ファイルは`.claude/plan-completion-state/`（gitignore）に置き、検出時はexit 2でstderrへ出す

## Progress

- [x] Step1: 完了検出フックの状態ファイルを`.claude/plan-completion-state/`へ移し、`.gitignore`に登録した（ブランチ`chore/plan-completion-hook`）
  - 追加: 完了検出フックを、`additionalContext`の注入から、検出時にexit 2でstderrへ出す形に変えた（`chore/plan-completion-hook`のコミットを修正）。状態ファイルに削除済みブランチを足して実行し、検出時はexit 2とstderrの通知、同じ状態での2回目はexit 0で出力なしになることを確認した
- [x] Step2: 確認用フックを追加した（ブランチ`chore/plan-work-records`）。`.claude/hooks/record-check.sh`をStop・SubagentStop・PreToolUse(SubagentHandback)に登録した。入力JSONによる各分岐の確認に加え、実セッションで次を確認した: Stopがターンを1回止める／SubagentHandbackの1回目が拒否され、サブエージェントが記録の要否を判断してから2回目の報告で通る／SubagentStopが状態ファイルを片付ける。ローカルの`.claude/plan-records/`は削除済み
  - 旧実装（`plan-record.sh`・`plan-record-agent.sh`・`plan-record-stop.sh`、PostToolUse(Agent)の登録、`.gitignore`の`/.claude/plan-records/`）を取り除く
  - Stop・SubagentStop共通の確認用フックを追加し、`.claude/settings.json`に登録する
- [x] Step3: `Worktree:`行の仕組みを廃止した（ブランチ`chore/retire-plan-worktree-lines`）。コミットメッセージから作業記録ログへの言及を除いた。Step2の書き換えに伴うrestackで、`settings.json`とこのplanファイルの競合を解消した（SubagentStopから`plan-worktree-check.sh`の登録だけを外し、planは書き換え後の内容を採用）
- [x] Step4: execution-plan skillの完了処理の手順2を、claude-memの通常の検索で、まだ記録されていない決定・教訓等を洗い出す指示にした（ブランチ`docs/plan-records-completion-query`。照会スクリプトは削除）。文脈を持たないサブエージェントでtask-group-share-cancellationの手順2をリハーサルし、変更前（`Worktree:`行の識別子で照会して0件になり、照会条件を独自に作った）から、通常の検索ツールで候補を集め、リポジトリと照合して分類する挙動に変わることを確認した
- [x] Step5: decisionの見直し（ブランチ`docs/record-check-decision`）。`check-docs.sh`が通ることを確認した。`plan-worktree-path-format.md`はDeprecated、`feedback-reflection-timing.md`は新しいdecision`record-check-and-completion-reflection.md`によるSupersededにする
  - `docs/decisions/plan-worktree-path-format.md`・`docs/decisions/feedback-reflection-timing.md`の前提（worktreeごとのproject識別子で絞り込める）が実態と異なるため、`decisions-maintenance`ルールに従いStatusを更新する
- [x] Step6: task-group-share-cancellationの完了処理をやり直す。手順1〜8を実施し報告済み（`docs/complete-task-group-share-cancellation-plan`のコミットに、Decision Logの訂正とRSpecの判断を追記）。残っていたサブエージェントのworktree 12個と`worktree-agent-*`ブランチ12本は、未コミットの変更がなく内容がブランチかmainにあることを確認して削除した。未決だった2点はStep7で扱う
- [x] Step7: worktreeでのRails起動手順を`bruno-endpoint-verification` skillに、使い終わったworktreeの削除基準と手順を`todoist-task-runner` skillに書く。いつもの形（Agentの`isolation: "worktree"`）で試験用worktreeを作り、起動と削除を実際に確かめる。いつもの形で作った試験用worktree（コミット1つ・detach済み）から起動とBruno Sign Inが通ることを確認し、skillの手順で`--force`なしに削除できた（無視ファイルが残っていても削除でき、`worktree-agent-*`ブランチは`-d`で削除できた）
  - `git stash`に退避した編集（Decision Log・Progressの追記、stash名`cancellation-plan-completion-redo`）を戻して使う
  - 結果は手順ごと・候補ごとに報告する
- ローカルの`.claude/plan-records/`（旧実装のログ）は、Step2のあとに削除する。照会スクリプトのシェル化の作業途中の変更は、stash（`abandoned: query script shell rewrite (plan-work-records)`）に退避した
- [x] Step8: ルールの比較テストを専用サブエージェント`rule-tester`（`.claude/agents/rule-tester.md`）とstash方式で行う形に変えた（ブランチ`docs/rule-test-subagent`、コミット`412f3cc9`）。Decision Logを決定と理由だけに絞り、テストの結果は「検証結果」へ移した。残りは次のとおり
  - 「検証結果」節の追加、ブランチを比較テストの後に作る手順、Stopフックの文言の修正、このplanの書き直しは、`docs/plan-verification-results`（`docs/rule-test-subagent`の上に挿入）にコミットした（`9b7b8b4e`）。「`branch create`は`--no-commit`で作り、`commit create`でコミットする」の`git-spice-workflow` skillへの追記は、比較テストの後、`docs/plan-verification-results`の上に挿入した`docs/git-spice-branch-create-no-commit`にコミットした
- [x] Step9: 完了検出フック（`plan-completion-check.sh`）が、マージ以外のローカルブランチの削除（改名、不要なブランチの削除）にも反応する問題を直す（ユーザー指摘）。改名（`docs/rule-test-headless-session`→`docs/rule-test-subagent`）と空のブランチの削除で、実際に反応した。消えたブランチは、同じ実行でmainも進んでいたときだけマージとして扱う形に直す（Decision Log）
- [x] Step10: フックの状態ファイルを`.claude/hook-state/<フック名>/`へまとめ、`record-check.sh`に古い状態ファイルの片付けを足す（ブランチ`chore/hook-state-dir`、`chore/plan-steps-fail-text`の上）
  - 変更対象: `record-check.sh`（`.claude/hook-state/record-check/`、実行のたびに24時間より古いファイルを削除）、`plan-completion-check.sh`（`.claude/hook-state/plan-completion/`）、`.gitignore`（2行を`/.claude/hook-state/`の1行に）
  - 実装はCodexへ委譲する。既存の状態ファイルの移行は手作業で1回だけ行う（`plan-completion-state/main`は新しい場所へ移し、`record-check-state/`の取り残し9個は削除）
  - 実装・移行・確認を終えた（検証結果）
  - `chore/plan-steps-fail-text`は`docs/notification-architecture`と同じ`docs/trim-verification-status-rule`から枝分かれしていたため、`docs/notification-architecture`以上を`chore/hook-state-dir`の上へ移し、一直線にした（ユーザー指示）。枝分かれを見落としたのは、`git-spice ls`が`--all`なしでは今のブランチの上下だけを表示し、兄弟のブランチを表示しないため。`git-spice-workflow` skillの「作成前に`git-spice ls`で最上段を確認する」の扱いは未決
  - skillの確認手順を`git-spice ls --all`にする（ユーザー指示、Decision Log）。比較テストを終えてコミットした
  - 比較テストでSkillツールが古い内容を返す問題に、`claude-md-maintenance`ルールの手順で対処する（ユーザー指示、Decision Log）。比較テストを終えた（検証結果）

## 検証結果

変更前後の比較テスト等、Decision Logの決定を確かめた結果を記録する。

- worktreeのskill（Step7）: worktreeの片付けは、変更前は削除せずユーザーに確認すると答え、変更後は4条件を確かめて確認なしで削除すると答えた。Rails起動は、変更前も設定ファイルから`-b`と`RAILS_MASTER_KEY`を導いたが、Codexのプロンプトを`pgrep`で見られる状態だったため参考程度。Puma停止は、変更前`pkill -f puma`（確認なし）、変更後`pkill -f '^puma '`と`pgrep -af '^puma '`。Pumaを起動し、`puma`を含むコマンド行のシェルから実行して、Puma本体とSolid Queueの子プロセスだけが止まり、シェルは止まらないことを確認した
- worktreeでのPuma起動: 試験用worktreeから起動し、`-b`で設定ファイルの`bind`が置き換わること、`bru run "Auth/Sign In.bru"`がnginx経由でPASSし、リクエストがworktreeの`log/development.log`に記録されること、ログに鍵が出ないことを確認した
- 「今のplanに関わる問題はその場で直す」: コミット済みの状態（`f00d0a9`）で、直前のStepで実装したコードのN+1に気づく場面を与えると、AGENTS.mdとplanの受け入れ基準を根拠に、そのplanで直すと答えた（変更前から正しい）
- フック文言・execution-plan手順3の修正: 修正前（`e79492e`）も修正後も、記録先は`.claude/rules/controllers.md`・`codex-delegation` skillで同じだった。修正前は食い違いを指摘してルールを優先し、修正後は指摘がなくなった
- コメント言語のrule・SKILL.mdに確認状況を書かない件・push済みブランチ: 変更前は、コメントを日本語で書き（根拠はシステムプロンプトの言語指定）、未確認の手順をSKILL.mdに加え、push済み`feat/`ブランチの改名を提案した。変更後は、コメントを英語で書き（根拠は`code-comments.md`）、未確認の手順は加えずplanに記録し、改名せずPRタイトルを`chore`にすると答えた。「未確認の手順を追加する場合も…」の文言では未確認の手順を加えたため、今の文言に直して再テストした（4回とも加えなかった）
- 状態ファイルの置き場所と片付け（Step10）: 入力JSONを与えて直接実行し、次を確認した。SubagentHandbackの1回目は`deny`を返し`.claude/hook-state/record-check/<agent_id>`を作り、2回目は何も出さずに削除する。25時間前のファイルは消え、23時間前のファイルは残る。対象外のツール・`stop_hook_active: true`・ディレクトリがない場合は何も出さずexit 0。`plan-completion-check.sh`は、ディレクトリがなければ`.claude/hook-state/plan-completion/main`を作り、今のmainを記録する。`.claude/hook-state/`は`git status --ignored`で無視対象と表示される。実セッションでは、変更後のスクリプトでStopがターンを1回止め、テスト用サブエージェントのSubagentHandbackが1回だけ拒否されて2回目で通り、状態ファイルが残らなかった
- `git-spice ls --all`（Step10）: 「READMEの誤字修正のブランチを作る前に何を実行し、どのブランチの上に作るか」を問うと、変更前（`77f97711^`）は2回とも`git-spice ls`（`--all`なし）と答え、変更後は2回とも`git-spice ls --all`で枝分かれを含めて最上段を確かめると答えた。変更後の最初の2回は、Skillツールが変更前の内容を返したため`git-spice ls`と答えており、判定に使っていない。`git stash pop`でSKILL.mdを戻しただけでは変更後の内容が読み込まれず、`touch`で更新日時を変えた後に読み込まれた
- Skillツールの内容の一致を確かめる手順（Step10、対象: `claude-md-maintenance.md`）: 「`execution-plan`のSKILL.mdの完了処理に1行足した。コミットまでに何をするか、コマンドや起動するエージェントまで具体的に」を問うと、変更前は2回ともSkillツールの内容を確かめる手順に触れず、変更後は2回とも、変更前・変更後のテストの前に`rule-tester`にSkillツールで引用させて作業ツリーと一致するか確かめ、ずれていれば`touch`してから確かめ直すと答えた。ルールはどの回も差し込まれていた（変更を退避した変更前の状態でテストし、テスト対象のコミット・detachは不要だった）
- `--no-restack`: claude-memなし・記録前のworktreeで、変更前は3回中2回が未コミットのまま`git-spice commit create`を使い、変更後は3回とも`--no-restack`でコミットし、作業ツリーがきれいになってから1回restackした
- SubagentStopの登録を外した件: テスト用のサブエージェントのトランスクリプトで、1回目のSubagentHandbackが拒否され、2回目で通り、状態ファイルが削除され、SubagentStopのフックが実行されないことを確認した
- Todoistの作成先の移動: 変更前も変更後もインボックスに作ると答え、根拠が`tech-debt-tracker`から`todoist-task-conventions`に変わった
- memoryの混入: Agentツールのgeneral-purposeサブエージェントにはMEMORY.mdの索引とCLAUDE.mdが入り、Exploreにはどちらも入らなかった。claude-memのセッション開始時の差し込みはメインセッションにだけ入る。`claude -p --setting-sources project,local`にはMEMORY.mdの索引が入り、`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`で入らなくなった
- `rule-tester`の文脈: claude-memの過去の記録が付くファイルを読ませても、記録は付かなかった。MEMORY.md・memoryの内容も入らなかった。入ったのはcodebase-memoryの案内文、MCPの指示、pathsで差し込まれるルール、記録確認フック、gitStatus等のsystem-reminder、context-modeの案内文。gitStatusにはブランチ名と直近のコミットが含まれる
- 比較テストの手順（`rule-tester`・stash方式）: 変更前は`claude -p`の旧手順、変更後は`rule-tester`とstashの手順で答えた。`.claude/agents/`を退避しない一文は、変更前が`rule-tester.md`も退避、変更後が退避しない。テスト対象以外を先に退避する書き換えは、変更前がplanとルールをまとめて退避・復帰、変更後がplanを先に退避して最後に戻すと答えた。`git stash push -u -- . ':(exclude)<対象>'`は、一時リポジトリで対象だけが残り、他の変更と未追跡ファイルが退避され、2回のpopで戻ることを確かめた
- コミットメッセージの書き方: planを退避して2回テストした（1回目はブランチ名が見えていたため無効。2回目は親ブランチでブランチ名を隠し、途中のコミットメッセージを含む経緯を時系列で与えた）。追記前から、親コミットからの差分だけでメッセージを書き、採らなかった案はbodyに入れなかった（根拠はPRのChangesを最終状態で書く規定と、bodyに目的・理由を書く規定）
- 比較テストの結果の書き込み先（`plans-maintenance`に「検証結果」を足し、`claude-md-maintenance`の手順5の書き込み先をそこにする）: planを退避し、「比較テストを終えた結果をplanのどの節にどう書くか」を問うと、変更前は`Decision Log`に決定と一緒に書くと答え（根拠は既存planの書き方）、変更後は`検証結果`節に書き、Decision Logには書かないと答えた
- gitStatusを止める設定: Claude Code 2.1.305の本体で、gitStatusの事前読み込みは`includeGitInstructions`（環境変数`CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS`が優先）が真のときだけ行われる。偽にすると、組み込みのコミット・PRの手順もシステムプロンプトから外れる。サブエージェントだけを対象にする項目は見つからなかった。実際にサブエージェントのgitStatusが消えるかは未確認
- サブエージェント単位でgitStatusを外せるか: Claude Code 2.1.305の本体で、サブエージェント起動時に`omitGitStatus`が付くのは`agentType`が`Explore`か`Plan`の場合だけで、固定で書かれている。エージェント定義の項目（`tools`・`model`・`permissionMode`・`hooks`・`omitClaudeMd`・`isolation`等18個）に、環境変数・設定値を渡す項目やgitStatusを外す項目はない。コードを読んだだけで、実際の動作では確かめていない
- サブエージェントの文脈のgitStatus（実際の動作）: 組み込みのExploreには入らなかった。`rule-tester`には入っていた（ブランチ名・変更ファイル・直近のコミット5件）。セッション中に`rule-tester.md`へ足した項目と目印は反映されなかった（エージェント定義の書き換えは、起動し直すまで反映されない）
- エージェント定義でgitStatusを外せるか（起動し直し後）: `rule-tester.md`に`omitGitStatus: true`・`env: CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS: "1"`と目印を足して起動し直すと、目印は出た（定義は反映された）が、gitStatusは入っていた。gitStatusは依頼メッセージに付くsystem-reminderの中にあり、セッション開始時点のスナップショット（ブランチ名・変更ファイル・直近のコミット5件）だった。確認後、`rule-tester.md`は元に戻した
- ブランチを作るタイミング（`claude-md-maintenance`の手順5に「変更内容を表すブランチを作るのは、ここまで終えた後にする」を足す）: planと`plans-maintenance`を退避し、「ルールを足す作業で、ブランチ作成・編集・比較テスト・コミットをどの順で行うか」を問うと、変更前はルールを編集する前にブランチを作ると答え、変更後はテストと記録を終えてからブランチを作り、最後にコミットすると答えた（根拠は手順5）
- Stopフックの文言の修正: `bash -n`が通り、入力JSONを与えて、Stopで`block`と新しい文言、`stop_hook_active`が真で出力なし、SubagentHandbackの1回目で`deny`と新しい文言、2回目で通過と状態ファイルの削除を確認した
- `git-spice branch create --insert`でのコミット: lefthookの`protect-branch`（`git branch --show-current`が`main`でないことを確かめる）に失敗し、ブランチもコミットも作られなかった。HEADを切り離した状態でコミットするため、出力が空になると見られる。`--no-commit`でブランチを挿入し、`git-spice commit create --no-restack`でコミットすると通った
- `branch create`に`--no-commit`を付ける手順（`git-spice-workflow`）: planを退避し、「ステージ済みの変更で、スタックの途中に新しいブランチを挿入して1つのコミットにするコマンド」を問うと、変更前は`git-spice branch create docs/example-change --insert -m ...`で作成と同時にコミットすると答え（`--no-commit`はステージしていない変更が残る場合だけ）、変更後は`branch create --insert --no-commit`でブランチだけを作り、`commit create`でコミットすると答えた（根拠はSKILL.md）
- `refs/backup/reorder-20261020/*`の削除前の確認: バックアップにあるmain以外のコミット129個のsubjectを、今のブランチとmainのコミットと照合した。128個は同じsubjectがあり、残る1個（`docs: retire the git workaround noted in active plans`）は`b768188a`・`83c1e54d`の2つに分けられて今のブランチにあった
- 完了検出フックの修正（Step9）: `bash -n`が通った。一時リポジトリ（planに`feat/x`・`feat/abandon`を記載）で、改名（`feat/x`→`feat/x2`）と、mainを進めずに`feat/abandon`を削除したときは出力なし・exit 0だった。mainにコミットを足して`feat/x`を削除すると、「mainへのマージを検出した」と完了処理の候補をstderrに出してexit 2だった。修正前のフックでは、同じ改名で「mainへのマージまたはローカルブランチの削除を検出した」と出た
- 「動作確認の状況（確認済み・未確認）や進行状況は書かない。書く場所は対象のplanファイル。」を`claude-md-maintenance`の執筆原則から削る件: skillに試して動いた手順Aと未確認の手順Bを足す場面で、SKILL.mdの文面とほかに書くことを問うと、変更前・変更後とも3回ずつ、Bは加えずplanに未確認と記録し、Aにも確認状況を書かず、確認したことはplanに書くと答えた。変更前は削る文を、変更後は「理由・経緯は書かない…今の正しい手順だけに絞る」を根拠に挙げた
- 無効にしたテスト: Decision Logを先に書いたplanを読んで答えたもの、claude-memの差し込み（過去の失敗の記録）を根拠にしたもの、テスト対象を退避して`rule-tester`自体が消えたもの、ブランチ名から作成中のルールを推測したものは、比較に使わずやり直した

## Decision Log

- 2026-10-19: 作業記録ログによる照会をやめ、記録の主軸を作業中のその場での記録に移す。Stopと、サブエージェントの報告前に、各skill・ruleが定める記録をすべて行ったかを確認させる。claude-memの通常のインターフェースではセッション・ターン・agentで絞り込めず、正確に引けるのは内部HTTP APIかDBの直接読み込みだけで、どちらも実装変更で使えなくなるため。チェックアウト中のブランチ（`gitBranch`）は無関係なターンが混ざり、トランスクリプトは`cleanupPeriodDays`で削除されるため、どちらも正本にしない。Python・sqliteへの依存も避ける（フロントエンドでも使い回すため）。過去に撤回した方式（`docs/decisions/feedback-reflection-timing.md`）との関係は次のとおり。
  - Stopの注入による無限ループ: `decision: block`と`stop_hook_active`の確認で防ぐ
  - prompt hookの自己言及による誤判定: 会話全体を持つ本体に判断させる
  - 反映は人間のレビュー後: 確認対象は、その場での記録が既に定められているものに限り、`docs/decisions/`・rules/skillへの反映は従来どおり完了処理で行う
- 2026-10-19: 確認対象は、各skill・ruleがその場での記録を定めているものすべてにする（ユーザー指示）。書き損じると後から確かめる手段がないため。
- 2026-10-19: 完了検出フックの状態ファイルは`.git`配下ではなく`.claude/`配下（gitignore）に置く。`.git`配下は、git公式が外部ツール用に定めた置き場所ではないため。
- 2026-10-19: 完了検出フックは、検出時にexit 2でstderrへ出す。`docs/decisions/reminder-hooks-removal.md`が、文言を注入するだけのhookを禁止しているため。
- 2026-10-19: 完了処理の手順に「claude-memの照会が正確でない」旨は書かない（ユーザー指示）。実行時に意味がなく、自明なため。
- 2026-10-19: この方式で記録漏れが減らない場合は、エージェント型フックを試す。試す場合は、plan-worktree-check-scopeのDecision Log（2026-10-14）にある採らない理由（experimental、停止のたびのコスト、非決定的な結果）に答える必要がある。
- 2026-10-19: AskUserQuestion向けの専用フックは作らない。回答はターン内のツール結果として返り、そのターンの終わりにStopフックが確認するため。
- 2026-10-19: サブエージェント側の確認は、SubagentHandbackへのPreToolUseで、報告の直前に1回だけ拒否して行う。SubagentStopで止めても、報告を渡したあとのサブエージェントは作業を続けないため。確認済みのagentはメインcheckoutの`.claude/record-check-state/<agent_id>`（gitignore）で持ち、2回目で削除する。SubagentStopの登録は外す（ユーザー指示）。完了通知だけで始まったターンでStopを止めない案は採らない。
- 2026-10-19: task-group-share-cancellationの完了処理の候補は次のとおり扱う（ユーザー回答）。`bin/rails runner`が止まる件は、再実行で2秒で終了したためtech-debtに記録しない。旧worktree（`agent-a7729d0959ce38cc6`）は、未コミットの変更がなく内容が#692でマージ済みのため削除した。plan-worktree-check-scopeは中止としてcompletedへ移した。
- 2026-10-19: 残すメリットのないworktreeは、確認せずに削除できるよう基準を`todoist-task-runner` skillに書く（ユーザー指示）。いちいち削除の確認をやり取りしないため。確認なしの削除を認めたのはworktreeについてだけで、不要物一般ではない（ユーザー指摘）。
- 2026-10-20: worktreeでのRails起動手順を`bruno-endpoint-verification` skillに書く（ユーザー指示）。過去のworktree作業で、master.keyのsymlink作成や、worktree側`tmp/sockets`がないための起動失敗があったため。起動は、`config/master.key`をコピー・リンクせず、メインcheckoutの鍵を`RAILS_MASTER_KEY`で渡し、`-b`でメインcheckoutの`tmp/sockets/puma.sock`にバインドする。nginxはメインcheckoutの`tmp/sockets`（名前付きボリューム）だけを見るため。worktreeから起動したPumaはworktreeの`.env*`を読むため、Brunoの`FRONTEND_ORIGIN`はそれに合わせる。
- 2026-10-20: Pumaの停止・確認は先頭固定の`'^puma '`にし、このplanで直す（ユーザー指示）。`pkill -f puma`は呼び出し元のシェルまで止め、このplanの起動・停止手順とworktree削除の条件に関わるため。`pkill -f`のパターンは、Puma以外でも先頭で固定する。
- 2026-10-20: claude-mem等の外部リポジトリへの機能要望・issue・PRは出さない（ユーザー指示）。個人の運用方針のためmemoryに残す。
- 2026-10-20: 「今のplan・直前の変更に関わる問題はtech-debtに回さずその場で直す」は、skillにもmemoryにも書かない。変更前の状態で既に、AGENTS.mdとplanの受け入れ基準からそう判断できたため。
- 2026-10-20: 確認用フックの文言と`execution-plan` skillの完了処理の手順3を、`claude-md-maintenance`ルール（memoryは個人の内容に限り、プロジェクト全体の内容はCLAUDE.md・rules・skillsへ）に合わせる（ユーザー指摘）。メインセッションでは実際にフック文言に従ってプロジェクトの事情をmemoryへ書いたため。ルールの追加ではなく食い違いの解消のため、比較テストで記録先が変わらなくても取り消さない。
- 2026-10-20: プロジェクト全体に関わる既存memoryはドキュメントへ移す（ユーザー指示）。コードコメントの言語は、AGENTS.mdではなくコードのパスに紐付くruleに書く。コミットメッセージの機械チェック・security-reviewの毎回実行は`docs/decisions/`へ移す。レビュー自動化2件の見送りは、個人的で結論が変わりうるため、TodoistのInbox（`6hpQWR8rvmr8VFGH`）に残す。Zed・CBMの2件は再現を確かめてから、tech-debt `cbm-daemon-stale-socket-blocks-start`（`6hpQWVwp8MHGXG5q`）・`zed-devcontainer-postcreate-not-run`（`6hpQvfXPg7VGQx5q`）として記録した。memory「Claude Code改善ブランチは機能ブランチより下に置きたい」は今回だけの事情のため削除した（ユーザー指摘）。
- 2026-10-20: SKILL.md/rulesには、動作を確認していない手順を加えず、未確認であることをplanに記録する、と書く。「未確認の手順を追加する場合も、未確認であることはplanに記録する」の文言では、未確認の手順をSKILL.mdに加えたため。
- 2026-10-20: 未コミットの変更が残っている間は`--no-restack`でコミットし、作業ツリーがきれいになってから上のブランチをrestackする手順を`git-spice-workflow` skillに加える（ユーザー指示）。未コミットの変更を残したまま`git-spice commit create`を実行し、restack後に元のブランチへ戻れず、次のコミットが別のブランチへ入ったため。
- 2026-10-20: Todoistの新規タスクの作成先（インボックス）を`tech-debt-tracker` skillから`todoist-task-conventions` skillへ移す（ユーザー指示）。共通ルールに作成先の記述がなく、tech-debtの手順にだけあったため。
- 2026-10-20: ルール・skillの比較テストでは、個人のmemoryと個人の設定を常に外す（ユーザー指摘）。ruleはプロジェクト全体で共有するが、memoryは個人のもので、memoryが効いて変化が出なかった場合にruleをノイズとして消すと、memoryを持たない環境でruleが欠けるため。
- 2026-10-20: 比較テストは、`omitClaudeMd: true`・読み取り専用の専用サブエージェント`rule-tester`で行う（ユーザー同意）。Agentツールで普通に呼ぶサブエージェントには個人のmemoryが入り、`claude -p`はサブスクリプションと別料金になるおそれがあるため。auto memoryだけを外す定義の項目はなく、`omitClaudeMd`はCLAUDE.mdと一緒にmemoryも外すので、CLAUDE.md・AGENTS.mdは定義の指示で最初に読ませる。
- 2026-10-20: 比較テストは`isolation: "worktree"`を使わず、メインのcheckoutで`git stash`により変更前と変更後の状態を作る（ユーザー同意）。worktreeは既定でmainから作られ、pathsで差し込まれる`.claude/rules`はworktreeではなくメインのcheckoutのディスク上のファイルであるため、worktreeでは変更前の状態を再現できない。
- 2026-10-20: ルールの手順には理由を書かない（ユーザー指示）。rulesに理由を書かない執筆原則のとおり、理由はこのDecision Logに書く。
- 2026-10-20: 比較テストでは、テスト対象のルール・skill以外の未コミット変更を先にすべて退避し、両方のテストが終わるまで戻さない（ユーザー同意）。決定を先に書いたplan等が変更前テストに混ざるため。退避するファイルを列挙すると対象が増えるたびに書き足す必要が出るので、原則で書く。`.claude/agents/`を退避しない一文は書かない（ユーザー指示）。`rule-tester.md`がコミット済みなら、`.claude/agents/`を変更しない限り退避の対象にならないため。
- 2026-10-21: コミットメッセージを親コミットの状態から書き、採らなかった案を出発点にしない旨は、`git-spice-workflow` skillに書かない（ユーザー指示）。変更前テストで、既存の規定から正しく書けたため。
- 2026-10-21: 比較テストの結果は、planの「検証結果」に書く。`plans-maintenance`ルールの各節の用途に「検証結果」を足し、`claude-md-maintenance`ルールの比較テストの手順の書き込み先をそこにする（ユーザー同意）。書き込み先が決まっておらず、結果をDecision Logに書いてしまったため。
- 2026-10-21: 比較テストの文脈に入るgitStatusは、設定ではなく手順の側で避ける。変更内容を表すブランチは比較テストの後に作る（ユーザー指示）。エージェント定義に`omitGitStatus`・`env`を足しても外れず、外せる`includeGitInstructions`はメインセッションのgitStatusと組み込みのコミット・PRの手順まで外すため。gitStatusはセッション開始時点のスナップショットで、テスト前に作ったブランチの名前から変更内容が漏れる。
- 2026-10-21: Stopフック・SubagentHandbackの確認文言の記録対象に、planの「検証結果」を足す（ユーザー指示）。比較テストの結果の書き込み先を「検証結果」にしたため。今回の変更は、Claude関連の変更の最上段（`docs/rule-test-subagent`の上、`docs/notification-architecture`の下）に新しいブランチ`docs/plan-verification-results`を挿入してコミットする（ユーザー指示）。
- 2026-10-21: 「Claude関連の変更をClaude関連の最上段に積む」は今回だけの扱いで、skillには書かない（ユーザー指示）。
- 2026-10-21: `git-spice branch create`でブランチを作るときは`--no-commit`を付け、コミットは`git-spice commit create`で行う旨を`git-spice-workflow` skillに足す（ユーザー指示）。`branch create`で直接コミットすると、lefthookの`protect-branch`に失敗するため。
- 2026-10-21: ブランチ`docs/rule-test-headless-session`を`docs/rule-test-subagent`に改名した（ユーザー指示）。中身がヘッドレスのセッション（`claude -p`）を使わなくなったため。スタックの並べ替え時のバックアップ`refs/backup/reorder-20261020/*`（35個）と、採らなかった照会スクリプトのstash`query script shell rewrite (plan-work-records)`は削除した（ユーザー指示）。
- 2026-10-21: 完了検出フックは、消えたローカルブランチを、同じ実行でmainも進んでいたときだけマージとして扱う（ユーザー指示）。ブランチは改名や不要なブランチの削除でも消え、そのたびに反応していたため。手順どおりのマージでは`git-spice repo sync`がmainの更新とマージ済みブランチの削除を1回で行うので、マージは拾える。mainの更新とブランチの削除を別のコマンドで行った場合は、そのブランチの削除を拾えないが、mainの変更が触ったplanは拾える。
- 2026-10-21: 完了検出を、planに書いた作業ブランチの一覧とマージ済みのPRで判定する形への作り直しは、このplanではなく、新しいplanと別のブランチで行う（ユーザー指示）。作り直しに関わる検証結果は新しいplanへ移す。
- 2026-10-22: `claude-md-maintenance`の執筆原則から「動作確認の状況（確認済み・未確認）や進行状況は書かない。書く場所は対象のplanファイル。」を削り、「動作を確認していない手順は加えず、未確認であることをplanに記録する」だけを残す（ユーザー指示）。確認状況を書かないことは「今の正しい手順だけに絞る」で足り、書く場所は残した一文とplanの節の用途で足りるため。
- 2026-10-22: SubagentHandbackの1回目だけを止めるための状態ファイルは残す。公式ドキュメント（hooks reference）では、`stop_hook_active`はStop・SubagentStopの入力にしかなく、PreToolUseの入力には前回拒否したかを示す欄も`agent_transcript_path`もなく、`once: true`はskill・agentで定義したフックにしか効かないため。ただし2回目の報告が来ないと状態ファイルが残り続け、実際に9個残っていたので、`record-check.sh`が実行のたびに24時間より古いものを消す（ユーザー指示）。誤って消しても確認がもう1回出るだけで済む。
- 2026-10-22: フックの状態ファイルは、メインcheckoutの`.claude/hook-state/<フック名>/`にまとめる（ユーザー同意）。どのフックの状態かを名前で分かるようにするため。git管理の`.claude/hooks/`に混ぜると管理対象と対象外が同じ場所に並び、worktree間で共有するのでworktree内の`.claude/hooks/`は使えないため、別のディレクトリにする。名前は、保存した状態の意味のstateが不可算で使われるため単数形にする（XDGの`~/.local/state`と同じ）。
- 2026-10-22: `git-spice-workflow` skillのブランチ作成前の確認を`git-spice ls --all`にする（ユーザー指示）。`git-spice ls`は`--all`なしでは今のブランチの上下だけを表示し、同じ親から分かれた兄弟のブランチを表示しないため、skillどおりに確認しても枝分かれを見落とし、`chore/hook-state-dir`を枝分かれした側に積んだ。
- 2026-10-22: skillの比較テストでは、`rule-tester`を起動する前に、Skillツールが返す内容が作業ツリーと一致することを`rule-tester`の引用で確かめ、一致しなければ対象のファイルを`touch`して確かめ直す手順を`claude-md-maintenance`ルールに足す（ユーザー指示）。git（stash・switch）でSKILL.mdを書き換えた直後に、Skillツールが書き換え前の内容を返すことが2回起きたため（`plan-branch-config`のStep1、このplanのStep10）。1回目は時間を置いて、2回目は`touch`の後に切り替わった。何が切り替えのきっかけかは確かめていないが、一致を確かめる手順があれば、古い内容でのテストを判定に使わずに済む。

## Validation and Acceptance

- メインセッションのターンの終わりに、Stopフックが確認対象を提示してターンを1回止める。同じターンの2回目のStopでは何も出力しない
- サブエージェントが報告を渡す前に、SubagentHandbackへのPreToolUseフックが同じ確認対象を提示して1回拒否し、2回目は状態ファイルを削除して通す
- 旧実装（作業記録ログ・記録用フック・照会スクリプト）がリポジトリに残っていない
- 完了検出フックが、検出時にexit 2でstderrへ出す
- `.claude/hook-state/`が`git status`に現れない
- `record-check.sh`の実行で、`.claude/hook-state/record-check/`の24時間より古い状態ファイルが削除され、新しいものは残る
- skill・ルールの変更は、`claude-md-maintenance`ルールの新規ルール追加時の手順（変更前後でのサブエージェントの挙動比較）を満たす
- `bash -n`でフックスクリプトの構文エラーがない。フックの各分岐を、入力JSONを与えて実行して確認する
