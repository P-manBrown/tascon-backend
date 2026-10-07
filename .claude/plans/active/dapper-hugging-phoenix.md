# AIエージェント駆動開発の運用基盤構築

## Context

OpenAI「Harness Engineering」記事の運用思想（repositoryをsystem of recordとして扱う、AGENTS.mdは百科事典でなく目次、progressive disclosure、agent legibility）を参考に、このリポジトリをClaude Code前提のAIエージェント駆動開発向けに整備する。

現状の課題: 「なぜその設計にしたか」「現在のコード構造がどうなっているか」を後から追跡する手段がなく、実装判断の根拠が失われやすい。`.claude/plans/`は実装前設計書止まりで、実装中の生きた更新（進捗・発見・決定）を前提にしていない。`docs/`ディレクトリ自体が存在しない。

対話の中でOpenAI記事本体（二次情報経由、直接WebFetchは403で不可）の実際のdocs構造（`docs/exec-plans/active/`, `completed/`, `tech-debt-tracker.md`等）を確認し、当初「記事に無い独自要素」と誤認していたactive/completed分離が実際には記事由来と判明した一方、ADR・core-beliefs.md・product specs独立ディレクトリは記事の一部機能と重複するか、このリポジトリの規模（個人開発1人）には過剰と判断し不採用とした。「OpenAI提示以上のものは実装しない」という方針のもとで、以下の最小構成に絞り込んでいる。

## 決定事項サマリ

- **新設するもの**: `docs/architecture/overview.md`（現状構造＋横断的設計判断の蓄積）、`.claude/plans/active/`・`.claude/plans/completed/`（分離、git管理化）、`.claude/skills/execution-plan/`、`.claude/skills/doc-gardening/`
- **新設しないもの**:
  - ADR（`docs/decisions/`）— completed plansのDecision Logで代替
  - `core-beliefs.md`— 既存`CLAUDE.md`の4原則（実装前に考える／シンプル最優先／外科的変更／ゴール駆動実行）が同じ役割を既に果たしている
  - product specs独立ディレクトリ — 各planのPurpose/Context節で代替
  - `.claude/plans/INDEX.md`— active/completed分離自体が一覧性を提供するため廃止（二重管理・陳腐化リスク回避）
- **git管理変更**: `.git/info/exclude`から`/.claude/plans`を削除し共有対象にする。`/.claude/memory`は個人の協業スタイルメモとして引き続きローカル限定
- **memory棚卸し**: `.claude/memory/`13ファイルのうち、プロジェクト全体のルールとして本来共有すべき内容（例: debride対策、ブランチ粒度、コミットbody必須、Bruno CLI必須）を`.claude/rules/`または`CLAUDE.md`へ個別に昇格。個人の作業スタイル的なメモはローカル限定のまま

既存メモリ方針（計画は1ステップずつ実行、ブランチ粒度は1機能=1〜2コミット）に従い、以下Stepごとに区切ってブランチを分け、都度承認を得てから次へ進む。

---

## Step 1: architecture docs新設

新規: `docs/architecture/overview.md`

- 内容: `app/controllers/api/`, `app/resources/`, `app/models/`, `app/validators/`等の役割を要約したレイヤー構成の説明
- 末尾に「設計判断」セクションを設ける（横断的・複数タスクをまたぐ決定を箇条書きで追記していく場所。今は空または1〜2件で開始）
- authoritative sourceはコード自体。このファイルは要約・ナビゲーション

検証: 既存`app/`配下の実際の構成と記述内容に齟齬がないか目視レビュー

## Step 2: plans運用変更（active/completed分離・git管理化・INDEX.md廃止）

