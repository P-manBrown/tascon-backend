# コミットメッセージの機械チェックはPRタイトルのみ

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2024-07-31
- **Related Files:** `.github/workflows/semantic-pull-request.yml`, `lefthook.yml`

## Context

ローカルの個々のコミットメッセージに、Conventional Commits形式の機械チェック（git-lintによるcommit-msgフック）をかけていた。フロントエンドとバックエンドでツール・設定を揃えられなかった。また、mainへはスカッシュマージするため、ローカルのコミットメッセージはmainの履歴に残らず、残るのはPRタイトルだけになる。

## Decision

ローカルのコミットメッセージに対する機械チェックは廃止し、CIでのPRタイトルのチェック（`semantic-pull-request.yml`）だけにする。ローカルのコミットメッセージは、レビュアーや将来の自分に技術的に何をしたかを伝えるためのもので、形式の厳密さより中身の分かりやすさを優先する。

## Considered Options

- **commit-msgフックでのチェックを維持**: ローカルで形式違反を早く検知できるが、フロントエンドと揃えられず、mainに残らないメッセージを縛ることになる
- **採用: PRタイトルのチェックのみ**: mainの履歴に残るものだけを検査する

## Consequences

- ローカルのコミットメッセージの形式は機械的に強制されない。規約は`git-spice-workflow` skillの手順で守る
- コミットメッセージの形式チェックを新たに導入する提案は、この決定を見直す場合に限る
