# plan-worktree-checkフックの判定基準を「いずれかのactive planに記録があるか」へ変更する

Worktree: /home/ruby/tascon-backend/.claude/worktrees/agent-a4a0c7af5c561dfb8

## Context/Purpose

- 対応するtech-debt: `.claude/tech-debt/active/plan-worktree-check-scans-all-active-plans.md`（Todoist親タスク`6hhr8RJR4gjP8V3q`、「作業する」子タスク`6hhr8RghXPvMFPmq`）
- `.claude/hooks/plan-worktree-check.sh`（`.claude/settings.json`のSubagentStopフック）は、cwdが`*/.claude/worktrees/*`のとき、`.claude/plans/active/*.md`の全ファイルに`Worktree: <cwd>`行があるかを確認し、1件でも欠けていればexit 2で停止をブロックする。そのため、無関係な既存planが毎回指摘される
- `Worktree:`を記録する目的は、execution-plan完了処理の手順2（`Worktree:`のパスから解決されるproject識別子でclaude-memを照会する）にある。記録が必要かどうかは「そのworktreeでplanの作業をしたか」で決まり、planファイルを編集したかどうかは関係ない
- 目的: フックの判定を「いずれか1件のactive planに、行全体が`Worktree: <cwd>`と一致する行があるか」へ変更し、`plans-maintenance`ルールの記録条件も同じ考え方に揃える
- ブランチ: `chore/plan-worktree-check-scope`（`docs/controller-before-action-rule`の上にgit-spiceで作成済み）

### 作業環境の注意（実行して確認済み）

- worktree内のBashツールでも素の`git`を使える（rtk feature 1.0.2以降。2026-10-14にdevcontainerをリビルドして確認）。ただし`git -C .`のように`-C`に相対パスを渡すと、worktree分離ガードに拒否される
- コマンド文字列に`git`を含むパイプ・サブシェル等の複合コマンドは「複雑すぎて検証できない」としてガードに拒否される。複合的な検証はスクリプトファイルに書いて`bash <file>`で実行する
- フックや`bash <file>`で実行するスクリプト内の`git`はrtkに書き換えられない（スクリプト内で`type git`が`/usr/bin/git`を返すことを確認）

## 仕様

- `stop_hook_active`が`true`なら何も出力せずexit 0（現状維持）
- cwdが空、またはcwdが`*/.claude/worktrees/*`でなければexit 0（現状維持）
- `$cwd/.claude/plans/active`が存在しなければexit 0（現状維持）
- `.claude/plans/active/`に`*.md`が1件もなければexit 0
- 各planの冒頭（最初の`## `見出しより前の行）だけを見て、行末の空白・CRを除いた行全体が`Worktree: <cwd>`と完全一致する行が1つでもあればexit 0。1つもなければexit 2
  - 前方一致は不可（`Worktree: .../agent-x`が`agent-xy`のworktreeにマッチしない）
  - cwdは正規表現ではなく文字列として比較する
- exit 2時のメッセージは「作業中のplanの冒頭に`Worktree: <cwd>`を1行で追記してください」という趣旨にする（`plans-maintenance`ルール参照の旨は残す）。あわせて「planの作業をしていない場合（レビュー・調査等）は対応不要。無関係なplanには追記しない」旨を明記する

## Steps

### Step 1: フック・ルール修正とtech-debt解消（`chore/plan-worktree-check-scope`）

1. `.claude/hooks/plan-worktree-check.sh`を上記仕様に修正する（Codexへ委譲）
2. `.claude/rules/plans-maintenance.md`の記録条件を「サブエージェントのworktreeでそのplanの作業を行う場合、そのworktreeの絶対パス（`Worktree:`）を冒頭に記録する。作業するworktreeが変わった場合（再委任等）は追記する」の趣旨に修正し、言及箇所（`.claude/skills/todoist-task-runner/SKILL.md:24`等）も合わせて更新する（Codexへ委譲）。`claude-md-maintenance`ルールの「新規ルール追加時の必須手順」に従い、新規subagentで変更前後の行動を比較する
3. tech-debt-tracker skillに従い、tech-debtを`Resolved`にして`.claude/tech-debt/completed/`へ移動する。Proposed Resolution（変更planに絞る）と実際の解決方法が異なる点を`Resolution`に明記する