- `.git/info/exclude`から`/.claude/plans`の行を削除
- `.claude/plans/active/`・`.claude/plans/completed/`を作成
- 既存3ファイルを完了状況に応じて`git mv`で仕分け（履歴保持）
  - `task-group-share-cancellation.md`: 現ブランチ`feat/task-group-share-destroy`の作業と対応している可能性が高く、実装状況を見てactive/completedを判断
  - `reflective-puzzling-wren.md`: Step4以降未実装と明記済み → `active/`
  - `lefthook-debride-scope-change.md`: 未着手と明記済み → `active/`
- `.claude/plans/INDEX.md`を削除
- `.claude/rules/claude-md-maintenance.md`または`CLAUDE.md`に「plansはactive/completed構成、git管理下」である旨を一言だけ追記（詳細手順はexecution-plan skillに書くのでここは触れる程度）

検証: `git status`で`.claude/plans/`が追跡対象になっていることを確認。3ファイルが適切に仕分けられているか内容と突き合わせ確認

## Step 3: `execution-plan` skill新設

新規: `.claude/skills/execution-plan/SKILL.md`（既存skillと同じfrontmatter形式: `name`, `description`）

- 目的: 複数ファイル・複数コミット・1時間超見込みの複雑タスクについて、計画をExecPlan方式（Context/Progress/Decision Log/Validation and Acceptance等）で作成・生きた文書として更新・完了処理する
- 使用場面: 複雑な機能追加/リファクタ着手時、`plans/active/`配下ファイルの更新時
- 変更可: `plans/active/*.md`の作成・更新、完了時`git mv`で`completed/`へ移動
- 変更禁止: 実装コード自体（既存方針通りCodexへ委譲）
- 完了条件: Validation and Acceptance達成 → `completed/`へ移動
- 他skillとの境界: `git-spice-workflow`はコミット/ブランチ/PR操作、`execution-plan`はその前段の計画文書管理

検証: このタスク自体の続きのステップ（Step4以降）をこのskill運用に沿って試験的に回してみる

## Step 4: `doc-gardening` skill新設

新規: `.claude/skills/doc-gardening/SKILL.md`

- 目的: `docs/architecture/`・`plans/`の陳腐化・矛盾・記述漏れを検知し修正提案する
- 使用場面: 定期的（`/loop`）または大きめのPR前後に手動起動
- 調査: `docs/architecture/overview.md`の記述と実コード構造の乖離
- 変更可: docs記述修正提案（適用はユーザー承認後）
- 変更禁止: コード自体
- 完了条件: 不整合の一覧化と修正案提示

検証: 現状の`docs/architecture/overview.md`に対して試験的に1回実行し、誤検知がないか確認

## Step 5: CLAUDE.mdへのナビゲーション追加

`.claude/CLAUDE.md`（既存50行・4原則）に、以下2点への導線を数行追加するのみ。既存原則・分量は変更しない。

- architecture理解が必要なら`docs/architecture/overview.md`
- 複雑タスクに着手するなら`execution-plan` skill

検証: 追加後も200行未満に収まっていること、既存4原則の記述を変更していないこと

## Step 6: memory棚卸し

`.claude/memory/`13ファイルを個別に確認し、以下の判定を適用：

- プロジェクト全体のルール（例: `feedback_debride_unused_check.md`, `project_branch_granularity.md`, `feedback_commit_body_default.md`, `feedback_bruno_endpoint_verification.md`）→ 該当内容を`.claude/rules/`または`CLAUDE.md`へ移し、移行元のmemoryファイルは重複を避けるため削除または要約に留める
- 個人の作業スタイル・ツール利用方針（例: rtk関連）→ ローカル限定のままmemoryに残す

検証: 昇格後、`MEMORY.md`索引と実ファイルの整合性を確認。重複記述が残っていないこと

---

## スコープ外（今回やらないこと）

- ADR / `docs/decisions/`の新設
- `core-beliefs.md`の新設
- product specs独立ディレクトリ
- lefthookへの機械的docsチェック追加（優先度低、将来検討）
- CI（GitHub Actions）への検証追加（現状テスト実行CIが無く不釣り合いなため見送り）
