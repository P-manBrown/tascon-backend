# planの作業記録（claude-mem照会キー）の仕組み

## Context/Purpose

execution-planの完了処理の手順2では、claude-memを照会して、planの期間中に生じた決定・教訓の記録漏れを監査する。これまでは、planの`Worktree:`行（サブエージェントのworktreeの絶対パス）から、claude-memのproject識別子（`<リポジトリ名>/<worktree名>`）を作って絞り込む前提だった。

task-group-share-cancellationの完了処理（2026-10-19）で、この前提が実データと合わないと判明した。

- claude-mem 14.0.1は、フック入力の`cwd`より環境変数`CLAUDE_PROJECT_DIR`（メインリポジトリ）を優先する（`normalizeInput`内の処理）。そのため、worktree内のサブエージェントの作業も、すべてproject=`tascon-backend`として記録される。DBの全テーブルで、projectの値は`tascon-backend`の1種類だけだった。
- worktreeは、記録の`agent_id`でしか区別できない。
- planの作業の大半（36ターン中34ターン）は、メインセッションでのレビュー・Q&A・PR作成だった。メインセッションの作業には、planと結びつくキーが記録されない。

claude-mem上でplanの作業を一意に特定できるキーは、次の2つだけである。

- サブエージェントの作業: `agent_id`。入れ子の子エージェントは、親のAgent呼び出しの応答に含まれる`agentId`からたどれる（実データで確認済み）。
- メインセッションの作業: セッションID＋ターン。ターンは、時刻からclaude-memの`user_prompts`（その時刻以前で最新のプロンプト）として特定する。

このplanでは、作業時にこの2つのキーをplanごとのログへ機械的に記録する。完了処理では、そのログのキーだけでclaude-memを照会する（キーワード検索・意味的な判定は使わない）。

## 合意した方針

- 記録は、起動・作業した側であるメインセッションが行う（サブエージェント自身には書かせない）
  - サブエージェント: メインセッションがAgentツールで起動したとき、その`agentId`を記録する。入れ子の子エージェントは記録しない（完了時に親の応答から求める）
  - メインセッション: planの作業をしたターンについて、セッションIDと時刻を記録する
- planの作業かどうかの判断は、そのターンのAIが行う。フックは、毎ターンの終わりに1回だけ判断の機会を作り、記録すべきキーを提示する
- 記録の置き場所は`.claude/plan-records/{active,completed}/<plan名>.log`とし、`.gitignore`に登録する
  - planファイルと同じ名前で1対1に対応させる。完了時はplanと一緒にcompletedへ移し、削除しない
  - 書き込み先は常にメインcheckoutの`.claude/plan-records/`とする（worktree側には書かない）
  - 共有・長期保管は目的にしない。ローカルのclaude-mem DBを引くための補助とする
- `Worktree:`行は廃止する。既存のactive planの`Worktree:`行は書き換えず、`agent-<id>`を各planのログへ1回だけ移す
- 完了検出フック（`plan-completion-check.sh`）の状態ファイルを、`.git/claude-plan-completion/`から`.claude/`配下（gitignore）へ移す

## Progress

- [ ] Step1: 完了検出フックの状態ファイルを`.claude/plan-completion-state/`へ移し、`.gitignore`に登録する（既存ブランチ`chore/plan-completion-hook`のコミットを修正）
- [ ] Step2: 作業記録の仕組みを追加する（このブランチ`chore/plan-work-records`）
  - 記録用スクリプト（planを指定してagent/session行を追記する）
  - PostToolUse(Agent)フック: メインセッションが起動したagentの`agentId`を、そのターンの未記録リストへ入れる
  - Stopフック: 毎ターン1回、そのターンのキーと未記録のagentを提示する。`stop_hook_active`がtrueなら何もしない
  - `.claude/settings.json`への登録、`.gitignore`への`.claude/plan-records/`追加
- [ ] Step3: `Worktree:`行の仕組みを廃止する
  - `plan-worktree-check.sh`とSubagentStopの登録を削除する
  - `plans-maintenance`ルールの`Worktree:`行の条項を、作業記録の手順に置き換える
  - todoist-task-runner skillの該当記述を更新する
  - 既存のactive planの`Worktree:`行の`agent-<id>`を、各planのログへ移す（ローカルのみ、コミット対象外）
- [ ] Step4: execution-plan skillの完了処理を更新する
  - 手順2を、ログのキー（agent_idと子孫、セッションID＋時刻）で照会する形にする
  - 手順6に、ログをcompletedへ移すことを加える
  - 記録漏れのチェックを加える: トランスクリプトが残っている間は、planのブランチ上にいたターン（`gitBranch`）とplanファイル・ブランチを操作したターンを抽出し、ログに無いものを「記録漏れの可能性あり」として報告する。自動では採用せず、確認してから扱う
  - 既存ブランチ`docs/execution-plan-completion-steps`のclaude-mem照会の記述（agent_idのみで照会する案）は、このStepの内容に差し替える
