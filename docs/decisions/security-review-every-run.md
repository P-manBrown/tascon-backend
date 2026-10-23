# security-reviewをdiffの種類によらず毎回実行する

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-09-10
- **Related Files:** `.claude/skills/todoist-task-runner/SKILL.md`

## Context

`todoist-task-runner` skillの処理フローでは、`/code-review`に加えて`/security-review`を、diffが入力値の扱い・認可・認証等のセキュリティに関わる場合だけ実行していた。この条件の判定をサブエージェントの主観に任せると、本来確認すべきdiffを見落とすおそれがある。

## Decision

`/security-review`は、diffの種類によらず毎回実行する。

## Considered Options

- **条件付き実行を維持**: トークン消費を抑えられるが、判定漏れのリスクが残る
- **採用: 毎回実行**: トークン消費は増えるが、判定漏れによる見落としの実害の方が大きいと判断した

## Consequences

- レビューごとのトークン消費が増える
- 毎回実行によるトークン消費が問題になった場合は、入力値・認可・認証に関わるdiffに限る条件付き実行へ戻すことを検討する
