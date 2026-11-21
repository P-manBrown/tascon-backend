# lefthook と CI の振り分けの基準のルール Implementation Plan

Spec: docs/design/specs/lefthook-ci-placement-rule.md

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (this Gas City lane does not use provider-native subagents; the only Agent use allowed is the `rule-tester` comparison test inside a headless Claude, described below). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tascon-backend に `.claude/rules/lefthook-ci-placement.md`（`paths`: `lefthook.yml`・`.lefthook/**`・`.github/workflows/**`）を足し、依頼の 5 点の基準を、道具の名前・具体例・理由なしの文で書く。入れる前と後の比較テストで、backend と frontend の全部の道具の振り分けを照らす表と比べ、結果と知らせる物を計画の Decision Log・PR の文案・bead の notes に残す。

**Architecture:** 変更はルールのファイル 1 つと、`docs/design/plans/active/` の計画のファイル 1 つだけ（コミットは 1 つ、`main` から切った 1 段のブランチ）。比較テストは `claude-md-maintenance` の必須手順を、Gas City の取り決め（worktree で起動した headless Claude の中で `rule-tester` を使い、git の操作は自分のセッションで行う）で読み替えて行う。場面は承認済みの設計の案 A（`.github/workflows/semantic-pull-request.yml` を読ませてルールを差し込ませ、道具の一覧を振り分けさせる）。

**Tech Stack:** Markdown（Claude Code の rules、`paths` の frontmatter）、git / git-spice、Claude Code の headless 実行（`claude -p --output-format stream-json`）、`rule-tester` サブエージェント、python3（stream-json から答えを取り出すだけ）。

---

## Context/Purpose

- 作るもの（2 ファイル、1 コミット）
  - `.claude/rules/lefthook-ci-placement.md`（新規）: 依頼の 5 点（BR-1〜BR-5）を基準の文として持つルール。初稿は承認済みの設計の「1. ルールのファイル」の文（REQ-001〜REQ-007）
  - `docs/design/plans/active/lefthook-ci-placement-rule.md`（新規）: この作業の計画。理由・比較テストの記録・知らせる物を Decision Log に置く（REQ-011・REQ-012・REQ-014）
- 変えないもの: `lefthook.yml`、`.lefthook/**`、`.github/workflows/**`、`.claude/rules/hooks-authoring.md`、`.claude/rules/scripts-authoring.md`、ほかの rules・skills・`AGENTS.md`・`.claude/CLAUDE.md`（REQ-013・BR-12）
- 比較テスト: 変更前 1 回・変更後 1 回（食い違いで文を直したら変更後をやり直す。直しは 3 回まで）。判定はファイル全体について 1 つの期待する行動で行う（BR-7・BR-8）
- 知らせる物: debride・Brakeman・Semgrep の分かれ方（BR-9）、今の設定とルールの食い違い（BR-10）、重なる記述の `grep` の結果（BR-12）。計画の Decision Log、PR の文案、bead の notes に書く
- 実装は 1 つのタスク（Task 1）。ルールの文・比較テスト・記録は互いに依存し、同じブランチで続けて行う
- ブランチ名: `docs/lefthook-ci-placement-rule`（`main` から切る 1 段のスタック）。比較テストを全部終えた後に作る（`claude-md-maintenance` の手順 5）
- この build は `push=true`・`open_pr=false`: push までで、PR は開かない。PR の文案（英語）は記録に残し、後段が使う

## Current System

### 今の状態（main `0f60f4ad`、2026-11-19 に読んだもの）

- `.claude/rules/` に lefthook・CI の置き場所の基準を書いたルールは無い
  - `hooks-authoring.md`: `paths` は `.claude/settings.json`・`.claude/hooks/**`（Claude Code のフック用）
  - `scripts-authoring.md`: `paths` は `.claude/settings.json`・`.claude/hooks/**`・`.claude/skills/**/scripts/**`・`.lefthook/**`・`lefthook.yml`（スクリプトの言語の決まり）。新しいルールと `paths` が重なるが、変えない（範囲外）
  - `claude-md-maintenance.md`: 比較テストの必須手順（手順 1〜6）と「SKILL.md/rules執筆時の原則」。手順 6 は「変更後にも現れない、または変更前にも現れる→ノイズ。その変更をその場で取り消し」
  - `plans-maintenance.md`: 計画は `Context/Purpose`・`Decision Log`・`Validation and Acceptance` 等の節を持ち、見出しの直後に `Spec:` 行を置く。内容は日本語、ファイル名は英語の kebab-case
- 書式の例（既存のルールの文体）: 日本語と英字・`` ` `` のあいだに空白を入れない（例: hooks-authoring の「違反の検出はpre-commitに任せる」）
- `lefthook.yml`（main）
  - pre-commit commands: `rubocop`（`--autocorrect --force-exclusion {staged_files}`、`stage_fixed`）、`htmlbeautifier`（`{staged_files}` を書き換える、`stage_fixed`）、`debride`（`{all_files}`）、`protect-branch`
  - pre-commit jobs: `check-docs.sh`、`check-plan-completion.sh`、`check-links.sh`、`.lefthook/pre-commit/tests/run.sh`、`.claude/skills/plan-completion/scripts/tests/run.sh`
  - pre-push: `check-git-clean`
- `.github/workflows/ci.yml`（main）: job `rspec`（MySQL のサービス）と job `checks`（rubocop、htmlbeautifier `--lint-only`、debride（`git ls-files '*.rb'` の全部）、check-docs.sh、pre-commit check tests、plan-completion script tests、check-plan-completion.sh）。`check-links.sh` は CI に無い
- `.github/workflows/semantic-pull-request.yml`（job `Validate PR title`）、`.github/workflows/related-documents.yml`（PR 本文の Related Documents の確かめ）
- `rule-tester`（`.claude/agents/rule-tester.md`）: `tools: Read, Grep, Glob, Skill`、`omitClaudeMd: true`。ガード `.claude/hooks/rule-tester-guard.sh` が `.claude/rules`・`skills`・`plans`・`memory` の Read と、それらを含む範囲の Grep・Glob を拒否する。定義の本文（frontmatter の後）は次の 5 行:

  ```markdown
  - 最初に、作業ディレクトリの`.claude/CLAUDE.md`と、そこで読み込みを指定している`AGENTS.md`を読む
  - `.claude/memory/`・`docs/design/plans/`配下のファイルは読まない。ただし、プロンプトで`docs/design/plans/rule-test-fixture.md`を読むよう指示されたときは、そのファイルだけ読む
  - `.claude/rules/`・`.claude/skills/`配下のファイルは、Read・Grep・Globで開いたり検索したりしない。ルールは関係するファイルを読んだときにシステムから差し込まれたもの、skillはSkillツールで呼び出したものだけを使う
  - ファイルの編集やコマンドの実行はしない。skillを呼び出しても、その手順は実行せず、手順に沿うなら何をするかを答える
  - 与えられたプロンプトに、読んだ文書に基づいて答え、根拠にしたファイルを挙げる
  ```

- `docs/decisions/rule-and-hook-change-tests.md`: 変更前の状態に、テスト対象の変更の記録（計画・Decision Log）と、gitStatus（ブランチ名）から推測できる変更内容を混ぜない
- `plan-completion` Skill の印（main）: 計画を最後まで終えた PR は `- ✅ Plan: <パス>`、設計が無ければ `- Spec: N/A`（Spec 行には印を付けない）
- 既存の計画の `Spec:` 行の例（`docs/design/plans/active/git-spice-merge-and-ci-gates.md`）: `Spec: N/A（設計と要件はGas Cityのbuildの成果物にあり、リポジトリには写していない）`
- `.gc-artifacts/` は `.git/info/exclude` で無視される（リポジトリに入らない）。計画から Markdown のリンクで指すと `check-links.sh` が落とすので、パスはコードの書式で書く
- 入れる予定の道具（共有の枝から読んだコマンド）
  - `origin/ci/add-simplecov-and-brakeman`（#836）: SimpleCov（rspec の中で率を step summary に書く）、job `brakeman`: `bin/bundle exec brakeman --no-pager`
  - `origin/ci/add-codeql-and-semgrep`（#837）: `codeql.yml` の `Analyze (ruby)`（`github/codeql-action/init`・`analyze`）、job `semgrep`: `semgrep scan --config <Rails の規則> --metrics=off --error`
  - `origin/ci/add-dependency-review`（#839）: job `dependency-review`（`actions/dependency-review-action`）
  - `origin/ci/add-code-review-graph-report`（#840）: `code-review-graph build` と `code-review-graph detect-changes --base origin/<base>` の報告（合否を返さない）
  - 枝 `ci/check-pr-language`: `pr-title-and-body.yml` の job `Check PR language`（PR のタイトル・本文の日本語の文字を確かめる）
  - 枝 `build/debride-full-scope`: lefthook の debride に `app config` を渡す案
- frontend（`P-manBrown/tascon-frontend`、#955 の枝 `chore/lefthook-safe-autofix-and-typecheck` の `lefthook.yml` を `gh api` で読んだ）
  - pre-commit: `yarn biome check --write --error-on-warnings {staged_files}`、`yarn markuplint {staged_files}`、`yarn markdownlint-cli2 {staged_files}`、`grep -nFH 'logger.trace' {staged_files}`、protect-branch、`bash .lefthook/pre-commit/check-docs.sh`
  - pre-push: `yarn knip`、check-git-clean、`yarn next typegen && yarn tsc --noEmit`
- 用語の重なり（`grep -rln "pre-push\|pre-commit\|必須のチェック\|lefthook"`、`scripts/` を除く）: `.claude/rules/hooks-authoring.md`・`scripts-authoring.md`・`code-comments.md`、`.claude/skills/doc-gardening/SKILL.md`・`plan-completion/SKILL.md`、`docs/decisions/` の 8 ファイル（`precommit-checks-by-target.md` ほか）。中身の食い違いは Task 1 の Step 9 で確かめる

## Proposed Implementation

### 全体の進め方（lifecycle との関係）

この計画の後の段（plan-review、decompose、実装、要約、review、finalize、publish）は formula が進める。下の `### Task 1` だけが実装の bead になる。Task 1 は push まで行い、PR は開かない。

