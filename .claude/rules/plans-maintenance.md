---
paths:
  - ".claude/plans/**/*.md"
---

# plans運用方針

## 構成

planファイルは`Context/Purpose`、`Progress`、`Decision Log`、`Validation and Acceptance`等のセクションを持つ。

## 保存ルール

- ファイル名は内容が分かる英語kebab-case（`<slug>.md`）にする
- 内容は日本語で記述する
- サブエージェントのworktreeでそのplanの作業を行う場合、そのworktreeの絶対パスを`Worktree: <path>`の形で冒頭（最初の`## `見出しより前）に記録する。planファイル自体を編集しない場合も記録する。作業するworktreeが変わった場合（再委任等）は、既存の行を残したまま`Worktree: <path>`を新しい行として追加する（1行に複数のパスを並べない）

## 各セクションの用途

- `Decision Log`: 決定事項とその理由を記録する。設計判断を含む提案にユーザーが同意したら、次の作業に移る前にその場で追記する
- `Context/Purpose`・`Progress`: 前提知識のない別セッションのClaude Codeが、これらを読むだけで作業を再開できる状態を保つ
- `Validation and Acceptance`: そのplanの完了条件(受け入れ基準)を記録する。完了処理時にすべて満たしたことを確認する
