# 作業中の記録漏れの確認とplan完了時の反映

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-10-19
- **Related Files:** `.claude/hooks/record-check.sh`, `.claude/settings.json`, `.claude/skills/execution-plan/SKILL.md`, `.devcontainer/compose.devcontainer.yml`

## Context

作業中に生じた決定・指摘・教訓・技術的負債等が、定められた記録先に書かれないまま漏れることがある。従来は、execution-planの完了処理でclaude-memを照会して漏れを監査し、照会範囲はplanの`Worktree:`行から解決されるclaude-memのproject識別子に絞る前提だった（[フィードバック・決定のプロジェクト昇格タイミング](feedback-reflection-timing.md)）。

2026-10-19に、この前提が成り立たないことが判明した。claude-mem 14.0.1はフック入力の`cwd`より`CLAUDE_PROJECT_DIR`を優先するため、worktree内の作業も親リポジトリのprojectとして記録される。また、claude-memの通常のインターフェース（MCPの`search`・`timeline`・`get_observations`等）は、セッション・ターン・agentで絞り込めない。正確に絞り込めるのは内部HTTP APIかDBの直接読み込みだけで、どちらも通常の使い方ではない。

## Decision

記録の主軸を、作業中のその場での確認に移す。plan完了時の反映は従来どおり行う。

- メインセッションのターンの終わり（Stop）と、サブエージェントが報告を渡す直前（SubagentHandbackへのPreToolUse）に、`record-check.sh`が1回だけ止めて、各skill・ruleがその場での記録を定めているもの（planの`Decision Log`・`検証結果`・`Progress`、技術的負債、Todoistへの進捗コメント、memory）をすべて記録したかを確認させる。
- SubagentHandbackはauto modeでだけ使われるため、auto mode以外のサブエージェントはSubagentStopで1回止めて確認させる（2026-10-23）。入力の`permission_mode`が`auto`のときと、`agent_type`が空（起動していない内部のエージェント）のときは何もしない。止めたときは、記録の後に直前の報告を全文もう一度出力させ、呼び出し元への報告が確認の返答に置き換わらないようにする
- SubagentHandbackの1回目を覚えておく状態ファイルは、メインcheckoutの`.claude/hook-state/record-check/`（gitignore）に置き、`record-check.sh`が実行のたびに24時間より古いものを消す（2026-10-22）。PreToolUseの入力には前回拒否したかを示す欄がなく、2回目の報告が来ないとファイルが残り続けるため
- `docs/decisions/`・rules/skill・`ARCHITECTURE.md`への反映は、従来どおりplanの完了処理（全ブランチのマージ後、人間のPRレビューを経た後）にまとめて行う。完了処理では、claude-memを通常の検索ツールで検索し、まだ記録されていない決定・教訓等を洗い出す
- claude-memの`CLAUDE_MEM_SKIP_TOOLS`は、`AskUserQuestion`を除いたリストに上書きし、`AskUserQuestion`経由の決定も記録対象にする（`compose.devcontainer.yml`）

## Considered Options

- **Stopフックでの`additionalContext`注入**: ターンが継続扱いになり、無限ループを招いた
- **`type: "prompt"`による判定型フック**: 判定モデルが、Claude自身の説明を人間の訂正と誤認した
- **`PostToolUse(Agent)`でのサブエージェント完了検知**: Agentツールが非同期のため、起動直後に発火した
- **SubagentStopでの確認のみ**: SubagentHandbackで報告を渡したあとのサブエージェントは、止めても作業を続けなかった
- **SubagentStopでの予備の確認**: SubagentHandbackを使わずに終わるサブエージェントのために残していたが、実際のサブエージェントはすべてSubagentHandbackで報告しており、状態ファイルの片付けにしか使われていなかったため外した（2026-10-20）。その後、SubagentHandbackはauto modeでだけ使われ、auto mode以外のサブエージェントは確認を受けていなかったと分かり、auto mode以外に限ってSubagentStopで確認する形で戻した（2026-10-23）。SubagentStopへの一本化は、auto modeではSubagentHandbackで報告を渡した後に動き、止めても作業を続けないため採らない
- **planごとの作業記録ログ（agent_id・セッションID＋時刻）でclaude-memを照会**: 通常のインターフェースではこのキーで絞り込めず、内部HTTP APIへの依存が必要になるため採らない
- **採用: 作業中の確認（`decision: block`とPreToolUseの拒否）＋完了時の通常検索**: 判定は会話全体を持つ本体に任せ、2回目は止めないことでループを防ぐ

## Consequences

- 毎ターン（サブエージェントは報告前）に1回、確認の分だけ処理とトークンが増える
- 記録するかどうかの判断はAIに任されるため、判断を誤った場合は漏れうる。完了時のclaude-mem検索は、その補助にとどまる
- この方式で漏れが減らない場合は、エージェント型フック（実験的機能）を検討する
