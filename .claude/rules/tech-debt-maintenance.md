---
paths:
  - ".claude/tech-debt/**/*.md"
---

# tech-debt運用方針

## 保存ルール

- `.claude/tech-debt/active/<slug>.md`：`Open`・`Accepted`のtech-debt
- `.claude/tech-debt/completed/<slug>.md`：`Resolved`のtech-debt
- ファイル名は内容が分かる英語kebab-case（`<slug>.md`）にする
- 削除しない。ファイル名も維持する

## 形式

```markdown
# <一行要約>
- **Status:** Open / Accepted / Resolved
- **Priority:** High / Medium / Low
- **Category:** Architecture / Code / Test / Performance / Security / Infrastructure / Dependency / Documentation
- **Area:** <対象ファイル・ディレクトリ>
- **Detected:** <YYYY-MM-DD>
- **Todoist Task ID:** <紐づくTodoistタスクのID>
- **Description:** <何が負債なのか>
- **Impact:** <なぜ問題なのか。放置すると何が起きるか>
- **Proposed Resolution:** <どう直すか>
- **Related:** <関連decision/plan/Issue/PR、無ければ「—」>
```

- `Category`・`Priority`・`Status`は必ず固定値から選ぶ。自由記述にしない
- `Description`だけで終わらせず`Impact`まで必ず書く
- `Resolved`にする場合、`Resolution`（実際にどう解決したか）と`Resolved`（解消日）を追記する
- `Accepted`にする場合、判断理由を`Resolution`相当の記述として追記する
- 内容は日本語で記述する