- [ ] Step5: decisionの見直し
  - `docs/decisions/plan-worktree-path-format.md`・`docs/decisions/feedback-reflection-timing.md`の前提（worktreeごとのproject識別子で絞り込める）が実態と異なるため、`decisions-maintenance`ルールに従いStatusを更新し、新しいdecisionを作成する
- [ ] Step6: task-group-share-cancellationの完了処理をやり直す
  - 過去分のログがないため、例外として調査で特定したキーを使う（サブエージェント: `a7729d0959ce38cc6`と子孫3件、`ae0a7cfc395dd57ff`・`a1a4e06cd1a16cd94`・`aa0768ea75bc77c11`。メインセッション: 0bd3d40e p50〜51、dd986fdd p1〜3、5c77b302 p1〜19、fa98268e p1〜12）
  - `git stash`に退避した編集（Decision Log・Progressの追記、stash名`cancellation-plan-completion-redo`）を戻して使う
  - 結果は手順ごと・候補ごとに報告する

## 未検証事項（実装時に確認する）

- Stopフックに渡される`session_id`が、claude-memの`content_session_id`と一致するか
- PostToolUse(Agent)の`tool_response`から`agentId`を確実に取得できるか（claude-memの`tool_uses`には含まれていた）
- PostToolUse(Agent)・Stopフックの入力で、メインセッションとサブエージェントを区別できるか（`agent_id`フィールドの有無）
- 時刻からターンを特定する方法で、ターンの途中にユーザーが送ったメッセージの扱いがずれないか

## Decision Log

- 2026-10-19: claude-memの照会キーを、worktreeのproject識別子から、agent_idとセッションID＋時刻へ変更する。worktreeごとのprojectは`CLAUDE_PROJECT_DIR`の優先処理により作られず、メインセッションの作業はagent_idでも引けないため。
- 2026-10-19: メインセッションの作業の特定に、チェックアウト中のブランチ（トランスクリプトの`gitBranch`）は使わない。planのブランチを開いたまま無関係な作業をしたターンが混ざり、別のブランチを開いたままplanのQ&Aをしたターンは漏れるため（今回の照合で、余計なターンが9件あった）。また、トランスクリプトは`cleanupPeriodDays`（既定30日）で削除される。
- 2026-10-19: claude-mem側の設定で、worktree単位の記録にすることは採らない。worktreeで起動した専用セッションで作業すれば、projectは分かれる見込み（未検証）だが、サブエージェントへの委譲・質問のエスカレーション・親セッションでのレビューという現在の作業の流れを作り直す必要があるため。
- 2026-10-19: 記録はplanファイルではなく、gitignoreしたログに置く。メインセッションのcheckoutはplanのブランチとは限らず、planファイルへ書くと、無関係なブランチに未コミットの変更が残るため。clone時にログが失われる点は、照会先のclaude-mem DBも同様にcloneでは引き継がれないため、許容する。
- 2026-10-19: ログは`.git`配下ではなく`.claude/`配下（gitignore）に置く。`.git`配下は、git公式（gitrepository-layout）が外部ツール用に定めた置き場所ではないため。完了検出フックの状態ファイルも同じ理由で移す。
- 2026-10-19: トランスクリプトは正本にせず、完了処理での記録漏れチェックにだけ使う。今回のplanで、記録を全て忘れたと仮定した場合にトランスクリプト側の手がかりで拾えたのは36ターン中34ターン、無関係な候補は9ターンだった（plan1件の測定のみ）。`cleanupPeriodDays`（既定30日）で削除されるため、残っている範囲だけで行う。Stopフックでの対象plan候補の提示は採らない。フック発火時点ではトランスクリプトに直近のメッセージが入っていないことがあり（公式ドキュメント hooks の Common input fields）、毎ターンの処理も増えるため。
- 2026-10-19: 既存の`Worktree:`行は書き換えず、ログへ1回だけ移す。planファイルへの記録自体をやめるため書き換えても使い道がなく、skillに旧形式の読み替えを残すと手順が二重になるため。

## Validation and Acceptance

- メインセッションでAgentツールを使ったターンの終わりに、Stopフックがそのターンのキーと起動したagentの`agentId`を提示する。記録用スクリプトで記録すると、`.claude/plan-records/active/<plan名>.log`に行が追加される
- 同じターンで2回目のStopでは、フックが何も出力しない
- サブエージェント内のAgent起動・Stopでは、フックが記録・提示をしない
- `.claude/plan-records/`と`.claude/plan-completion-state/`が`git status`に現れない
- execution-plan skillの完了処理のリハーサルで、ログのキーだけからclaude-memの該当記録を取得できる（文脈を持たない新規サブエージェントで確認する）
- 同リハーサルで、ログから意図的に外したターンが「記録漏れの可能性あり」として報告される
- skill・ルールの変更は、`claude-md-maintenance`ルールの新規ルール追加時の手順（変更前後でのサブエージェントの挙動比較）を満たす
- `bash -n`でフックスクリプトの構文エラーがない。フックの各分岐を、入力JSONを与えて実行して確認する
