---
paths:
  - ".claude/CLAUDE.md"
  - ".claude/rules/**/*.md"
  - ".claude/skills/**/*.md"
  - ".claude/memory/**/*.md"
---

# CLAUDE.md運用方針

## 置き場所判断

- 常に必要な文脈（プロジェクト全体の前提・振る舞い方針）→ CLAUDE.md
- 特定ファイルパスを触るときだけ必要 → `.claude/rules/*.md`
- 特定タスク遂行時のみ必要な手順（コミット作成・リリース手順等、パスに紐付かない） → `.claude/skills/*/SKILL.md`
- 個人の作業スタイル・ツール利用方針など、プロジェクト全体・将来のセッションに影響しない内容 → `.claude/memory/`（git管理外のまま）
- プロジェクト全体のルールとして今後も参照されるべき内容 → memoryへ書く前に上記CLAUDE.md/rules/skillsへ直接昇格させる。後でまとめて棚卸しするのではなく、記録する時点で判断する

## 実践

- 強調語（`IMPORTANT`/`YOU MUST`等）は最後の手段。乱用すると全体的に効果が弱まる。本当に外せないルールにのみ使う
- CLAUDE.mdが200行超過時→`.claude/rules/`への切り出しを検討
- 新規ルール追加時→違反しそうなプロンプトで即セルフテスト。止まらなければノイズなので削除
- 変更は都度新規ブランチを切りコミット

## plans運用

`.claude/plans/`はactive/completed構成で運用し、git管理下に置く（索引ファイルは持たず、ディレクトリ構成自体を一覧として使う）。
