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
- [ ] Step6: task-group-share-cancellationの完了処理をやり直す
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
- 2026-10-19: この方式で記録漏れが減らない場合は、エージェント型フック（実験的機能）を試す。
- 2026-10-19: サブエージェント側の確認は、SubagentHandbackへのPreToolUseで行う。SubagentStopで止めても、SubagentHandbackで報告を渡したあとのサブエージェントは作業を続けなかった（サブエージェント自身のトランスクリプトで、SubagentStopのblockingErrorが最終行にあり、その後の応答がないことを確認）。報告を渡す直前に1回だけ拒否して確認を求め、2回目は通す。どのagentが確認済みかは、メインcheckoutの`.claude/record-check-state/<agent_id>`（gitignore）で持つ。SubagentHandbackを使わないサブエージェントのために、SubagentStopの確認も残し、確認済みのagentでは何もしない。

## Validation and Acceptance

- メインセッションのターンの終わりに、Stopフックが確認対象を提示してターンを1回止める。同じターンの2回目のStopでは何も出力しない
- サブエージェントの終了時に、SubagentStopフックが同じ確認対象を提示して1回止める。2回目は何も出力しない
- 旧実装（作業記録ログ・記録用フック・照会スクリプト）がリポジトリに残っていない
- 完了検出フックが、検出時にexit 2でstderrへ出す
- `.claude/plan-completion-state/`が`git status`に現れない
- skill・ルールの変更は、`claude-md-maintenance`ルールの新規ルール追加時の手順（変更前後でのサブエージェントの挙動比較）を満たす
- `bash -n`でフックスクリプトの構文エラーがない。フックの各分岐を、入力JSONを与えて実行して確認する
