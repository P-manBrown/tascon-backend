---
paths:
  - ".claude/plans/**/*.md"
---

# plans運用方針

## 構成

planファイルは`Context/Purpose`、`Branches`、`Progress`、`検証結果`、`Decision Log`、`Validation and Acceptance`等のセクションを持つ。

## 保存ルール

- ファイル名は内容が分かる英語kebab-case（`<slug>.md`）にする
- 内容は日本語で記述する

## 各セクションの用途

- `Decision Log`: 決定事項とその理由を記録する。設計判断を含む提案にユーザーが同意したら、次の作業に移る前にその場で追記する
- `Branches`: そのplanで作業したブランチを、1行に1つ`type/name`の形ですべて書く。ブランチを作ったら足し、改名したら書き換え、PRにせず捨てたら外す
- `検証結果`: 変更前後の比較テスト等、決定を確かめた結果を記録する。Decision Logには書かない
- `Context/Purpose`・`Progress`: 前提知識のない別セッションのClaude Codeが、これらを読むだけで作業を再開できる状態を保つ
- `Validation and Acceptance`: そのplanの完了条件(受け入れ基準)を記録する。完了処理時にすべて満たしたことを確認する
