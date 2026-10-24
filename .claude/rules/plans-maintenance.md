---
paths:
  - ".claude/plans/**/*.md"
---

# plans運用方針

## 構成

planファイルは`Context/Purpose`、`Progress`、`検証結果`、`Decision Log`、`Validation and Acceptance`等のセクションを持つ。

## 保存ルール

- ファイル名は内容が分かる英語kebab-case（`<slug>.md`）にする
- 内容は日本語で記述する

## 各セクションの用途

- `Decision Log`: 決定事項とその理由を記録する。設計判断を含む提案にユーザーが同意したら、次の作業に移る前にその場で追記する
- `検証結果`: 変更前後の比較テスト等、決定を確かめた結果を記録する。Decision Logには書かない
- `Context/Purpose`・`Progress`: 前提知識のない別セッションのClaude Codeが、これらを読むだけで作業を再開できる状態を保つ
- `Progress`のチェックボックスは1つのStepに1つとし、`- [ ] StepN: `の形で書く。Stepの変化はチェックボックスを増やさず、その下に箇条書きで時系列に書き足す。Stepでない注記はチェックボックスにしない
- `Validation and Acceptance`: そのplanの完了条件(受け入れ基準)を記録する。判定の時期・手順は`execution-plan` skillに従う。mainへのマージ後でないと確かめられない項目には「マージ後に判定」と明記する

## ブランチとの対応

- 別のplanの作業は、できるだけそのplanのブランチで行う
- 別のplanの作業をした、または自分の作業が別のplanに影響してそのplanを更新したら、今のブランチの`branch.<name>.plan`にそのplanの値を足す（値の形は`git-spice-workflow` skillに従う）
