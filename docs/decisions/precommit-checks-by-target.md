# pre-commitのチェックをskillから分け、対象の変更時だけ実行する

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-11
- **Related Files:** `lefthook.yml`, `.lefthook/pre-commit/check-plan-completion.sh`, `.lefthook/pre-commit/check-links.sh`, `.lefthook/pre-commit/lib/index.sh`, `.claude/skills/plan-completion/scripts/lib/markdown.jq`, `.lefthook/pre-commit/tests/run.sh`, `.lefthook/pre-commit/check-docs.sh`

## Context

計画の完了の記録の検査（`check-completion.sh`）は`plan-completion` skillの`scripts/`にあったが、skill自身が実行するのは完了の判定と完了の処理のPRの検索だけで、この検査はlefthookのpre-commitからしか呼ばれない。検査にはMarkdownのリンクの検査も同居し、`check-docs.sh`にも別のリンクの検査があって、リンクの検査が2つに分かれていた。計画の検査は全コミットで動き、skillのテストはSKILL.mdの変更でも動いた。

## Decision

- pre-commitのチェックとそのテストは`.lefthook/pre-commit/`に置く。skillの`scripts/`には、skill自身が使う判定・PR検索のスクリプトとそのテストだけを残す
- チェックは対象ごとに分ける。計画の検査（`check-plan-completion.sh`）と、Markdownのリンクの検査（`check-links.sh`）は別のスクリプトにし、`check-docs.sh`からリンクの検査を除く。リンクの検査はコミットするMarkdown全体を対象に、ステージの内容（index）で行う
- 計画の検査は、コミットが`.claude/plans/**`か`.claude/specs/**`に触れるときだけ実行する（lefthookのglob）。計画を移すのは削除と追加なので、移した後に壊れるリンクはリンクの検査が止める
- テストは、テストする対象が変わるときだけ実行する。pre-commitのチェックのテストはチェックのスクリプト・`lib/`・テストの変更で、skillのテストはskillの`scripts/`の変更で実行する

## Considered Options

- **チェックをskillに置いたままglobだけ絞る**: skillが使わないスクリプトがskillに残り、skillの変更とpre-commitの変更の区別がつかない
- **リンクの検査を`check-docs.sh`に集める**: `check-docs.sh`は作業ツリーを読み、対象のディレクトリが固定で、削除したファイルを指すリンクを検出できない
- **採用: リンクの検査をindexを読む1つのスクリプトにし、`.lefthook/pre-commit/`に置く**

## Consequences

- pre-commitのチェックを足す・直すときは`.lefthook/pre-commit/`だけを見ればよい
- Markdownのリンクの検査は`check-links.sh`だけにあり、`check-docs.sh`は書式・必須項目の検査に絞られる
- pre-commitのチェックは、Markdownを読む`jq`の定義を`plan-completion` skillの`markdown.jq`と共有する。この`markdown.jq`が変わったときは、pre-commitのテストも実行する