4. レビュー指摘への対応（同ブランチに追加コミット）: フックの判定（`*.md`がない場合、冒頭部分に限定、行末の空白・CRの除去、メッセージ）を上記仕様へ修正する。`plans-maintenance`ルールに「worktreeごとに`Worktree: <path>`を1行ずつ書く」旨を明記し、`todoist-task-runner/SKILL.md`の言及箇所も揃える（いずれもCodexへ委譲）

検証（JSON入力をパイプして実行。確定したケース一覧）:

1. どのactive planにもWorktree行がない（無関係なplanのみ） → exit 2
2. いずれか1件のactive planに完全一致のWorktree行がある → exit 0
3. 前方一致だけの行（`Worktree: <cwd>x`）しかない → exit 2
4. `agent-x`の行しかないplanを`agent-xy`のworktreeで検査 → exit 2
5. cwdがworktree外 → exit 0
6. `stop_hook_active: true` → 出力なしでexit 0
7. plans_dirが存在しない → exit 0
8. `active/`は存在するが空 → exit 0
9. 行末に空白が付いた完全一致行 → exit 0
10. CRLFの完全一致行 → exit 0
11. 一致する行が`## `見出しより後にしかない → exit 2
12. パスに`.`を含むcwd（`a.12`）と、`.`の位置だけが違う行（`a_12`） → exit 2（正規表現として扱わない）
13. このworktree自体 → exit 0

## Progress

- [x] 2026-10-14 ブランチ`chore/plan-worktree-check-scope`を`docs/controller-before-action-rule`の上に作成。事前調査を実施しplanドラフトを作成
- [x] 2026-10-14 ユーザーとの議論で方針を変更したうえでplanが承認された（Decision Log参照）
- [x] 2026-10-14 Step 1完了（すべてCodexへ委譲し、成果物を確認してコミット）
  - フック修正`54e6a42`: 当時の検証ケース（上記一覧の1〜7と13）の8件すべて想定どおり
  - ルール修正`685f339`（`plans-maintenance.md`、`todoist-task-runner/SKILL.md:24`）: 新規subagentに「既存planをこのworktreeで再開し、残作業を確認して報告する（planは編集不要）」というプロンプトを与えて比較した。変更前はWorktree行を追記せず、変更後は追記した（テストでの追記は取り消し済み）
  - tech-debt解消`428183d`: `Resolved`にして`completed/`へ移動し、Proposed Resolutionと異なる方法で解決したことを`Resolution`に記載
  - 注意: SubagentStopフックはメインcheckoutの旧スクリプト（`${CLAUDE_PROJECT_DIR}`）で動くため、このブランチがマージされるまでは無関係なplanの指摘が出続ける
- [x] 2026-10-14 親セッションの`/code-review`指摘に対応（`/security-review`は指摘なし）。Step 1の4を実施
  - フック修正`1fe75cd`: 検証ケース1〜13の全件が想定どおり
  - ルール修正: 新規subagentに「既存planをこのworktreeで再開する。planファイルの`Worktree:`欄にこのworktreeのパスを追記する」というプロンプトを与えて比較した。変更前は既存の行にカンマ区切りで並べ、変更後は新しい行として追加した（テストでの変更は取り消し済み）。「planの作業開始時にルールどおり記録する」というプロンプトでは、変更前から別の行で追加しており差が出なかったため、比較には前者を使った

## Decision Log

