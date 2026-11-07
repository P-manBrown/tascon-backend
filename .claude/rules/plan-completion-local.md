---
paths:
  - ".claude/plans/**/*.md"
---

# 計画の完了の処理（このリポジトリの決まり）

`plan-completion` skillの完了の処理で「リポジトリの決まりに従う」部分は、次による。

- 完了の処理のブランチの置き場所: `docs/decisions/plan-completion-branch-placement.md`と、`git-spice-workflow` skillの完了処理のブランチの決まりに従う
- Decision Logの転記先:
  - 複数のタスクにまたがる横断的な決定 → `docs/decisions/`（`decisions-maintenance`ルール）
  - 技術的負債・既知の制約 → `tech-debt-tracker` skill
  - 振る舞いのルール・手順 → `claude-md-maintenance`ルールの置き場所判断
  - コードの構造の変化 → `ARCHITECTURE.md`（`architecture-md-maintenance`ルール）
- マージ後の確認でアプリのテストを走らせるときは、`AGENTS.md`と各skillに書かれたやり方に従う
