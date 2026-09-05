# フィードバック・決定のプロジェクト昇格タイミング

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-09-05

## Context

claude-mem導入を機に、ユーザーからの訂正・決定を`CLAUDE.md`/`rules`/`skills`/`.claude/memory/`へ反映するタイミングを検討した。当初はStop/PostToolUseフックによるリアルタイム自動反映を試みた。

## Decision

リアルタイム自動反映の方針を撤回し、`execution-plan`の完了処理（そのplanに関わる全ブランチがmainへマージ完了した時点、人間のPRレビューを経た後）にまとめて反映する。

- 完了処理内でclaude-memを照会し、そのplan期間中の決定・教訓に記録漏れがないか監査する。照会範囲は、plan内に記録したworktree絶対パス（サブエージェントの`isolation: "worktree"`起動時に払い出される、`.claude/worktrees/agent-<agentId>`形式のパス）から解決されるclaude-memの`project`識別子に絞る。これは時刻ではなくworktree単位でスコープを切ることで、人間のレビュー待ちで完了処理が遅延しても並行作業と混ざらないようにするため
- plan内の`Decision Log`セクションへの記録は従来通り即時（`execution-plan` SKILL.md既存ルール）。対象が「plan単体の作業記録」であり、プロジェクト全体への昇格とは別工程のため遅らせる理由がない
- claude-memの`CLAUDE_MEM_SKIP_TOOLS`はデフォルトで`AskUserQuestion`を観測対象から除外するため、`compose.devcontainer.yml`で`AskUserQuestion`を除いたリストへ上書きする

## Considered Options

- **`Stop`フックでの無条件`additionalContext`注入**: `hookSpecificOutput.additionalContext`を返すとそのターンを継続扱いにする仕様のため、無限ループを招いた
- **`type: "prompt"`による判定型フック**: 判定モデルがClaude自身の説明・自己解説を人間の訂正と誤認する自己言及誤判定が複数回発生した
- **`PostToolUse(Agent)`でのサブエージェント完了検知**: この環境の`Agent`ツールは非同期起動がデフォルトで、`PostToolUse(Agent)`は起動直後に発火することが判明。サブエージェント完了は`task-notification`として新しいターンに届き、それを処理したターンの末尾で通常の`Stop`が発火するため、意図した検知にならない
- **採用: `execution-plan`完了処理時の一括反映**: ドキュメントは人間とClaude間のコミュニケーションツールであり、その確定には人間のレビューを経るべきという判断

## Consequences

- リアルタイム性は失われるが、人間のPRレビューを経てから反映されるため確定内容の質が上がる
- `AskUserQuestion`経由の決定は即時反映（`PostToolUse(AskUserQuestion)`フック）が機能しなかった場合でも、claude-mem監査で拾えるようにする必要が生じた