- 2026-10-14 判定基準は「いずれか1件のactive planに`Worktree: <cwd>`の行があるか」にする（ユーザー判断）。`Worktree:`の記録目的は完了処理でのclaude-mem照会であり、記録要否はそのworktreeでplanの作業をしたかで決まる。1つのworktreeで扱うplanは基本的に1つで、どのplanが正しいかという意味的な検証は形式的な検査ではできないため、検査は「どれか1件に記載があるか」までに留める
- 2026-10-14 一致判定は行全体の完全一致にする。前方一致だと`agent-x`が`agent-xy`のworktreeに誤ってマッチする
- 2026-10-14 当初案（git-spiceで親ブランチを取得し、git差分で変更されたplanだけを検査する）は一度採用したが取り消した。planファイルを編集したかどうかは、記録の要否と関係ないため
- 2026-10-14 agent hook（`type: "agent"`）は採用しない。公式ドキュメント上experimentalで、サブエージェントの停止のたびにコストがかかり、結果も非決定的なため
- 2026-10-14 `completed/`は検査しない。完了処理を行うworktreeは記録不要である。完了処理ではclaude-memを照会した後にplanを移動するので、そのworktreeの記録は照会で使われない
- 2026-10-14 既知の制約として記録のみ: 将来、完了処理をサブエージェントのworktreeで行うと、planがcompletedへ移動した時点で該当するactive planがなくなり、フックが1回ブロックする（`stop_hook_active`により2回目は通る）。現状、完了処理をサブエージェントへ委ねる手順はないため対処しない
- 2026-10-14 ブランチtypeは`chore`にする（既存のフック変更#683等と同じ）
- 2026-10-14 `plans-maintenance`ルールの記録条件を「作成・更新する場合」から「そのplanの作業を行う場合」へ変更する。フックの判定基準と考え方を揃えるため
- 2026-10-14 以下はcode-review指摘への対応（ユーザー承認済み）
- 2026-10-14 `active/`に`*.md`が1件もなければexit 0にする。記録先のplanがないのでブロックしても意味がなく、旧版もexit 0だった（新版でexit 2になったのは退行）
- 2026-10-14 exit 2のメッセージに「planの作業をしていない場合（レビュー・調査等）は対応不要。無関係なplanに追記しない」旨を明記する。`stop_hook_active`により2回目のSubagentStopは通るので、作業していないworktreeでは無視すればよい。指示どおり無関係なplanに追記されると`Worktree:`の記録が崩れる
- 2026-10-14 比較の前に行末の空白・CRを除く。`Worktree: /path `やCRLFのファイルでも一致させるため。前方一致での誤マッチは引き続き起こさない
- 2026-10-14 判定対象を各planの冒頭（最初の`## `見出しより前の行）に限る。ルールで「冒頭に記録する」と定めており、本文中の例示行で通過しないようにするため。代案の「`.claude/plans`を触った場合のみ検査する」は、planを編集しない作業でも記録が必要なため却下した
- 2026-10-14 `plans-maintenance`ルールに「worktreeごとに`Worktree: <path>`を1行ずつ書く」旨を明記する。追記方法が決まっていないと1行にカンマ区切りで並べられ、フックの完全一致に当たらなくなるため。新規subagentでの比較で、変更前はカンマ区切りで追記されることを確認した。`todoist-task-runner/SKILL.md`の「`Worktree:`に追記する」も、同じ書き方を誘うため「`Worktree:`行を記録する」に改める
- 2026-10-18 `plan-worktree-check.sh`の登録先は導入時（`27b23abb`）から`SubagentStop`であり、planやADR等で「Stopフック」と書いていたのは誤りだったため訂正した。ルールが`Worktree:`の記録を求めるのはサブエージェントのworktreeで作業する場合だけで、`SubagentStop`はそれと一致する。`Stop`に変えるとメインセッションが`EnterWorktree`でworktreeに入った場合にも動き、ルールの対象外でブロックが起きるため、登録先は変えない

## Validation and Acceptance

- 無関係なactive planにWorktree行がなくても、いずれか1件のactive planに完全一致のWorktree行があればフックがブロックしない
- どのactive planにも完全一致のWorktree行がなければexit 2でブロックし、作業中のplanへの追記を促す
- 前方一致の行や、最初の`## `見出しより後にしかない行では通らない。行末の空白・CRがあっても完全一致なら通る
- `stop_hook_active: true`・worktree外のcwd・plans_dirがない・`active/`にplanがない場合は何もしない
- `plans-maintenance`ルールと言及箇所が「作業を行う場合に、worktreeごとに1行で記録する」に揃っている
- tech-debtファイルが`Resolved`として`.claude/tech-debt/completed/`へ移動している