### 決めたこと

- D1: 実装は Task 1 の 1 つ。ルールの文は比較テストの結果で直し、記録はその結果を書くので、分けると同じ作業ツリーの状態を引き継げない
- D2: ブランチは `docs/lefthook-ci-placement-rule` を `main` から切る（`git-spice branch create docs/lefthook-ci-placement-rule --target main --no-commit`）。type は `docs`（ルールの文書の追加で、SemVer に影響しない）。作るのは比較テスト（Step 7 の変更後のやり直しを含む）を全部終えた後（Step 11 の最初）。`claude-md-maintenance` の手順 5 と `docs/decisions/rule-and-hook-change-tests.md` の「変更内容を表すブランチはテストの後に作る」に従う。テストの間は、worktree の元の HEAD の状態（元の枝、または detach）のまま作業し、変更内容を表す枝を作らない。worktree の元の枝（Gas City が付けた名前など）は使わず、コミットもしない
- D3: 比較テストは、ルールと計画をコミットする前に行う（`claude-md-maintenance` の「コミット前にその場で」）。テストの間、計画は「その他」の stash に、ルールは「テスト対象」の stash に退避する。worktree の HEAD は `origin/main` と同じでコミットが無いので、手順 3 の「最初に含むコミットの1つ前」は今の土台のコミットそのものになる
- D4: 変更前と変更後のどちらの起動も、worktree を土台のコミット（`origin/main` と同じ HEAD）へ detach した状態で行う。gitStatus に元の枝の名前が出て変更の中身を推測されるのを、変更前・変更後の両方で同じに避けるため（`docs/decisions/rule-and-hook-change-tests.md`）。detach の先は土台と同じコミットなので、手順 3 の `rule-tester` の定義とガードを置き直す操作は要らない（同じ版）。それでも定義とガードが今の版で動くことは引用とガードの拒否で確かめる（TS-6）。テストの起動の後は、Step 1 で控えた元の HEAD の状態（元の枝、または detach のまま）に戻る
- D5: 場面は案 A。`rule-tester` に `.github/workflows/semantic-pull-request.yml` を読ませてルールを差し込ませ、道具の一覧を振り分けさせる。一覧には、リポジトリ・道具の名前・走らせるコマンド・直すオプションの有無（事実）だけを書き、今の置き場所・ルールの名前・基準の言葉（速さ、要る物、ビルド・サーバー・ブラウザ・DB など）は書かない。今の置き場所を写させないよう、ほかの lefthook の設定とワークフローのファイルは読まないよう頼む（変更前・変更後で同じプロンプト）
- D6: 判定は、ファイル全体について 1 つの期待する行動（BR-7）で行う。文ごとには判定しない（BR-8）
- D7: 判定がノイズ（変更後にも期待する行動が出ない、または変更前にも出ている）でも、依頼の 5 点の文はどれも取り消さない。これは `claude-md-maintenance` の手順 6（ノイズは取り消す）と食い違う。requirements の BR-8 が承認済みの設計の「4. 失敗と止め方」の 3 点目に代わり、依頼（5 点を書いたルールを作る）を優先する。食い違いと判定は、計画の Decision Log・PR の Testing・bead の notes に書いて人に知らせる。この決定は計画の Decision Log に最初から書く（Step 2）
- D8: 照らす表の段と食い違った所は、例を足さずに基準の文を直し、同じプロンプトで変更後だけをやり直す。直しは依頼の 5 点の意味を変えない範囲に限り、3 回まで。それでも残る食い違いは直さずに残し、知らせる（BR-8）
- D9: 今の設定とルールの食い違い（BR-10）と、重なる記述の食い違い（BR-12）は、設定も文書も直さず、知らせる物として記録する
- D10: 計画の `Spec:` 行は `Spec: N/A（設計と要件はGas Cityのbuildの成果物にあり、リポジトリには写していない）`（既存の計画と同じ形）。設計・要件のパスは `.gc-artifacts/` のため、Markdown のリンクにしない
- D11: 比較テストの生の出力（stream-json）と取り出した答えは、build の成果物の folder `/home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/comparison-test/` に置く（リポジトリには入れない）。計画の Decision Log には、プロンプトの全文・答えの要約と照合の表・判定・直した文を書く
- D12: debride・Brakeman・Semgrep の分かれ方と知らせる物は、実装の bead の notes と workflow root `tb-z3r00` の notes に追記する（閉じない）

### 前提（曖昧さへの判断）

- A1〜A4: requirements の仮定 1〜4 のとおり（frontend の決まった形は #955、「必須にする確かめ」は中身を確かめる物、入れる予定の道具の範囲、SimpleCov・code-review-graph は報告として照らす）
- A5: 照合の「段」は、照らす表で lefthook に入る物はその段（pre-commit ＋ CI は「pre-commit」）、lefthook に入らない物は「CI だけ」、手元の状態を見る物は「手元だけ」とする。答えが「pre-commit と CI」のように両方を挙げたら、lefthook の段で照らす
- A6: Vitest は一覧で 1 つの道具（全部のテストと、関係するテストだけ、の 2 つのコマンド）として出し、照合は「全部のテスト＝CI だけ」で見る。「関係するテストだけ」の答えは記録だけする
- A7: `rule-tester` の答えにルールの基準が根拠として現れない（差し込まれていない見込み）ときは、同じプロンプトで 1 回だけやり直す。それでも現れなければ判定をノイズとして D7 で扱う
- A8: 直し（D8）は依頼の 5 点の意味を変えない範囲。「CI だけ」の条件に PR のタイトル・本文・依存の差分など GitHub の PR の情報を見る物を足すかは、「段は何を要るかで決める」の意味の中の明確化として許す。lefthook の段の 4 つの区分そのもの（pre-commit・pre-push・CI だけ・手元だけ）は変えない

### 比較テストの実行の仕方（Step 4〜Step 7 で使う）

`rule-tester` を 1 回起動するごとに、worktree で headless Claude を 1 つ起動する。実装者のセッションから次を実行する（`<WT>` は worktree の絶対パス、`<OUT>` は出力ファイルの絶対パス、`<PROMPT_FILE>` はプロンプトを書いたファイルの絶対パス）:

```bash
cd <WT> && claude -p "$(printf '%s\n\n%s\n' 'Agent ツールで rule-tester サブエージェントを isolation なしで 1 回だけ起動し、次の「プロンプト:」の行より下の文だけをそのまま与えて。ほかのツールは使わず、rule-tester の答えを手を加えずにそのまま返して。' "プロンプト:
$(cat <PROMPT_FILE>)")" --allowedTools "Agent Skill Read Grep Glob" --output-format stream-json --verbose > <OUT>
```

- 答えは `<OUT>` の stream-json から、Agent ツールの結果（`tool_result`）の本文を取る。リポジトリの Stop フックが最後に足す返答は答えではない
- 取り出し（`<OUT>.answer.md` に書く）:

  ```bash
  python3 -c 'import json,sys
  out=[]
  for l in open(sys.argv[1]):
      l=l.strip()
      if not l: continue
      m=json.loads(l)
      if m.get("type")!="user": continue
      for c in (m.get("message",{}).get("content") or []):
          if isinstance(c,dict) and c.get("type")=="tool_result":
              x=c.get("content")
              out.append(x if isinstance(x,str) else "".join(i.get("text","") for i in x if isinstance(i,dict)))
  print("\n\n".join(out))' <OUT> > <OUT>.answer.md
  ```

- 1 回の起動ごとに新しい headless Claude を使う（前の答えを持ち越さない）
- 出力の置き場所: `/home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/comparison-test/`。名前は `00-definition.jsonl`、`01-before.jsonl`、`02-after-r0.jsonl`、直した後は `02-after-r1.jsonl`・`02-after-r2.jsonl`・`02-after-r3.jsonl`（`r<n>` は直した回数）
- プロンプトのファイル: 同じ folder に `prompt-definition.txt`・`prompt-scene.txt` として書く（Step 3）

### 照合に使う表（決まっている道具の段）

比較テストの答え合わせだけに使う（ルールにも、テストのプロンプトにも書かない）。ID はプロンプトの一覧と同じ。

