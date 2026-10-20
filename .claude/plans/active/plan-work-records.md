# 作業中の記録漏れを防ぐ確認フック

## Context/Purpose

作業中に生じた決定・指摘・教訓・技術的負債等が、定められた記録先に書かれないまま漏れることがある。漏れると、後から確認する手段がない。

当初は、execution-planの完了処理でclaude-memを照会して漏れを監査する前提だった。照会の絞り込みには、planの`Worktree:`行から作るclaude-memのproject識別子を使う想定だった。task-group-share-cancellationの完了処理（2026-10-19）で、次のことが判明した。

- claude-mem 14.0.1は、フック入力の`cwd`より環境変数`CLAUDE_PROJECT_DIR`（メインリポジトリ）を優先するため、worktree内の作業もすべてproject=`tascon-backend`として記録される
- claude-memの通常のインターフェース（MCPの`search`・`timeline`・`get_observations`・`build_corpus`等）は、セッション・ターン・agentで絞り込めず、出力にもそれらのキーが含まれない（実際に呼び出して確認）
- キーで正確に引けるのは、ワーカーの内部HTTP APIかDBの直接読み込みだけで、どちらも通常の使い方ではなく、claude-memの実装変更で使えなくなる

そのため、完了処理でclaude-memから正確に記録を引くことはできない。記録の主軸を、作業中のその場での記録に移す。StopとSubagentStopのタイミングで、各skill・ruleが定める「その場で記録すべきもの」をすべて記録したかを確認させる。完了処理でのclaude-memの照会は、通常の検索で追加の記録候補を探す補助とする。

## 合意した方針

- StopとSubagentStopの両方で、1つの確認用フックが、毎ターン（サブエージェントは終了時）1回だけ`decision: block`で止める。`stop_hook_active`がtrueなら何もしない
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
- [x] Step1追加: 完了検出フックを、`additionalContext`の注入から、検出時にexit 2でstderrへ出す形に変えた（`chore/plan-completion-hook`のコミットを修正）。状態ファイルに削除済みブランチを足して実行し、検出時はexit 2とstderrの通知、同じ状態での2回目はexit 0で出力なしになることを確認した
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

## Decision Log

- 2026-10-19: claude-memの照会キーを、worktreeのproject識別子から、agent_idとセッションID＋時刻へ変更する。worktreeごとのprojectは`CLAUDE_PROJECT_DIR`の優先処理により作られず、メインセッションの作業はagent_idでも引けないため。
- 2026-10-19: メインセッションの作業の特定に、チェックアウト中のブランチ（トランスクリプトの`gitBranch`）は使わない。planのブランチを開いたまま無関係な作業をしたターンが混ざり、別のブランチを開いたままplanのQ&Aをしたターンは漏れるため（今回の照合で、余計なターンが9件あった）。また、トランスクリプトは`cleanupPeriodDays`（既定30日）で削除される。
- 2026-10-19: claude-mem側の設定で、worktree単位の記録にすることは採らない。worktreeで起動した専用セッションで作業すれば、projectは分かれる見込み（未検証）だが、サブエージェントへの委譲・質問のエスカレーション・親セッションでのレビューという現在の作業の流れを作り直す必要があるため。
- 2026-10-19: 記録はplanファイルではなく、gitignoreしたログに置く。メインセッションのcheckoutはplanのブランチとは限らず、planファイルへ書くと、無関係なブランチに未コミットの変更が残るため。
- 2026-10-19: ログは`.git`配下ではなく`.claude/`配下（gitignore）に置く。`.git`配下は、git公式（gitrepository-layout）が外部ツール用に定めた置き場所ではないため。完了検出フックの状態ファイルも同じ理由で移す。
- 2026-10-19: トランスクリプトは正本にしない。`cleanupPeriodDays`（既定30日、最小1）で削除されるため。
- 2026-10-19: 完了検出フックは、`additionalContext`による注入をやめ、検出時にexit 2でstderrへ出す形にする。`docs/decisions/reminder-hooks-removal.md`（Accepted）が、文言を注入するだけのhookを禁止しているため。
- 2026-10-19: 方針を変更し、作業記録ログによる照会をやめる。claude-memの通常のインターフェースでは、セッション・ターン・agentで絞り込めず（`search`に`agentId`・`contentSessionId`を渡しても結果が変わらない、`get_observations`の出力にキーがない、`save_memory`で目印を付けても検索は意味的で完全一致にならない）、正確に引けるのは内部HTTP APIかDBの直接読み込みだけだった。どちらも通常の使い方ではなく、claude-memの実装変更で使えなくなるため採らない。Python・sqliteへの依存も避ける（Rubyのプロジェクトで、フロントエンド（Next.js）でも使い回すため）。
- 2026-10-19: 記録の主軸を、作業中のその場での記録に移す。StopとSubagentStopで、各skill・ruleが定める記録をすべて行ったかを確認させる。過去に撤回した方式との関係は次のとおり（`docs/decisions/feedback-reflection-timing.md`のConsidered Options）。
  - Stopの`additionalContext`注入による無限ループ: `decision: block`と`stop_hook_active`の確認で防ぐ（旧記録用フックで、ループしないことを実運用で確認済み）
  - prompt hookの自己言及による誤判定: 判定を軽量モデルに任せず、会話全体を持つ本体（メインまたはサブエージェント自身）に判断させる
  - `PostToolUse(Agent)`が起動直後に発火する問題: サブエージェントの終了時に発火するSubagentStopを使う
  - 反映は人間のレビュー後に完了処理で行う方針: 確認対象は、その場での記録が既に定められているもの（planの`Decision Log`等）に限り、`docs/decisions/`・rules/skillへの反映は従来どおり完了処理で行う
