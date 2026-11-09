---
paths:
  - ".claude/plans/**/*.md"
---

# plans運用方針

## 構成

planファイルは`Context/Purpose`、`Decision Log`、`Validation and Acceptance`等のセクションを持つ。

- planファイルの先頭（見出しの直後）に`Spec:`行を置き、そのplanが基づく設計のパスをリポジトリの根から書く
- 設計が無いplanは`Spec: N/A`と書き、同じ行に続けて設計が無い理由を書く
- 1つの設計を、複数のplanが参照してよい

## 作成の手順

1. **調査**: 実装作業を依頼されたら、着手前に関連コード・既存実装を確認する
2. **ドラフト作成**: 調査結果を踏まえ、実装方針をドラフトとして作成する。構成はこのルールに従う
3. **ユーザーへ提示・承認**: ドラフトの実装方針をユーザーに提示し、同意を得る
4. **作成**: 同意を得た内容で`.claude/plans/active/<slug>.md`を作成する。見出しの直後に、「構成」のとおり`Spec:`行を書く
5. **連続実行**: 複数の段のplanは、`git-spice-workflow` skillに従って1段ずつブランチを切り、ブランチをスタックしながら連続実行する

## 保存ルール

- ファイル名は内容が分かる英語kebab-case（`<slug>.md`）にする
- 内容は日本語で記述する

## 各セクションの用途

- `Decision Log`: 決定事項とその理由を記録する。設計判断を含む提案にユーザーが同意したら、次の作業に移る前にその場で追記する
- `Context/Purpose`: 前提知識のない別セッションのClaude Codeが、これを読むだけで作業を再開できる状態を保つ
- `Validation and Acceptance`: そのplanの完了条件(受け入れ基準)を記録する。最後の段のPRを作る前の判定は`git-spice-workflow` skill、マージ後の判定は`plan-completion` skillに従う。mainへのマージ後でないと確かめられない項目には「マージ後に判定」と明記する

## PRとの対応

- planとPRの対応は、PR本文のRelated DocumentsのPlan行で持つ。印の書き方は`plan-completion` skillに従う
- 別のplanの作業は、できるだけそのplanのブランチで行う
- 別のplanの作業をした、または自分の作業が別のplanに影響してそのplanを更新したら、そのPRのRelated Documentsに、そのplanを指すPlan行を足す
