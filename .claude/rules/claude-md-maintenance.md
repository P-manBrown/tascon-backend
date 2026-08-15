---
paths:
  - ".claude/CLAUDE.md"
  - ".claude/rules/**/*.md"
  - ".claude/skills/**/*.md"
---

# CLAUDE.md運用方針

## 置き場所判断

- 常に必要な文脈（プロジェクト全体の前提・振る舞い方針）→ CLAUDE.md
- 特定ファイルパスを触るときだけ必要 → `.claude/rules/*.md`
- 特定タスク遂行時のみ必要な手順（コミット作成・リリース手順等、パスに紐付かない） → `.claude/skills/*/SKILL.md`

## 実践

- 強調語（`IMPORTANT`/`YOU MUST`等）は最後の手段。乱用すると全体的に効果が弱まる。本当に外せないルールにのみ使う
- CLAUDE.mdが200行超過時→`.claude/rules/`への切り出しを検討
- 新規ルール追加時→違反しそうなプロンプトで即セルフテスト。止まらなければノイズなので削除
- 変更は都度新規ブランチを切りコミット
