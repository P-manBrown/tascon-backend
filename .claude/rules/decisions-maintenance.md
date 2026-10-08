---
paths:
  - "docs/decisions/**/*.md"
---

# decisions運用方針

## 対象

複数タスクを跨ぐ永続的な設計判断（なぜこの技術・パターンを採用したか等）を記録する。1決定1ファイルとする。

## ファイル名

内容が分かる英語kebab-case（`<slug.md>`）とする。

## 形式

```markdown
# <決定タイトル>

- **Status:** Proposed / Accepted / Deprecated / Superseded by [XXX](XXX.md)
- **Verification Status:** Verified / Unverified / Stale
- **Date:** YYYY-MM-DD
- **Related Files:** <この決定に対応する実装ファイルのパス。複数可>

## Context

## Decision

## Considered Options

## Consequences
```

- `Status`: この決定自体が今も有効な意思決定かを示す
- `Verification Status`: この決定が実装で実際に検証済みかを示す
- `Related Files`: `Verification Status`の検証時に照合する実装ファイル
- `Considered Options`: 複数案を検討した場合のみ、それぞれの長所・短所を書く
- 内容は日本語で記述する