- 2026-10-19: 確認対象は「planのDecision Logに書くべき決定」に限らず、各skill・ruleがその場での記録を定めているものすべてにする。書き損じると後から確認する手段がないため、漏れをできるだけ減らす（ユーザー指示）。
- 2026-10-19: 完了処理の手順に「claude-memの照会が正確でない」旨は書かない。実行時に意味がなく、自明なため（ユーザー指示）。
- 2026-10-19: この方式で記録漏れが減らない場合は、エージェント型フック（実験的機能）を試す。なお、plan-worktree-check-scopeのDecision Log（2026-10-14）に、agent hookを採らない理由（公式ドキュメント上experimental、停止のたびのコスト、結果が非決定的）がある。試す場合はこれらの理由に答える必要がある。
- 2026-10-19: AskUserQuestion向けの専用フック（廃止済みの`ask-user-question-decision-reminder.sh`の再導入）は作らない。AskUserQuestionの回答はターン内のツール結果として返り、そのターンの終わりにStopフックが確認する。実際にAskUserQuestionで4件の判断を受けたターンの終わりに、Stopフックが止めて記録の確認を求めることを確認した（ユーザー指示による検証）。
- 2026-10-19: task-group-share-cancellationの完了処理の候補について、ユーザーの回答を受けて次のとおり扱う。`bin/rails runner`が止まる件は、再実行すると2秒で終了し`/home/ruby`にも書き込めたため、tech-debtに記録しない。旧worktree（`agent-a7729d0959ce38cc6`）は、未コミットの変更がなく、HEADのコミットと同じ内容が#692でマージ済みのため削除した。plan-worktree-check-scopeは中止としてcompletedへ移した。
- 2026-10-19: 残すメリットのないworktreeは、確認せずに削除できるよう基準を文書化する（ユーザー指示。いちいち削除の確認をやり取りしたくないため）。
- 2026-10-19: サブエージェント側の確認は、SubagentHandbackへのPreToolUseで行う。SubagentStopで止めても、SubagentHandbackで報告を渡したあとのサブエージェントは作業を続けなかった（サブエージェント自身のトランスクリプトで、SubagentStopのblockingErrorが最終行にあり、その後の応答がないことを確認）。報告を渡す直前に1回だけ拒否して確認を求め、2回目は通す。どのagentが確認済みかは、メインcheckoutの`.claude/record-check-state/<agent_id>`（gitignore）で持つ。SubagentHandbackを使わないサブエージェントのために、SubagentStopの確認も残し、確認済みのagentでは何もしない。
- 2026-10-20: worktreeでのRails起動手順は、セキュリティ上安全で正常に起動できる方法で`bruno-endpoint-verification` skillに書く。worktreeの削除基準と手順もskillに書き、試験用worktreeで削除できることを確かめる（ユーザー指示）。claude-mem等の外部リポジトリへの機能要望・issue・PRは出さない（ユーザー指示）。
- 2026-10-20: worktreeでのPuma起動は、`config/master.key`をコピー・リンクせず、メインcheckoutの鍵を`RAILS_MASTER_KEY`環境変数で渡し、`-b`でメインcheckoutの`tmp/sockets/puma.sock`にバインドする。nginxはメインcheckoutの`tmp/sockets`（名前付きボリューム`puma-sockets`）だけを見るため、worktree側の`tmp/sockets`にバインドしても届かない。試験用worktreeから起動し、`-b`で設定ファイルの`bind`が置き換わること（worktree側に`tmp/sockets`がなくても起動）、`bru run "Auth/Sign In.bru"`がnginx経由でPASSし、リクエストがworktreeの`log/development.log`に記録されること、ログに鍵が出ないことを確認した。worktreeから起動したPumaはworktreeの`.env*`を読むため、Brunoの`FRONTEND_ORIGIN`はそれに合わせる（メインcheckoutの`.env.local`の値とは異なり得る）。
- 2026-10-20: skill変更前後の比較テストは、比較対象の記録（このplanの未コミットのDecision Log等）を読めない、コミット済みの状態から作ったworktree（scratchpadの`wt-before`）を文書の参照先にして行う。最初の変更前テストは、このDecision Logを読んで変更後と同じ答えを返したため、比較にならなかった。
- 2026-10-20: 比較テストの結果。worktreeの片付けは、変更前は削除せず「削除してよいかユーザーに確認が要る」と答え（拒否されたら`--force`を付ける案も出した）、変更後は4条件を確かめて確認なしで削除すると答えた。Rails起動は、変更前も設定ファイルを読んで`-b`と`RAILS_MASTER_KEY`を自力で導いたが、`-b`が効くかは未確認として扱った（実行中のCodexのプロンプトを`pgrep`で見られる状態だったため、比較は参考程度）。変更後は手順どおりの答えになった。過去の実際のworktree作業で、master.keyのsymlink作成やworktree側`tmp/sockets`がなく起動に失敗した例があるため、起動手順はskillに残す。
- 2026-10-20: `pkill -f puma`が呼び出し元のシェルまで止める問題は、tech-debtに回さずこのplanで直す。このplanで書いた起動・停止手順と、worktree削除の条件（Pumaが残っていない）に関わるため（ユーザー指示）。停止・確認は先頭固定の`'^puma '`にする。Pumaを起動し、`puma`を含むコマンド行のシェルから`pgrep -af '^puma '`・`pkill -f '^puma '`を実行して、Puma本体だけに一致すること、シェルが止まらず後続のコマンドが動くこと、Solid Queueの子プロセスも一緒に止まることを確認した。変更前後のskill（`f00d0a9`と現在）を文脈なしのサブエージェントに読ませて「検証後にPumaを止め、残っていないか確かめるコマンド」を聞くと、変更前は`pkill -f puma`（確認方法はなし）、変更後は`pkill -f '^puma '`と`pgrep -af '^puma '`と答えた。
- 2026-10-20: 確認なしの削除を認めたのはworktreeについてだけで、不要物一般ではない（ユーザー指摘）。worktreeの削除基準を`todoist-task-runner` skillに書いたため、memory`feedback_delete_without_asking`は削除した。このmemoryを根拠に確認なしで捨てたstash（廃案の照会スクリプト）は、`git stash store`で戻した。
- 2026-10-20: 「今のplan・直前の変更に関わる問題はtech-debtに回さずその場で直す」は、memoryではなく`tech-debt-tracker` skillの新規記録の手順に書く（ユーザー指示）。memoryは削除した。
- 2026-10-20: 上記をskillに書く前に、変更前の挙動をコミット済みの状態（`f00d0a9`）の文書だけで確かめた。Puma件と無関係な場面（直前のStepで自分が実装したコードのN+1に気づく）を与えると、文脈なしのサブエージェントは、AGENTS.mdの「自分が生んだ問題は片付ける」やplanの受け入れ基準を根拠に、tech-debtに回さずそのplanで直すと答えた。`claude-md-maintenance`ルールの「変更前後で挙動が変わらないルールは追加しない」に従い、skillには書かない。Puma件の場面を使った最初のテストは、claude-memのフックがPuma件の実際の処理記録を差し込み、質問文も範囲内と示していたため比較に使わなかった。
- 2026-10-20: 調査中に作ったclaude-memのテスト記録#2298（タグ照会の検証用、決定を含まない）は、ユーザーの指示でworkerの`DELETE /api/observation/2298`で削除した。取得が404になり、検索にも出ないことを確認した。
- 2026-10-20: 確認用フックの文言「memory（ユーザーの指摘・好み・プロジェクトの事情）」は、`claude-md-maintenance`ルール（2026-10-08のPR #646で決定。memoryはプロジェクト全体・将来のセッションに影響しない個人の内容に限り、プロジェクト全体の内容はCLAUDE.md・rules・skillsへ書く）に反する（ユーザー指摘）。`execution-plan` skillの完了処理の手順3（「影響する個人の作業スタイル・経緯等 → memory」）もルールと逆になっている。ユーザーの指示で、両方とclaude-md-maintenanceルールと食い違う他の記述をルールに合わせて直す。
- 2026-10-20: スタックの並べ替え後に作ったmemory「Claude Code改善ブランチは機能ブランチより下に置きたい」は、今回だけの事情で常に下へ置く方針ではない（ユーザー指摘）ため削除した。外部リポジトリへ要望・issue・PRを出さない方針はユーザー個人の運用方針のためmemoryに残す。既存memoryのうちプロジェクト全体に関わるものは、別ブランチでドキュメントへ移す。
- 2026-10-20: 修正前の挙動を、コミット済み状態（`e79492e`）のworktreeだけを読む文脈なしのサブエージェントで確かめた。Stopフックで止まった場面で「APIエラーのJSONキーはsnake_case」という指示を与えると`.claude/rules/controllers.md`へ、plan完了処理でCodex委譲プロンプトの書き方に関する作業スタイルを与えると`codex-delegation` skillへ記録すると答え、いずれもmemoryを選ばなかった。ただし両方ともフック文言・手順3とルールの食い違いを指摘してルール側を優先しており、メインセッションでは実際にフック文言に従ってプロジェクトの事情をmemoryへ書いたため、食い違いを解消する。
- 2026-10-20: 修正後の2ファイルだけをコミット済み状態に重ねたworktreeで同じ2場面を確かめた。記録先は修正前と同じ（`.claude/rules/controllers.md`、`codex-delegation` skill）で、食い違いの指摘はなくなり、フック文言・手順3からそのまま`claude-md-maintenance`ルールの判断へ進んだ。ルールの追加ではなく既存ルールとの食い違いの解消のため、記録先が変わらないことは修正を取り消す理由にしない。

## Validation and Acceptance

- メインセッションのターンの終わりに、Stopフックが確認対象を提示してターンを1回止める。同じターンの2回目のStopでは何も出力しない
- サブエージェントが報告を渡す前に、SubagentHandbackへのPreToolUseフックが同じ確認対象を提示して1回拒否し、2回目は通す。SubagentHandbackを使わずに終わるサブエージェントは、SubagentStopフックが1回止める
- 旧実装（作業記録ログ・記録用フック・照会スクリプト）がリポジトリに残っていない
- 完了検出フックが、検出時にexit 2でstderrへ出す
- `.claude/plan-completion-state/`が`git status`に現れない
- skill・ルールの変更は、`claude-md-maintenance`ルールの新規ルール追加時の手順（変更前後でのサブエージェントの挙動比較）を満たす
- `bash -n`でフックスクリプトの構文エラーがない。フックの各分岐を、入力JSONを与えて実行して確認する