| 道具 | 決まった段 | 備考 |
| --- | --- | --- |
| B1 rubocop | pre-commit | ＋ CI。lefthook で `--autocorrect` |
| B2 htmlbeautifier | pre-commit | ＋ CI（`--lint-only`）。lefthook で直す（直しの判断は知らせる） |
| B3 debride | 決まっていない | 分かれ方を記録 |
| B4 protect-branch | 手元だけ | |
| B5 check-docs.sh | pre-commit | ＋ CI |
| B6 check-plan-completion.sh | pre-commit | ＋ CI |
| B7 check-links.sh | pre-commit | CI に無い（知らせる） |
| B8 pre-commit check tests | pre-commit | ＋ CI |
| B9 plan-completion script tests | pre-commit | ＋ CI |
| B10 check-git-clean | 手元だけ | |
| B11 rspec | CI だけ | |
| B12 Validate PR title | CI だけ | |
| B13 Related Documents の確かめ | CI だけ | |
| B14 SimpleCov | CI だけ | 報告（合否を返さない） |
| B15 Brakeman | 決まっていない | 分かれ方を記録 |
| B16 Semgrep | 決まっていない | 分かれ方を記録 |
| B17 CodeQL | CI だけ | 別のワークフロー（知らせる） |
| B18 Dependency Review | CI だけ | |
| B19 code-review-graph | CI だけ | 報告（合否を返さない） |
| B20 PR の言語の確かめ | CI だけ | |
| F1 biome | pre-commit | ＋ CI。lefthook で `--write` |
| F2 markuplint | pre-commit | ＋ CI。直さない |
| F3 markdownlint | pre-commit | CI に無い（知らせる） |
| F4 check-logger-trace | pre-commit | CI に無い（知らせる） |
| F5 protect-branch | 手元だけ | |
| F6 check-docs.sh | pre-commit | CI に無い（知らせる） |
| F7 knip | pre-push | ＋ CI |
| F8 型の確かめ | pre-push | ＋ CI |
| F9 next build | CI だけ | |
| F10 check-git-clean | 手元だけ | |
| F11 semantic-pull-request | CI だけ | |
| F12 Vitest | CI だけ | 全部のテスト。関係するテストだけは pre-push |
| F13 Playwright | CI だけ | |
| F14 Stryker | CI だけ | |

### Task 1: lefthook と CI の振り分けの基準のルールを足し、比較テストで照らして記録する

**Files:**
- Create: `.claude/rules/lefthook-ci-placement.md`
- Create: `docs/design/plans/active/lefthook-ci-placement-rule.md`
- Test（リポジトリの外、コミットしない）: `/home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/comparison-test/`（プロンプト・stream-json・取り出した答え・照合の表）
- Record（リポジトリの外）: `/home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/comparison-test/record.md`（判定・照合・知らせる物・PR の文案）、実装の bead と `tb-z3r00` の notes
- 変えない: `lefthook.yml`、`.lefthook/**`、`.github/workflows/**`、`.claude/rules/hooks-authoring.md`、`.claude/rules/scripts-authoring.md`、ほかの rules・skills・`AGENTS.md`・`.claude/CLAUDE.md`・`docs/`

**満たす要求:** REQ-001〜REQ-014

**受け入れ基準:** requirements.md の AC-1〜AC-10。下の Step 10 の確認がすべて通り、Step 11 の記録と push があること。

- [ ] **Step 1: 準備を確かめる**

  - セッションの作業ディレクトリが、この作業の worktree（`.claude/worktrees/<name>`）であること。メインの checkout（`/home/ruby/tascon-backend`）では枝を切り替えない
  - この Step ではブランチを作らない（ブランチは比較テストの後、Step 11 の最初に作る。D2）
  - `git fetch origin main` の後、確かめる（結果を `record.md` に書く）:
    - `git status --porcelain` が空
    - `git log --oneline origin/main..HEAD` が空で、`git rev-parse HEAD` が `git rev-parse origin/main` と同じ。違えば（元の枝にコミットがある、または古い）、元の枝は動かさずに `git switch --detach origin/main` で土台へ移り、移ったことと Current System とのずれを記録する
    - 元の HEAD の状態を控える: `git branch --show-current` の出力（空なら detach）を `record.md` に「元の HEAD の状態」として書く。Step 4〜Step 7 はこの状態へ戻る（枝なら `git switch <その枝>`、detach なら移らない）
    - `git rev-parse main` が `git rev-parse origin/main` と同じか（Step 11 の `--target main` の土台）。違えば、違いを `record.md` と bead の notes に書く（`main` はメインの checkout で使われているので、ここでは動かさない）
    - `ls .claude/rules/lefthook-ci-placement.md` が「無い」で失敗する
    - `sed '1,/^---$/{/^---$/!d};1,/^---$/d' .claude/agents/rule-tester.md | sed '/^$/d'`（frontmatter の後の本文）が Current System の定義の 5 行と同じ（全体を `cat .claude/agents/rule-tester.md` で出して目で比べてもよい）
    - `git diff origin/main -- lefthook.yml .github/workflows` が空、`grep -n "check-links" .github/workflows/ci.yml` が何も出さない（Current System と同じ）
  - `mkdir -p /home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/comparison-test`

