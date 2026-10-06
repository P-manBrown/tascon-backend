---
name: execution-plan
description: 実装計画をExecPlan方式で作成・更新・完了処理するスキル。「実装計画を作って」「ExecPlanを作成・更新して」「タスクの計画を立てて」「別セッションで再開できる計画を残して」等の指示があった場合に加え、実装タスクに着手する際、planに関わる全ブランチがmainにマージされた時に使用する。
---

# execution-plan

実装作業の計画を、別セッションでも再開できる生きたExecPlanとして管理する。

## 計画作成

1. **調査**: 実装作業を依頼されたら、着手前に関連コード・既存実装を確認する
2. **計画ドラフト作成**: 調査結果を踏まえ、実装方針をドラフトとして作成する。構成は`plans-maintenance`ルールに従う
3. **ユーザーへ提示・承認**: ドラフトの実装方針をユーザーに提示し、同意を得る
4. **計画作成**: 同意を得た内容で`.claude/plans/active/*.md`にファイルを作成する
5. **連続実行**: 複数ステップのplanは1ステップずつブランチを切り、ブランチをスタックしながら連続実行する

## 完了処理

完了処理は、そのplanに関わる全ブランチ(git-spiceスタック全体)がmainへマージ完了した時点で行う。

1. 完了条件をすべて満たしたことを確認する
2. claude-memを照会し、このplanの期間中に生じた決定・ドキュメント化すべき内容・記録すべき教訓を洗い出す。planファイルに記録されている`Worktree:`のパスから解決されるproject識別子に絞る
3. 洗い出した内容を、該当するドキュメントへ転記する
  - 複数タスクを跨ぐ横断的な設計判断 → `docs/decisions/`へ個別ファイル化する。そのplan固有の経緯はplanファイルの`Decision Log`に追記する。
  - 今すぐ対応しないが将来問題化しうる設計上の妥協・既知の制約 → `tech-debt-tracker` skillの手順で記録する
  - 恒久的な振る舞いルール・手順の変更 → `claude-md-maintenance`ルールの置き場所判断に従い、該当する`.claude/skills/*/SKILL.md`または`.claude/rules/*.md`へ反映する
  - プロジェクト全体・将来のセッションに影響する個人の作業スタイル・経緯等 → memoryとして記録する
4. コードの変更が`ARCHITECTURE.md`に影響を与える場合、`ARCHITECTURE.md`を更新する
5. 完了したplanがtech-debtに関連するものであれば`tech-debt-tracker` skillに従い、tech-debtも更新する
6. 完了したplanは`.claude/plans/active/`から`.claude/plans/completed/`へ移動する
7. 完了後も削除せず、実装判断の根拠として保持し続ける

## 変更範囲

- 変更してよい対象: `.claude/plans/active/*.md`の作成・更新、完了時の`.claude/plans/completed/`への移動
- 変更してはいけない対象: 実装コード。このリポジトリでは実装をCodexへ委譲するため、このskill自体はコード実装を行わない
