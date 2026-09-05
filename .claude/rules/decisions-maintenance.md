---
paths:
  - "docs/decisions/**/*.md"
---

# decisions運用方針

対象・書くこと・書かないことは`docs/decisions/index.md`を参照する。1決定1ファイルとする。

## 形式

```markdown
# <決定タイトル>

- **Status:** Proposed / Accepted / Deprecated / Superseded by [XXX](XXX.md)
- **Verification Status:** Verified / Unverified / Stale
- **Date:** YYYY-MM-DD

## Context

## Decision

## Considered Options

## Consequences
```

- `Status`: この決定自体が今も有効な意思決定かを示す
- `Verification Status`: この決定が実装で実際に検証済みかを示す
- `Considered Options`: 複数案を検討した場合のみ、それぞれの長所・短所を書く
