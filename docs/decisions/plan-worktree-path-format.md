# planのWorktree行のパス形式

- **Status:** Deprecated
  - 理由: planの`Worktree:`行自体を廃止したため（claude-memはworktree内の作業も親リポジトリのprojectとして記録し、worktreeのパスで記録を絞り込めないことが判明した）
- **Verification Status:** Verified
- **Date:** 2026-10-15
- **Related Files:** `.claude/rules/plans-maintenance.md`, `.claude/hooks/plan-worktree-check.sh`, `.claude/skills/execution-plan/SKILL.md`

## Context

planファイルの`Worktree:`行には、作業したworktreeの絶対パス（例: `/home/ruby/tascon-backend/.claude/worktrees/agent-xxx`）を記録している。ホスト側とDev Container内ではパスが異なるため、環境を跨いで作業すると記録と実際のパスが食い違い、分かりづらくなるのではないかという懸念が挙がり、相対パス等への変更を検討した。

`Worktree:`行の用途は次の2つである。

- 完了処理でのclaude-mem照会の絞り込み（`execution-plan`スキル）
- SubagentStopフック`plan-worktree-check.sh`による記録漏れの検査（`cwd`との完全一致）

## Decision

絶対パスのまま変更しない。現状壊れておらず実害がないため、「壊れていないコードのリファクタ禁止」（`AGENTS.md`）に従う。

## Considered Options

- **採用: 絶対パス（現状維持）**: フックが`cwd`を変換せずそのまま比較できる。環境依存で行が長く、ホームのユーザー名がplanに残るが、いずれも動作上の問題ではない
- **リポジトリルートからの相対パス（`.claude/worktrees/agent-xxx`）**: 環境に依存せず読みやすい。フックで`cwd`からの変換が1段増える。変更の必要性がないため見送った
- **worktree名のみ（`agent-xxx`）**: 環境に依存しない最小の情報だが、相対パスより何を指すか分かりにくい
- **claude-memのproject識別子（`tascon-backend/agent-xxx`）**: 前半はリポジトリを置いたディレクトリ名で環境により変わり得る。また`CLAUDE_MEM_PROJECT_NAME_SOURCE=git-remote`設定やバージョンアップで識別子の形式が変わると記録が使えなくなる。planの記録がclaude-memの内部仕様に縛られるため不適

## Consequences

- claude-mem 13.39.0（`worker-service.cjs`）は、worktreeのproject識別子を`<親リポジトリのディレクトリ名>/<worktreeのディレクトリ名>`として作る（既定の`CLAUDE_MEM_PROJECT_NAME_SOURCE=path`の場合）。パスの前半は使わないため、絶対パスでもclaude-mem照会の絞り込みは環境に関係なく機能する
- コンテナで作ったサブエージェントのworktreeをホスト側で引き続き使うことは、実運用ではほぼ起きない。gitのworktreeは`.git`ファイルに元リポジトリの`.git`の場所を絶対パスで持つため、そもそもホスト側では正しく扱えない可能性が高い（未検証）
- 次のいずれかが起きたら再検討する
  - ホスト側でworktreeの作業を続けることが実際に起き、記録との食い違いで支障が出た
  - claude-memのproject識別子の作り方が変わり、パスの前半も使うようになった
