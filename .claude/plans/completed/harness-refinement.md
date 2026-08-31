# harness engineering基盤の精査・是正

## Context

`dapper-hugging-phoenix.md`（AIエージェント駆動開発の運用基盤構築）完了後、matklad "ARCHITECTURE.md"記事（https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html）とCodex公式ドキュメント（developers.openai.com/codex/guides/agents-md）を踏まえて内容を精査したところ、複数の設計上の不備が見つかったため是正した。

## Progress

全ステップ完了済み。

## Decision Log

- **ARCHITECTURE.mdを`docs/architecture/overview.md`からリポジトリルートへ移動**
  - Rationale: matklad記事（"next to README and CONTRIBUTING"）とOpenAI Harness Engineering記事の実例の両方が、ルート配置を採用している

- **ARCHITECTURE.mdの中身を265行→98行に書き直し**
  - Rationale: matklad原則（短く保つ、codemapは国の地図であり州の地図の地図帳ではない、決定理由は書かない、直接リンクは張らない）に沿わせた。Controller/Model個別のアクション詳細等、実装詳細に踏み込みすぎていた

- **AGENTS.mdを新設し、CLAUDE.mdは`@AGENTS.md`インポート構成へ変更**
  - Rationale: Codex CLIは実行のたびにリポジトリルートの`AGENTS.md`を自動読込するが`CLAUDE.md`は読まない仕様と判明。コーディング方針4原則がCodexへの実装委譲に一切反映されていなかった

- **`docs/design-docs/index.md`新設**
  - Rationale: 複数タスクを跨ぐ永続的な設計判断の置き場所がなく、当初ARCHITECTURE.mdの末尾に置く案は「情報の質が異なる」（What/現状の地図 と Why/決定理由は別物）と判明し不適切だった

- **`.claude/rules/codex-delegation.md` → `.claude/skills/codex-delegation/`へ移動**
  - Rationale: `paths: app/**`というトリガーは、Claudeがapp/を直接編集しない運用（実装はCodexへ委譲）のため発火機会が構造的にほぼない。内容も「方針」ではなく「委譲時の具体的手順」だったためSKILL.mdが適切

- **`.claude/rules/debride-safe-commits.md`を分割・削除**
  - Rationale: debrideの動作原理から導かれる確定原則（新設メソッドは使用コードと同一コミットに含める）と、`lefthook-debride-scope-change.md`（未着手plan）でまだ検証中の観察（ファイルスコープと誤検知の因果関係）が混在していた。未着手planの調査結果を確定規約として先取りすべきでないため、確定部分のみ`git-spice-workflow` skillへ統合し、検証中の部分はplanへ一本化した

- **`.claude/CLAUDE.md`の「ナビゲーション」節（Skillへの誘導）を削除**
  - Rationale: Skill自体の`description`フィールドが既に「いつ使うべきか」を担っており、CLAUDE.mdでの重複記述はSkill更新時に陳腐化するリスクを生む。ファイルでないもの（`ARCHITECTURE.md`等）への言及はAGENTS.md側にのみ残した

- **Codexの成果物確認をコミット前の必須手順として明記**（`codex-delegation` skill）
  - Rationale: `.claude/rules/*.md`の`paths:`自動ロードは、Claudeがそのパスのファイルを`Read`した瞬間に発火する。Codexは`.claude/rules/`を一切読まないため、Claude自身が成果物確認のタイミングでこの自動発火を利用するのが、規約違反を検知する最も確実な経路と判断した

## Validation and Acceptance

- 各変更はlefthook pre-commit（rubocop/debride）を通過している
- ARCHITECTURE.mdの`paths:`ルール自動ロードは実機で検証済み（`Read`直後にsystem-reminderとして`architecture-md-maintenance.md`の全文がロードされることを確認）
- 対象コミット: `be02cae`（AGENTS.md新設）, `5325cc1`（ARCHITECTURE.mdルール）, `c7d28c9`（design-docs index）, `04736e0`（自律運用ギャップ是正）, `ed6ebd1`（codex-delegation skill化）, `1b38f1a`（debride-safe-commits分割）、および`docs/architecture-overview`ブランチのamend（ARCHITECTURE.mdルート移動・書き直し）