- [ ] **Step 2: ルールと計画のファイルを書く（REQ-001〜REQ-007、REQ-012 の初稿）**

  - `.claude/rules/lefthook-ci-placement.md` を次の内容で作る（承認済みの設計の初稿。文体は既存のルールに合わせ、日本語と英字のあいだに空白を入れない）:

    ```markdown
    ---
    paths:
      - "lefthook.yml"
      - ".lefthook/**"
      - ".github/workflows/**"
    ---

    # lefthookとCIへの確かめの振り分け

    ## CI

    - 中身を確かめる物（コードや文書が決まりに合っているか、テストが通るか）はCIに入れ、リポジトリ全体を対象にして必須のチェックにする。CIでは直さずに落とす
    - 中身を確かめる必須のチェックは1つのワークフローに置き、そのワークフローのまとめ役のジョブ`checks`だけを必須のチェックにする

    ## lefthookの段

    - lefthookのどの段に置くかは、速さでなく、その確かめが何を要るかで決める
      - pre-commit: 変えたファイルだけで確かめられる物
      - pre-push: プロジェクト全体は要るが、ビルド・サーバー・ブラウザ・DBは要らない物
      - CIだけ: ビルド・サーバー・ブラウザ・DBが要る物、またはテストを何度も走らせる物
      - 手元だけ: 手元の状態を見る物

    ## lefthookでの直し

    - lefthookで直すのは、意味を変えないと保証された直しだけにする

    ## 変えるとき

    - lefthookかCIのどちらかを変えたら、同じPRでもう一方にも要るかを確かめる
    ```

  - `docs/design/plans/active/lefthook-ci-placement-rule.md` を次の内容で作る（比較テストの結果の節は Step 8 で埋める。ここでは見出しと、テストの前に決まっていることだけを書く）:

    ```markdown
    # lefthookとCIの振り分けの基準のルール

    Spec: N/A（設計と要件はGas Cityのbuildの成果物にあり、リポジトリには写していない）

    ## Context/Purpose

    - 確かめ（lint・テスト・文書の検査など）をlefthookのどの段に置くか、CIに置くかの基準が無く、AIが`lefthook.yml`・`.lefthook/**`・`.github/workflows/**`を変えるときに置き場所を速さなどで決めてしまう
    - `.claude/rules/lefthook-ci-placement.md`を足し、人が決めた基準（依頼の5点）を、道具の名前・具体例・理由なしの文で書く。後でdev-workflow-shared経由でfrontendにも配るため、backendだけの道具名・パス・ジョブの中身は書かない
    - `claude-md-maintenance`の比較テストで、ルールを入れる前と後の振り分けを、今決まっている置き場所（下の「照らす表」）と照らす
    - 作業のブランチは`docs/lefthook-ci-placement-rule`（`main`から切った1段）で、比較テストを終えた後に作る。変更はルールとこの計画の2ファイルだけで、`lefthook.yml`・`.lefthook/**`・`.github/workflows/**`は変えない
    - 照らす表（答え合わせだけに使う。ルールには書かない）
      - backend（今）: rubocop pre-commit（安全な直し）＋CI／htmlbeautifier pre-commit（直す）＋CI（`--lint-only`）／debride 決まっていない／protect-branch 手元だけ／`check-docs.sh`・`check-plan-completion.sh` pre-commit＋CI／`check-links.sh` pre-commit（CIに無い）／`.lefthook/pre-commit/tests/run.sh`・plan-completionのスクリプトのテスト pre-commit＋CI／check-git-clean 手元だけ／rspec CIだけ／Validate PR title・Related Documentsの確かめ CIだけ
      - backend（入れる予定）: SimpleCov CIだけ（報告）／Brakeman・Semgrep 決まっていない／CodeQL CIだけ（別のワークフロー）／Dependency Review CIだけ／code-review-graph CIだけ（報告）／PRの言語の確かめ CIだけ
      - frontend（今。#955の形）: biome pre-commit（safeな直し）＋CI／markuplint pre-commit（直さない）＋CI／markdownlint・check-logger-trace・`check-docs.sh` pre-commit／protect-branch 手元だけ／knip・`next typegen && tsc --noEmit` pre-push＋CI／`next build` CIだけ／check-git-clean 手元だけ／semantic-pull-request CIだけ
      - frontend（入れる予定）: Vitestの全部のテスト CIだけ（pre-pushは関係するテストだけ）／Playwright CIだけ／Stryker CIだけ

    ## Decision Log

    - ルールの中身は人の依頼の4点と、追加の1点（必須にする確かめは1つのワークフローに置き、まとめ役のジョブ`checks`だけを必須のチェックにする）。追加の1点は、まとめ役のジョブが`needs`で待てるのは同じワークフローのファイルの中のジョブだけのため（人の依頼の説明による）
    - 追加の1点の「必須にする確かめ」は、中身を確かめる物に限る。PRのタイトルの確かめ（Validate PR title）も必須に登録するが、別のワークフローのままでよいため
    - 具体例・道具の名前は書かない。人の依頼が明示しており、`claude-md-maintenance`の「代表例を添える」例外は使わない。比較テストで食い違ったら、例を足さずに基準の文を直す
    - `.claude/rules/hooks-authoring.md`（Claude Codeのフック用）とは別のファイルにする。`paths`が`lefthook.yml`・`.lefthook/**`・`.github/workflows/**`で、フックの`paths`と重ならないため。`scripts-authoring.md`と`paths`が重なるが、扱う中身（スクリプトの言語）が違うので変えない
    - 比較テストの判定は、文ごとではなく、ルールのファイル全体について1つの期待する行動で行う。判定がノイズ（変更後にも期待する行動が出ない、または変更前にも出ている）でも、依頼の5点の文はどれも取り消さずに残す。これは`claude-md-maintenance`の手順6（ノイズはその場で取り消す）と食い違う。依頼が5点を書いたルールを作ることを求めているため、依頼を優先し、判定と食い違いをここ・PRのTesting・作業の記録に書いて人に知らせる
    - 照らす表と食い違った所は、依頼の5点の意味を変えない範囲で基準の文を直し、同じプロンプトで変更後のテストをやり直す（3回まで）。その範囲で直らない食い違いは残して知らせ、基準を変えるか置き場所を変えるかは人が決める
    - 今の設定とルールの食い違い（CIに無い確かめ、別のワークフローの確かめ、lefthookの直しの判断）は、このPRでは設定もルールの文も直さず、知らせる物として下に書く
    - frontendの「今決まっている置き場所」は、開いている#955の形とする。#955が決定の記録をAcceptedで持つため
    - SimpleCov・code-review-graphは合否を返さない報告のため、必須にする確かめではなく、CIだけの報告として照らす

    ### 比較テスト

    （Step 8で書く）

    ### 知らせる物

    （Step 8・Step 9で書く）

    ## Validation and Acceptance

    - `.claude/rules/lefthook-ci-placement.md`があり、`paths`がちょうど`lefthook.yml`・`.lefthook/**`・`.github/workflows/**`の3つ。`.claude/rules/hooks-authoring.md`は変わっていない
    - 本文が依頼の5点を基準の文として持ち、道具の名前・具体例・理由・強調語・backendだけのパスやジョブの中身を含まない
    - 比較テストを`claude-md-maintenance`の手順で行い、判定・照らした結果・直した文がこの計画のDecision LogとPRのTestingにある
    - debride・Brakeman・Semgrepがルールでどう分かれたかと、今の設定とルールの食い違いが、直されずにこの計画とPRに書かれている
    - `lefthook.yml`・`.lefthook/**`・`.github/workflows/**`の中身が変わっていない
    - dev-workflow-sharedから配ったfrontendでの効き目は、この計画の範囲外（配る段で確かめる）
    ```

  - 確かめる: `git status --porcelain` が `?? docs/design/plans/active/lefthook-ci-placement-rule.md` と `?? .claude/rules/lefthook-ci-placement.md` の 2 行だけ

- [ ] **Step 3: 比較テストのプロンプトを書き出す（手順 1、REQ-008）**

  - 期待する行動（1 点、BR-7）: 道具の置き場所を、速さでなく確かめに要る物（変えたファイルだけ／プロジェクト全体／ビルド・サーバー・ブラウザ・DB・テストの繰り返し／手元の状態）で決め、決まっている道具では照らす表の段と一致させる
  - `comparison-test/prompt-definition.txt`（定義とガードの確認。TS-6）:

    ```text
    比較テストの前に、あなたの定義を確かめたい。次の 2 つだけを行って答えて。
    1. あなたのエージェント定義の指示文（箇条書きの部分）を、一字も変えずにそのまま引用して。
    2. Read ツールで .claude/rules/claude-md-maintenance.md を開こうとして、その結果（開けたか、拒否されたか、拒否の理由の文）をそのまま書いて。中身は引用しない。
    ```

  - `comparison-test/prompt-scene.txt`（場面。変更前・変更後で同じ。D5）:

    ```text
    .github/workflows/semantic-pull-request.yml を読んでから答えて。

    backend（このリポジトリ、Rails）と frontend（別のリポジトリ、Next.js）の確かめの置き場所を、lefthook の段と CI について白紙から見直している。今の lefthook.yml と、semantic-pull-request.yml 以外の .github/workflows/ のファイルは、今の置き場所を写さないために読まないで（.lefthook/ の下のスクリプトの中身は読んでよい）。

    下の道具ごとに、次の 4 つを答えて。
    - 段: pre-commit・pre-push・CI だけ・手元だけ のどれか 1 つ（lefthook と CI の両方に置くなら lefthook の段を書く）
    - CI: CI に入れるか。入れるなら、マージの前に通っていないといけない必須のチェックにするか
    - 直し: lefthook で走らせるときにファイルを直してよいか
    - 根拠: その段・CI・直しにした理由と、根拠にしたファイル

    答えは、道具の ID ごとに 1 行（「ID 名前: 段 / CI / 直し / 根拠」）で書いて。

    backend
    - B1 rubocop: `bin/bundle exec rubocop`（直すオプション `--autocorrect` がある）
    - B2 htmlbeautifier: `bin/bundle exec htmlbeautifier <erb のファイル>`（渡したファイルを書き換える。`--lint-only` を付けると書き換えずに確かめだけする）
    - B3 debride: `bin/bundle exec debride --rails -w debride-whitelist.txt <rb のファイル>`
    - B4 protect-branch: `git branch --show-current | grep -Eqvx 'main'`
    - B5 check-docs.sh: `bash .lefthook/pre-commit/check-docs.sh`
    - B6 check-plan-completion.sh: `bash .lefthook/pre-commit/check-plan-completion.sh`
    - B7 check-links.sh: `bash .lefthook/pre-commit/check-links.sh`
    - B8 pre-commit check tests: `bash .lefthook/pre-commit/tests/run.sh`
    - B9 plan-completion script tests: `bash .claude/skills/plan-completion/scripts/tests/run.sh`
    - B10 check-git-clean: `test -z "$(git status --porcelain)"`
    - B11 rspec: `bin/bundle exec rspec`
    - B12 Validate PR title: semantic-pull-request.yml の job
    - B13 Related Documents の確かめ: `bash .claude/skills/plan-completion/scripts/check-pr-body.sh --body-file <PR の本文>`
    - B14 SimpleCov: rspec の中でテストのカバレッジの率を書き出す（合否は返さない）
    - B15 Brakeman: `bin/bundle exec brakeman --no-pager`
    - B16 Semgrep: `semgrep scan --config <Rails の規則> --metrics=off --error`
    - B17 CodeQL（Ruby）: `github/codeql-action/init` と `github/codeql-action/analyze`
    - B18 Dependency Review: `actions/dependency-review-action`
    - B19 code-review-graph: `code-review-graph build` の後に `code-review-graph detect-changes --base <PR の土台の枝>` で報告を書く（合否は返さない）
    - B20 PR の言語の確かめ: PR のタイトルと本文に日本語の文字があれば落とす

    frontend
    - F1 biome: `yarn biome check --error-on-warnings <ファイル>`（直すオプション `--write` がある）
    - F2 markuplint: `yarn markuplint <ファイル>`（直すオプション `--fix` がある）
    - F3 markdownlint: `yarn markdownlint-cli2 <ファイル>`
    - F4 check-logger-trace: `grep -nFH 'logger.trace' <src のファイル>` で見つかれば落とす
    - F5 protect-branch: `git branch --show-current | grep -Eqvx 'main'`
    - F6 check-docs.sh: `bash .lefthook/pre-commit/check-docs.sh`
    - F7 knip: `yarn knip`
    - F8 型の確かめ: `yarn next typegen && yarn tsc --noEmit`
    - F9 next build: `yarn next build`
    - F10 check-git-clean: `test -z "$(git status --porcelain)"`
    - F11 semantic-pull-request: PR のタイトルの形を確かめる GitHub Actions の job
    - F12 Vitest: `yarn vitest run`（全部のテスト）と `yarn vitest related <ファイル>`（変えたファイルに関係するテストだけ）
    - F13 Playwright: `yarn playwright test`
    - F14 Stryker: `yarn stryker run`
    ```

  - 確かめる: `prompt-scene.txt` に「速さ」「要る」「ビルド・サーバー」「DB」「必須のチェック」「lefthook-ci-placement」が無い（`grep -nE '速さ|要る|ビルド・サーバー|DB|必須のチェック|lefthook-ci-placement' prompt-scene.txt` が何も出さない）。「必須のチェックにするか」は質問の言葉で出るので、出たらその 1 行だけで、基準の文ではないことを目で確かめる

- [ ] **Step 4: 退避して detach し、定義を確かめて変更前を取る（手順 2・3、REQ-008）**

  - 退避（手順 2）: テスト対象は `.claude/rules/lefthook-ci-placement.md`。計画は「その他」に入る
    - `git stash push -u -m lefthook-ci-placement-rule-cmm-other-1 -- . ':(exclude).claude/rules/lefthook-ci-placement.md'`
    - `git stash push -u -m lefthook-ci-placement-rule-cmm-target -- .claude/rules/lefthook-ci-placement.md`
    - `No local changes to save` で何も退避しなかったときは、対応する pop をしない
    - 確かめる: `git status --porcelain` が空。`git stash list | grep lefthook-ci-placement-rule-cmm` が 2 行
  - detach（D4）: 元の HEAD の状態が枝なら `git switch --detach HEAD`、detach なら移らない。確かめる: `git branch --show-current` が空、`git rev-parse HEAD` が `origin/main` と同じ
  - 定義とガードの確認（TS-6）: 「比較テストの実行の仕方」で `prompt-definition.txt` を与え、`00-definition.jsonl` に出す
    - 1 の引用が Current System の定義の 5 行と同じこと（`diff <(sed '1,/^---$/{/^---$/!d};1,/^---$/d' .claude/agents/rule-tester.md | sed '/^$/d') <(引用の 5 行)` で比べてよい。目で 1 行ずつ比べてもよい）
    - 2 が拒否で、理由に `比較テストの条件を保つため` を含むこと
    - どちらかがずれたら `touch .claude/agents/rule-tester.md .claude/hooks/rule-tester-guard.sh` し、35 秒以上おいてから同じ確認をやり直す（`01` 以降の番号は変えず、`00-definition-retry.jsonl` に出す）。2 回目もずれたら Step 4 を止め、退避を戻して（Step 6 の戻し方）bead を blocked にする
  - 変更前（手順 3）: `prompt-scene.txt` を与え、`01-before.jsonl` に出す。`01-before.jsonl.answer.md` に B1〜F14 の 34 行がそろっていること。そろっていなければ同じプロンプトで 1 回だけやり直し（`01-before-retry.jsonl`）、やり直しの答えを使う

- [ ] **Step 5: 変更後を取る（手順 4、REQ-008）**

  - detach したまま、テスト対象の stash を名前で戻す: `git stash list` で `lefthook-ci-placement-rule-cmm-target` の `stash@{n}` を探し、`git stash pop stash@{n}`
  - 確かめる: `git status --porcelain` が `?? .claude/rules/lefthook-ci-placement.md` の 1 行だけ。`git branch --show-current` が空
  - `prompt-scene.txt` を与え、`02-after-r0.jsonl` に出す。答えに B1〜F14 の 34 行がそろうこと（そろわなければ Step 4 と同じく 1 回だけやり直す）
  - 答えの根拠に、差し込まれたルールの基準（変えたファイルだけ・プロジェクト全体・ビルド・サーバー・ブラウザ・DB・手元の状態など）が現れているかを控える。現れなければ前提 A7 のとおり 1 回だけやり直す

- [ ] **Step 6: 元の HEAD の状態へ戻り、その他の stash を戻す（手順 4・5）**

  - Step 1 で控えた元の HEAD の状態へ戻る: 枝なら `git switch <その枝>`、detach なら移らない（ルールの未追跡のファイルはそのまま持ち越す）
  - `git stash list` で `lefthook-ci-placement-rule-cmm-other-1` の `stash@{n}` を探し、`git stash pop stash@{n}`
  - 確かめる: `git branch --show-current` が Step 1 で控えた出力と同じ（detach なら空）。`git rev-parse HEAD` が `origin/main` と同じ。`git status --porcelain` が Step 2 の 2 行。`git stash list | grep lefthook-ci-placement-rule-cmm` が何も出さない
  - ここではまだ `docs/lefthook-ci-placement-rule` を作らない（Step 7 のやり直しを終えた後、Step 11 の最初に作る）

- [ ] **Step 7: 照らして判定し、食い違いは文を直して変更後をやり直す（手順 6、BR-7・BR-8、REQ-008・REQ-009）**

  - 照合: `comparison-test/record.md` に、「照合に使う表」の 34 行それぞれについて「決まった段／変更前の段と根拠の要約／変更後の段と根拠の要約／一致」を書く。決まっていない道具（B3・B15・B16）は一致を見ず、段・CI・直しを書く
  - 判定（ファイル全体で 1 つ、D6）:
    - 期待する行動が「変更前に無く変更後にある」: 変更後の根拠が確かめに要る物で置き場所を決めており、決まっている道具の段が照らす表と一致している。変更前は、根拠が速さ・重さ・慣習で決めている、または段の食い違いが多い。変更前でも段が一致した道具は、その道具を根拠で判定したことを書く
    - ノイズ（変更後にも出ない、または変更前にも出る）: 文は取り消さない（D7）。判定と食い違いを記録する
  - 食い違い（変更後の段が照らす表と違う、決まっている道具）があれば、D8・前提 A8 のとおり、例を足さずに基準の文だけを直す。直したら、前の答えと直した文を `record.md` に書き、次をやり直す:
    - `git stash push -u -m lefthook-ci-placement-rule-cmm-other-<n> -- . ':(exclude).claude/rules/lefthook-ci-placement.md'`（計画を退避。`<n>` は 2 から順に）
    - 元の HEAD の状態が枝なら `git switch --detach HEAD`（detach なら移らない）。`git branch --show-current` が空
    - `prompt-scene.txt` を与え、`02-after-r<n-1>.jsonl` に出す（`<n-1>` は直した回数。1 回目の直しの後は `02-after-r1.jsonl`。変更前はやり直さない）
    - Step 1 で控えた元の HEAD の状態へ戻り（枝なら `git switch <その枝>`、detach なら移らない）、`lefthook-ci-placement-rule-cmm-other-<n>` を名前で戻す
    - 照合をやり直す
  - 直しは 3 回まで。直した文が依頼の 5 点の意味を変えていないこと（BR-1〜BR-5 の意味を保つこと）を、直すたびに `record.md` に 1 行で書く。意味を変えないと直せない食い違いは直さずに残す
  - 予想される食い違いの候補（試す前に文を直さない）: F12 Vitest の全部のテストが pre-push、B8・B9 のスクリプトのテストが pre-push、B12・B13・B18・B20 が「CI だけ」以外、B17 CodeQL の別ワークフロー（設定の側の話。直さない）
  - 結果として残すルールの文が、AC-3（道具の名前・具体例・理由・強調語・backend だけのパスやジョブの中身が無い）を満たしていること: `grep -nE 'IMPORTANT|YOU MUST|rubocop|rspec|debride|biome|vitest|Vitest|knip|ため|例:|例えば|\.lefthook/|ci\.yml' .claude/rules/lefthook-ci-placement.md` が frontmatter の `".lefthook/**"` の 1 行だけを出す

- [ ] **Step 8: 計画の Decision Log に比較テストと知らせる物を書く（REQ-009〜REQ-012）**

  `docs/design/plans/active/lefthook-ci-placement-rule.md` の「### 比較テスト」「### 知らせる物」の `（Step 8で書く）` などの行を、次の中身に置き換える（日本語、`record.md` から写す）:

  - 「### 比較テスト」
    - 期待する行動（Step 3 の 1 文）
    - 手順: `claude-md-maintenance` の必須手順。`rule-tester` は作業のworktreeで起動したheadless Claudeの中で起動し、変更前・変更後とも土台のコミットへdetachして行った（ブランチ名を見せないため）。変更内容を表すブランチはテストを終えた後に作った。テストの時点でコミットが無いので、手順3の定義とガードの置き直しは要らず、定義の引用とガードの拒否で今の版で動くことを確かめた（結果を 1 行で）
    - プロンプトの全文（`prompt-scene.txt` をコードブロックで）
    - 照らした結果: 34 行の照合（道具・決まった段・変更前・変更後・一致）を箇条書きで
    - 判定（期待する行動が変更前に無く変更後にあるか、またはノイズ）と、その根拠
    - 直した文（直す前・直した後・直した理由、何回目の答えで何が変わったか）。無ければ「無し」
    - ノイズと判定したときは、5 点を取り消さずに残したことと、`claude-md-maintenance` の手順 6 との食い違い
  - 「### 知らせる物」
    - debride・Brakeman・Semgrep がルールでどう分かれたか（段・CI に入れるか・必須にするか・lefthook で直すか、変更後の答えの根拠の要約）（BR-9）
    - 直らずに残った食い違い（道具、決まった段、ルールでの段、残した理由）。基準を変えるか置き場所を変えるかは人が決める（BR-8）
    - 今の設定とルールの食い違い（BR-10）: 少なくとも次を、変更後の答えに照らして書く。設定は直していない
      - backend の `check-links.sh` が CI に無い
      - frontend の markdownlint・check-logger-trace・`check-docs.sh` が CI に無い
      - CodeQL が必須の確かめを置く 1 つのワークフローの外（別のワークフロー）にある
      - htmlbeautifier の lefthook での書き換えが「意味を変えないと保証された直し」に当たるかの、変更後の答えの判断
      - そのほか、変更後の答えが今の置き場所と違う所
    - 重なる記述の確かめ（Step 9 の結果）
  - 書いた後、計画の中に `（Step 8で書く）`・`（Step 8・Step 9で書く）` が残っていないこと（`grep -n 'Step 8で書く\|Step 9で書く' docs/design/plans/active/lefthook-ci-placement-rule.md` が何も出さない）

- [ ] **Step 9: 重なる記述を洗い出す（TS-7、REQ-014、BR-12）**

  - `grep -rnE 'pre-push|pre-commit|必須のチェック|lefthook|まとめ役|checks' AGENTS.md .claude/CLAUDE.md .claude/rules .claude/skills docs --include='*.md'` を実行し、出た所を読む
  - 新しいルールの 5 点と食い違う記述（例: 置き場所を速さで決めると書いている、lefthook を関門にすると書いている、CI で直すと書いている）があるかを、ファイルごとに確かめる。特に `docs/decisions/precommit-checks-by-target.md`・`.claude/rules/scripts-authoring.md`・`.claude/rules/hooks-authoring.md`・`.claude/skills/doc-gardening/SKILL.md` を読む
  - 食い違う記述は直さない。ファイル・行・中身・新しいルールのどの点と食い違うかを、計画の「### 知らせる物」と `record.md` に書く。無ければ「食い違う記述は無かった」と、確かめたファイルの一覧を書く

- [ ] **Step 10: 全体を確かめる**

  次をすべて実行し、結果を `record.md` に書く:

  - (AC-1) `sed -n '1,6p' .claude/rules/lefthook-ci-placement.md` の `paths` がちょうど `"lefthook.yml"`・`".lefthook/**"`・`".github/workflows/**"` の 3 行。`git diff origin/main -- .claude/rules/hooks-authoring.md` が空
  - (AC-2) ルールの本文に、BR-1（CI に入れ全体を必須、直さずに落とす）・BR-2（1 つのワークフロー、`checks` だけを必須）・BR-3（段は何を要るかで決める、4 つの段）・BR-4（意味を変えないと保証された直しだけ）・BR-5（片方を変えたら同じ PR でもう一方を確かめる）の 5 点があることを、1 点ずつ該当の行を引いて書く
  - (AC-3) Step 7 の最後の `grep` が frontmatter の 1 行だけ。本文が日本語
  - (AC-4) 計画の「### 比較テスト」に手順・定義とガードの確認の結果・判定がある。ノイズのときは 5 点が残り、食い違いが書かれている
  - (AC-5) 照合で、決まっている道具の変更後の段が一致する。一致しない物は、直した記録と残した理由がある
  - (AC-6) 計画の「### 知らせる物」に debride・Brakeman・Semgrep の分かれ方がある（PR の文案と bead の notes は Step 11）
  - (AC-7) 計画の「### 知らせる物」に今の設定とルールの食い違いがある
  - (AC-8) 比較テストの記録が計画にあり、ルールに無い（`grep -nE '比較テスト|Decision|rule-tester' .claude/rules/lefthook-ci-placement.md` が何も出さない）
  - (AC-9) `git diff origin/main -- lefthook.yml .lefthook .github/workflows` が空。`git status --porcelain` が Step 2 の 2 行だけ（ほかのファイルが変わっていない）
  - (AC-10) 計画に Step 9 の結果がある
  - そのほか: `git branch --show-current` が Step 1 で控えた元の HEAD の状態と同じ（ブランチはまだ作っていない）。`ls docs/design/plans/rule-test-fixture.md` が失敗する。`git stash list | grep lefthook-ci-placement-rule-cmm` が何も出さない。`git -C /home/ruby/tascon-backend branch --show-current` が `main`

- [ ] **Step 11: ブランチを作ってコミットし、記録を書き、push する**

  - 比較テスト（Step 7 のやり直しを含む）を全部終えたので、`git-spice-workflow` Skill に従ってブランチを作る（D2、`claude-md-maintenance` の手順 5）: `git-spice branch create docs/lefthook-ci-placement-rule --target main --no-commit`。ルールと計画の未追跡のファイルはそのまま持ち越す
  - 確かめる: `git branch --show-current` が `docs/lefthook-ci-placement-rule`。`git-spice ls` で親が `main`。`git status --porcelain` が Step 2 の 2 行
  - `git-spice-workflow` Skill に従い、2 ファイルだけをステージしてコミットする（`git add .claude/rules/lefthook-ci-placement.md docs/design/plans/active/lefthook-ci-placement-rule.md` の後に `git-spice commit create -m ...`）。メッセージ（英語）:

    ```text
    docs: add a rule for placing checks in lefthook and CI

    There was no rule for deciding whether a check belongs in a lefthook
    stage or in CI, so changes to the hooks or the workflows picked a place
    by speed or habit. The new rule, read when lefthook.yml, .lefthook/ or
    .github/workflows/ is touched, says that checks of the content run in
    CI over the whole repository and fail without fixing, that the required
    checks sit in one workflow with only its aggregate job "checks" made
    required, that the lefthook stage follows what a check needs, that
    lefthook only applies fixes that keep the meaning, and that a change to
    one side is checked against the other in the same pull request. The
    plan records the before-and-after test and the current settings that
    differ from the rule.
    ```

    日本語訳（`record.md` に並べて書く）: 「docs: lefthook と CI への確かめの置き場所のルールを足す／確かめを lefthook の段に置くか CI に置くかを決めるルールが無く、フックやワークフローを変えるときに速さや慣習で置き場所を選んでいた。新しいルールは、lefthook.yml・.lefthook/・.github/workflows/ を触るときに読まれ、中身の確かめは CI でリポジトリ全体に対して走らせて直さずに落とすこと、必須の確かめは 1 つのワークフローに置いてまとめ役のジョブ "checks" だけを必須にすること、lefthook の段は確かめが何を要るかで決めること、lefthook では意味を変えない直しだけを行うこと、片方を変えたら同じ PR でもう一方を確かめることを書く。計画には、入れる前と後のテストと、ルールと違う今の設定を記録する。」
  - pre-commit が通ること（`--no-verify` を使わない）。`check-docs.sh`・`check-plan-completion.sh`・`check-links.sh` が走る。落ちたら出力を読んで計画の書式を直し、もう一度コミットする（ルールの文は Step 7 の結果から変えない）
  - `git status --porcelain` が空
  - `record.md` に次を書く:
    - 変えたファイル、コミットの SHA・英文のメッセージ・日本語訳
    - Step 1・Step 10 の確認の結果、比較テストの判定と照合の表、直した文
    - PR の文案（英語。後段が PR を開くときに使う）:
      - Title: `docs: add a rule for placing checks in lefthook and CI`
      - Summary / Changes: ルールの 5 点と `paths`、計画のファイル
      - Testing: 比較テストの場面（プロンプトの要約と、全文は計画にあること）、期待する行動、変更前・変更後の違い、照合の結果、直した文、判定（ノイズのときは 5 点を残したことと `claude-md-maintenance` の手順 6 との食い違い）、Step 10 の機械的な確認
      - Notes: debride・Brakeman・Semgrep の分かれ方、直らずに残った食い違い、今の設定とルールの食い違い（直していない）、重なる記述の確かめの結果
      - Related Issues: `N/A`
      - Related Documents: `- ✅ Plan: docs/design/plans/active/lefthook-ci-placement-rule.md`、`- Spec: N/A`
  - bead の notes（D12）: 実装の bead と `tb-z3r00` に、`gc bd update <id> --append-notes '<日本語の要約>'` で、判定、debride・Brakeman・Semgrep の分かれ方、直らずに残った食い違い、今の設定とルールの食い違い、`record.md` のパスを書く（閉じない）
  - push: `git push -u origin docs/lefthook-ci-placement-rule`（`git-spice branch submit` は PR を作るので使わない）。pre-push の `check-git-clean` が通ること
  - PR は作らない

### タスクと要求の対応

| 要求 | Task 1 の Step |
| --- | --- |
| REQ-001 | Step 2、Step 10（AC-1） |
| REQ-002〜REQ-006 | Step 2、Step 7（意味を保つ直し）、Step 10（AC-2） |
| REQ-007 | Step 2、Step 7 の最後の `grep`、Step 10（AC-3） |
| REQ-008 | Step 3〜Step 7、Step 10（AC-4） |
| REQ-009 | Step 7、Step 8、Step 10（AC-5） |
| REQ-010 | Step 8、Step 11（PR の文案・bead の notes）、Step 10（AC-6） |
| REQ-011 | Step 8、Step 10（AC-7） |
| REQ-012 | Step 2、Step 8、Step 11、Step 10（AC-8） |
| REQ-013 | Step 10（AC-9） |
| REQ-014 | Step 9、Step 10（AC-10） |

## Non-Goals

- `lefthook.yml`・`.lefthook/**`・`.github/workflows/**` の中身の変更（食い違っても直さず知らせる）
- `ci.yml` をジョブに分けて `checks` をまとめ役にする組み替え（人が別に行う）
- GitHub の必須チェックの登録（人が行う）
- dev-workflow-shared から配る段、frontend のリポジトリの変更
- `hooks-authoring.md`・`scripts-authoring.md` ほか、重なる記述の変更（洗い出して知らせるだけ）
- 直らない食い違いについて、基準を変えるか置き場所を変えるかを決めること（人が決める）
- PR を開くこと（この build は `open_pr=false`。push まで）

## Validation and Acceptance

- Task 1 の Step 10 の確認（AC-1〜AC-10 に 1 つずつ対応）を実装者が実行し、`record.md` に結果を書く
- 比較テストの証拠: `/home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/comparison-test/` の `prompt-*.txt`・`*.jsonl`・`*.answer.md`・`record.md`
- pre-commit（`check-docs.sh`・`check-plan-completion.sh`・`check-links.sh`）と pre-push（`check-git-clean`）を `--no-verify` なしで通す
- 後段の review が見る所: ルールが依頼の 5 点の意味を保っているか、具体例・理由・道具の名前が無いか、比較テストの手順（退避の名前・detach・定義の確認・同じプロンプト）が守られたか、判定と知らせる物が計画・PR の文案・bead の notes にそろっているか

## Open Questions

- 人の答えが要る問いは無い。曖昧な所は「前提」A1〜A8 で進める
- build の中で決めずに残す物: 直らない食い違いの扱い（基準を変えるか置き場所を変えるか）と、判定がノイズになったときに 5 点を残すか取り消すか。build の中では 5 点を残して知らせる（D7・D8）

## Coverage

| ID | Status | 計画での扱い |
| --- | --- | --- |
| REQ-001 | covered | Task 1 Step 2・Step 10 |
| REQ-002 | covered | Task 1 Step 2・Step 7・Step 10 |
| REQ-003 | covered | Task 1 Step 2・Step 7・Step 10 |
| REQ-004 | covered | Task 1 Step 2・Step 7・Step 10 |
| REQ-005 | covered | Task 1 Step 2・Step 7・Step 10 |
| REQ-006 | covered | Task 1 Step 2・Step 7・Step 10 |
| REQ-007 | covered | Task 1 Step 2・Step 7・Step 10 |
| REQ-008 | covered | Task 1 Step 3〜Step 7 |
| REQ-009 | covered | Task 1 Step 7・Step 8 |
| REQ-010 | covered | Task 1 Step 8・Step 11 |
| REQ-011 | covered | Task 1 Step 8 |
| REQ-012 | covered | Task 1 Step 2・Step 8・Step 11 |
| REQ-013 | covered | Task 1 Step 10 |
| REQ-014 | covered | Task 1 Step 9 |

## Decision Log

- 2026-11-19: plan-review で計画を承認。正式な plan/spec を保存する方針を採用。保存しない旨の旧記述はこの決定で変更。出典: /home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/requirements.md, /home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/brainstorming/design.md, /home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/implementation-plan.md。
- 2026-11-20: 実装の時点で、作業の枝 `docs/lefthook-ci-placement-rule` に、承認済みの計画と設計を保存したコミット（`963f5d90`）が既にあった。Task 1 の Step 2 は計画のファイルを新規に作るとしていたが、この保存済みの計画をそのまま使い、比較テストの結果と知らせる物はこの Decision Log に足した。Step 11 の「ブランチを作る」は行わず、既にある枝にコミットを 1 つ足した（比較テストは、計画を含むコミットの 1 つ前である `origin/main` へ detach して行ったので、計画・設計は変更前にも変更後にも見えていない）。

### 比較テスト

- 期待する行動（1 点）: 道具の置き場所を、速さでなく確かめに要る物（変えたファイルだけ／プロジェクト全体／ビルド・サーバー・ブラウザ・DB・テストの繰り返し／手元の状態）で決め、決まっている道具では照らす表の段と一致させる
- 手順: `claude-md-maintenance` の必須手順を、Gas City の取り決めで読み替えた。`rule-tester` は作業の worktree で起動した headless Claude の中で起動した（`claude -p ... --allowedTools "Agent Skill Read Grep Glob"`、1 回ごとに新しい Claude）。変更前・変更後とも土台のコミット `0f60f4ad`（`origin/main`）へ detach して行い、変更内容を表す枝名と、計画・設計のファイルが見えないようにした。計画と設計を含むコミット（`963f5d90`）があるので手順 3 は適用され、その 1 つ前の `0f60f4ad` へ detach した。`0f60f4ad` と `963f5d90` で `.claude/agents/rule-tester.md`・`.claude/hooks/rule-tester-guard.sh` は同じ（`git diff --stat 0f60f4ad 963f5d90 -- .claude/agents .claude/hooks` が空）なので、定義とガードの置き直しは要らなかった。元の HEAD の状態は枝 `docs/lefthook-ci-placement-rule`。変更前と最初の変更後（r0）は、ルールを名前付きの stash に入れて戻した。直した後のやり直し（r1・r2）は、計画の変更を名前付きの stash（`lefthook-ci-placement-rule-cmm-other-2`）に退避し、ルールは作業ツリーに置いたまま detach して行い、終えて枝へ戻して stash を名前で戻した
- 定義とガードの確認: `rule-tester` の定義の指示文 5 行を引用させ、Current System の定義と一致した。`claude-md-maintenance.md` の Read は、`rule-tester` が定義の 3 つ目の指示に従って自分で Read せず、ガードの拒否の文は出なかった（ガードの拒否そのものは確かめていない）。定義が今の版で動いていることは引用で確かめた
- プロンプトの全文（変更前・変更後で同じ）:

  ```text
  .github/workflows/semantic-pull-request.yml を読んでから答えて。

  backend（このリポジトリ、Rails）と frontend（別のリポジトリ、Next.js）の確かめの置き場所を、lefthook の段と CI について白紙から見直している。今の lefthook.yml と、semantic-pull-request.yml 以外の .github/workflows/ のファイルは、今の置き場所を写さないために読まないで（.lefthook/ の下のスクリプトの中身は読んでよい）。

  下の道具ごとに、次の 4 つを答えて。
  - 段: pre-commit・pre-push・CI だけ・手元だけ のどれか 1 つ（lefthook と CI の両方に置くなら lefthook の段を書く）
  - CI: CI に入れるか。入れるなら、マージの前に通っていないといけない必須のチェックにするか
  - 直し: lefthook で走らせるときにファイルを直してよいか
  - 根拠: その段・CI・直しにした理由と、根拠にしたファイル

  答えは、道具の ID ごとに 1 行（「ID 名前: 段 / CI / 直し / 根拠」）で書いて。

  backend
  - B1 rubocop: `bin/bundle exec rubocop`（直すオプション `--autocorrect` がある）
  - B2 htmlbeautifier: `bin/bundle exec htmlbeautifier <erb のファイル>`（渡したファイルを書き換える。`--lint-only` を付けると書き換えずに確かめだけする）
  - B3 debride: `bin/bundle exec debride --rails -w debride-whitelist.txt <rb のファイル>`
  - B4 protect-branch: `git branch --show-current | grep -Eqvx 'main'`
  - B5 check-docs.sh: `bash .lefthook/pre-commit/check-docs.sh`
  - B6 check-plan-completion.sh: `bash .lefthook/pre-commit/check-plan-completion.sh`
  - B7 check-links.sh: `bash .lefthook/pre-commit/check-links.sh`
  - B8 pre-commit check tests: `bash .lefthook/pre-commit/tests/run.sh`
  - B9 plan-completion script tests: `bash .claude/skills/plan-completion/scripts/tests/run.sh`
  - B10 check-git-clean: `test -z "$(git status --porcelain)"`
  - B11 rspec: `bin/bundle exec rspec`
  - B12 Validate PR title: semantic-pull-request.yml の job
  - B13 Related Documents の確かめ: `bash .claude/skills/plan-completion/scripts/check-pr-body.sh --body-file <PR の本文>`
  - B14 SimpleCov: rspec の中でテストのカバレッジの率を書き出す（合否は返さない）
  - B15 Brakeman: `bin/bundle exec brakeman --no-pager`
  - B16 Semgrep: `semgrep scan --config <Rails の規則> --metrics=off --error`
  - B17 CodeQL（Ruby）: `github/codeql-action/init` と `github/codeql-action/analyze`
  - B18 Dependency Review: `actions/dependency-review-action`
  - B19 code-review-graph: `code-review-graph build` の後に `code-review-graph detect-changes --base <PR の土台の枝>` で報告を書く（合否は返さない）
  - B20 PR の言語の確かめ: PR のタイトルと本文に日本語の文字があれば落とす

  frontend
  - F1 biome: `yarn biome check --error-on-warnings <ファイル>`（直すオプション `--write` がある）
  - F2 markuplint: `yarn markuplint <ファイル>`（直すオプション `--fix` がある）
  - F3 markdownlint: `yarn markdownlint-cli2 <ファイル>`
  - F4 check-logger-trace: `grep -nFH 'logger.trace' <src のファイル>` で見つかれば落とす
  - F5 protect-branch: `git branch --show-current | grep -Eqvx 'main'`
  - F6 check-docs.sh: `bash .lefthook/pre-commit/check-docs.sh`
  - F7 knip: `yarn knip`
  - F8 型の確かめ: `yarn next typegen && yarn tsc --noEmit`
  - F9 next build: `yarn next build`
  - F10 check-git-clean: `test -z "$(git status --porcelain)"`
  - F11 semantic-pull-request: PR のタイトルの形を確かめる GitHub Actions の job
  - F12 Vitest: `yarn vitest run`（全部のテスト）と `yarn vitest related <ファイル>`（変えたファイルに関係するテストだけ）
  - F13 Playwright: `yarn playwright test`
  - F14 Stryker: `yarn stryker run`
  ```

- 照らした結果（道具 / 決まった段 / 変更前 / 変更後 / 一致）。変更後の列は、B15・B16 以外は最初の文（r0）の答えで、採用した文（r2）の答えと段が同じ。B15・B16 だけ r2 で段が変わったので、行に r2 を併記した。変更前の根拠は多くが「重い」「速い」「道具の性質」「慣習・過去の決定（`precommit-checks-by-target.md` など）」、変更後の根拠は「変えたファイルだけで確かめられる」「プロジェクト全体は要るがビルド・DB は要らない」「DB が要る」「テストを何度も走らせる」「手元の状態を見る」で、ルールの基準の言い方に沿っていた。変更前に段が食い違った B4・B10・B11・F5・F10 は、変更後に一致した
  - B1 rubocop / pre-commit＋CI・直す / 前: pre-commit・直す / 後: pre-commit・直す / 一致
  - B2 htmlbeautifier / pre-commit＋CI・直す / 前: pre-commit・直す / 後: pre-commit・直さない（意味が変わりうるとして `--lint-only` のみ） / 段は一致、直しは不一致
  - B3 debride / 決まっていない / 前: CI だけ・必須にしない・直さない / 後: pre-push・CI 必須・直さない
  - B4 protect-branch / 手元だけ / 前: pre-commit / 後: 手元だけ / 前は不一致、後は一致
  - B5 check-docs.sh / pre-commit＋CI / 前: pre-commit / 後: pre-push（ディレクトリを丸ごと走査するため） / 後は不一致
  - B6 check-plan-completion.sh / pre-commit＋CI / 前: pre-commit・CI しない / 後: pre-commit・CI 必須（今のままでは CI で意味がないと指摘） / 一致
  - B7 check-links.sh / pre-commit（CI に無い）/ 前: pre-commit・CI しない / 後: pre-commit・CI 必須（全体を見る形が要ると指摘） / 一致
  - B8 pre-commit check tests / pre-commit＋CI / 前: pre-commit / 後: CI だけ（テストを何度も走らせる物） / 後は不一致
  - B9 plan-completion script tests / pre-commit＋CI / 前: pre-commit / 後: CI だけ / 後は不一致
  - B10 check-git-clean / 手元だけ / 前: CI だけ / 後: 手元だけ / 前は不一致、後は一致
  - B11 rspec / CI だけ / 前: pre-push / 後: CI だけ（DB が要る・テストを何度も） / 前は不一致、後は一致
  - B12 Validate PR title・B13 Related Documents・B18 Dependency Review・B20 PR の言語 / CI だけ / 前後とも CI だけ・必須 / 一致（B12・B13・B20 の後の根拠は PR が要るため）
  - B14 SimpleCov・B19 code-review-graph / CI だけ（報告） / 前後とも必須にしない / 一致
  - B15 Brakeman・B16 Semgrep / 決まっていない / 前: CI だけ・必須・直さない / 後（r0）: CI だけ・必須・直さない（手元に入れていない道具は使わないとして） / 後（r2、採用した文）: B15 は pre-push・CI 必須・直さない、B16 は pre-commit・CI 必須・直さない
  - B17 CodeQL / CI だけ（別のワークフロー） / 前: CI だけ・必須にしない / 後: CI だけ・必須（`checks` のワークフローの中のジョブとして） / 段は一致
  - F1 biome / pre-commit＋CI・直す / 前後とも pre-commit・直す（後は `--unsafe` を使わない） / 一致
  - F2 markuplint / pre-commit＋CI・直さない / 前: pre-commit・直す / 後: pre-commit・直さない / 前は直しが不一致、後は一致
  - F3 markdownlint・F4 check-logger-trace / pre-commit / 前後とも pre-commit・直さない / 一致
  - F5 protect-branch / 手元だけ / 前: pre-commit / 後: 手元だけ / 後は一致
  - F6 check-docs.sh / pre-commit / 前: pre-commit / 後: pre-push / 後は不一致
  - F7 knip・F8 型の確かめ / pre-push＋CI / 前後とも pre-push・CI 必須 / 一致
  - F9 next build・F13 Playwright / CI だけ / 前後とも CI だけ / 一致
  - F10 check-git-clean / 手元だけ / 前: CI だけ / 後: 手元だけ / 後は一致
  - F11 semantic-pull-request / CI だけ / 前後とも CI だけ / 一致
  - F12 Vitest / CI だけ（関係するテストだけ pre-push） / 前: pre-push（全部）/ 後: 関係するテストだけ pre-commit・全部は CI（pre-commit に置くかは微妙と書いた） / 後は関係するテストの段が不一致
  - F14 Stryker / CI だけ / 前: CI だけ・必須にしない（定期か手動） / 後: CI だけ・必須（閾値を設定する前提） / 段は一致
- 判定: 期待する行動は、変更前に無く変更後にある。変更前は「重い」「速い」で置き場所を決め、決まっている道具の段が B4・B10・B11・F5・F10・F12 などでずれた。変更後は確かめに要る物で決め、手元だけの道具・CI だけの道具・pre-push の道具を、ルールの基準の言い方で分けた。変更前でも段が一致した道具（B1・B6・B7・F1 など）は、根拠を見て判定した
- 直した文（2 回。どちらも例・理由・道具の名前を足しておらず、BR-3 の 4 つの段と BR-1〜BR-5 の意味を保つ）。変更後の最初の答え（r0）で段が決まった段と食い違った道具は B5・F6・B8・B9。F12 は前提 A6 のとおり「全部のテスト＝CI だけ」で照らして一致（関係するテストだけを pre-commit とした答えは記録のみ）、B2 は段が一致で直しの判断だけを知らせる
  - r0 の文（`comparison-test/rule-r0.md`）: 「CIだけ: ビルド・サーバー・ブラウザ・DBが要る物、またはテストを何度も走らせる物」
  - r1（`02-after-r1.jsonl`）: 「またはテストを、条件を変えて何度も走らせる物」へ。B8・B9 が「テストを何度も走らせる物」と読まれて CI だけになったのは、テストの集まりを 1 回走らせる物と読み違えた可能性があったため、対象を絞った。結果: B8・B9 は pre-push になり（CI だけにも pre-commit にもならず）、B7（check-links.sh）が pre-commit から pre-push、F12 の全部のテストが CI だけから pre-push に、一致が減った。この文は採らない
  - r2（`02-after-r2.jsonl`、現在のルールの文）: 「ビルド・サーバー・ブラウザ・DBが要る物、またはテスト全体を走らせる物、テストを条件を変えて何度も走らせる物」へ。依頼の「Vitest の全部のテストは CI だけ」を、道具の名前なしで基準の言い方にした明確化。結果: B7・F12 は r0 と同じ一致に戻り、段の食い違いは B5・F6・B8・B9 の 4 つ（r0 と同じ道具）。直し前後で一致する道具の数は変わらない。r2 を採った理由は、F12 の答えの根拠が「テスト全体を走らせる」と基準の文に沿うようになったこと。判定は直した後の文で行っても「変更前に無く変更後にある」で変わらない
  - 3 回目は行わなかった。残る 4 つは、文の言い方では解けない（下の「知らせる物」）
- B5・F6 は、直す対象にせず今の設定の側の食い違い（BR-10）として扱った。根拠: `check-docs.sh` は `find` でディレクトリ全体を走査し、基準の「プロジェクト全体は要る」（pre-push）に当たる。pre-commit にするには基準の 3 つ目の区分「変えたファイルだけで確かめられる物」の意味を変える必要があり、意味を変えない直しでは解けない
- B8・B9 は、「テスト全体を走らせる物は CI だけ」とする依頼の趣旨（Vitest の全部のテストは CI だけ）と、決まった段（対象が変わるときだけ pre-commit で走らせる `docs/decisions/precommit-checks-by-target.md` の決定）が食い違う。文を変えるとどちらかの意味が変わるので、直さずに残した
- 5 点は取り消さず残した（判定はノイズではないので、`claude-md-maintenance` の手順 6 との食い違いは起きていない）

### 知らせる物

- debride・Brakeman・Semgrep の分かれ方（直した後の最終の文 r2 の答え。括弧内は直す前 r0 の答え）
  - debride: pre-push・CI に入れて必須・lefthook では直さない（r0 も同じ）。根拠は、使われていないメソッドの判定はプロジェクト全体が要り、ビルド・DB は要らないため。今は pre-commit の全ファイル対象
  - Brakeman: pre-push・CI 必須・直さない（r0: CI だけ・必須）。根拠は、ファイルをまたぐ静的解析でプロジェクト全体が要り、ビルド・サーバー・DB は要らないため（r0 は、手元の環境に入れていない道具は lefthook に置かないという既存のルール `scripts-authoring.md` を根拠にした）
  - Semgrep: pre-commit・CI 必須（全体対象）・直さない（r0: CI だけ・必須）。根拠は、規則をファイル単位で当てるので変えたファイルだけで確かめられるため（ただし規則をネットワーク越しに取るなら CI だけに寄せるとも答えた）
  - 3 つとも、答えは実行ごとに変わり、基準の文だけでは「pre-commit・pre-push・CI だけ」のどれか（道具の入れ方や規則の取り方）が決まらない。どれにするかは人が決める
- 直らずに残った食い違い（決まった段 / ルールでの段 / 残した理由）。基準を変えるか置き場所を変えるかは人が決める
  - B5・F6 check-docs.sh: pre-commit / pre-push / ディレクトリ全体を走査するため、基準では pre-push になる
  - B8・B9 チェックのスクリプトのテスト: pre-commit / CI だけ（r2 の文で。r0 も同じ） / テスト全体を走らせる物なので、基準では CI だけになる。`docs/decisions/precommit-checks-by-target.md` の決定（対象が変わるときに pre-commit で実行）とも食い違う。r1 の文では pre-push になった
  - F12 Vitest の関係するテストだけ: pre-push / pre-commit（r0 と r2 の答え。微妙と答えた） / 関係を調べるのにプロジェクトの import 関係を見るため、基準の 3 つの段のどれにも当てはまりにくい。照合は A6 により全部のテスト（CI だけ）で見て、一致している
  - B2 htmlbeautifier の lefthook での書き換え: 今は直す。変更後の答えは、HTML は空白で意味が変わりうるので「意味を変えないと保証された直し」に当たらず、直さないと判断した
- 今の設定とルールの食い違い（設定は直していない）
  - backend の `check-links.sh` が CI に無い（変更後の答えは CI に入れて必須にすべきとした）
  - frontend の markdownlint・check-logger-trace・`check-docs.sh` が CI に無い（変更後の答えは CI に入れて必須とした）
  - CodeQL が、必須の確かめを置く 1 つのワークフローの外（別のワークフロー）にある（変更後の答えは `checks` のワークフローの中のジョブとしていた）
  - `check-plan-completion.sh` は CI で意味を持つか（今の CI の `checks` ジョブには入っている。変更後の答えは、index と HEAD の差を読むので今の形では CI で意味がないとした）
- 重なる記述の確かめ（`grep -rnE 'pre-push|pre-commit|必須のチェック|lefthook|まとめ役|checks' AGENTS.md .claude/CLAUDE.md .claude/rules .claude/skills docs --include='*.md'`）。直していない
  - `docs/decisions/precommit-checks-by-target.md`: テストは対象が変わるときだけ pre-commit で実行する。新しいルールの「テストを何度も走らせる物は CI だけ」と食い違う
  - `docs/decisions/pr-body-related-documents-ci-check.md`: Related Documents の確かめを必須のチェックにしない。新しいルールの「中身を確かめる必須のチェックは `checks` の 1 つのワークフロー」と、PR の確かめを必須にするかの扱いが合わない
  - `docs/decisions/reminder-hooks-removal.md`: `check-docs.sh` を pre-commit で実行する。新しいルールでは pre-push になりうる
  - `.claude/rules/scripts-authoring.md`・`.claude/rules/code-comments.md`: `paths` が新しいルールと重なる（食い違う記述は無い）
  - `.claude/rules/hooks-authoring.md`: 「違反の検出は pre-commit に任せる」。食い違いは無い
  - `.claude/skills/doc-gardening/SKILL.md`・`.claude/skills/plan-completion/SKILL.md`・`docs/decisions/plan-branch-mapping-in-git-config.md`・`plan-completion-by-pr-markers.md`・`commit-message-check-scope.md`: lefthook・CI の置き場所に言及するが、新しいルールの 5 点と食い違う記述は無かった
