# Mutant を報告だけで入れる Implementation Plan

Spec: docs/design/specs/mutant-mutation-testing.md

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (this Gas City lane does not use provider-native subagents). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tascon-backend の PR ごとの CI に、PR が変えた `app/` の subject だけへ Mutant 0.17.1 を走らせて結果を Step Summary に書くだけ（合否を返さない）のワークフロー `mutant`（job `report`）を足し、手元でも同じ設定で走らせられるようにし、理由を決定の記録に残す。

**Architecture:** `mutant-rspec` を `Gemfile` の `group :test` に足し、設定を `config/mutant.yml`（`context_map`・`jobs: 1`・`usage: opensource`）と `config/mutant/hooks.rb`（eager load）に置く。SimpleCov の `track_tests` で test ごとのカバレッジを `coverage/coverage.json` に記録し、Mutant はそれでテストを選ぶ。CI は `ci.yml` の外の新しいワークフロー `.github/workflows/mutant.yml` の 1 job の中で、`COVERAGE` 付きの rspec → 変えた subject を数える → `mutant run --since origin/<base>` → session を Step Summary に書く、の順に走らせ、session ができなかったときだけ落ちる。変更は `ci/add-code-review-graph-report`（PR #840）の上の 1 段の git-spice のブランチ `ci/add-mutant-report` に積む。

**Tech Stack:** Ruby 4.0.0 / Rails 8.1.3 / RSpec（rspec-core 3.13.6）、SimpleCov 1.3.2、Mutant 0.17.1 と mutant-rspec 0.17.1、MySQL 8.4.8、GitHub Actions、git-spice。

---

## Context/Purpose

- 依頼 gc-xtys の tascon-backend の分（部分 tb-yxpiz）の承認済み要件 `/home/ruby/tascon-backend/.gc-artifacts/mutant-mutation-testing/requirements.md`（REQ-001〜REQ-010、AC-1〜AC-10）を、1 つの実装タスク（Task 1）にまとめる
  - 要件は 1 本のブランチ・1 本の PR（REQ-010）で、ファイルどうしが互いに依存する（ワークフローは設定と `track_tests` が無いと動かない、決定の記録は確かめた事実を書く）。タスクを分けると同じブランチを複数の実装の lane が順に触ることになるため、1 タスクの中でコミットを分ける
- Task 1 のコミットは 5 つ（依存 → `track_tests` → Mutant の設定 → ワークフロー → 決定の記録）。各コミットの前にその部分の確かめを走らせる
- PR を開くことと、PR の上でしか確かめられない条件（AC-6・AC-10 と、AC-7 の PR 上の確かめ方）は、この build のタスクではない。workflow root の `gc.var.open_pr=false` のため、「Verification」の「PR を出す作業の引き継ぎ」に PR の題名・本文の案と確かめの手順を置き、実装の lane はそれを implementation summary に写す（REQ-010）

## Current System

計画の作成時（2026-11-20、積む先 `origin/ci/add-code-review-graph-report` = `b375ab11ea86aa1a0be740ee6bf1e99a8fd7c8c1`）に確かめた事実:

- 積む先のスタック: `ci/add-code-review-graph-report`（PR #840、base `ci/add-dependency-review`）。PR #840 の本文の Related Documents は `- ✅ Plan: docs/design/plans/active/test-and-check-tools-ci.md` と `- Spec: N/A`
- `.github/workflows/` は `ci.yml`・`code-review-graph.yml`・`codeql.yml`・`related-documents.yml`・`semantic-pull-request.yml`
- `ci.yml` の job `rspec`: `runs-on: ubuntu-latest`、`container: ruby:4.0.0`、service `db`（`mysql:8.4.8`、env `MYSQL_ROOT_PASSWORD: ci_root_password`・`MYSQL_USER: ci_user`・`MYSQL_PASSWORD: ci_password`・`MYSQL_DATABASE: tascon_test`、`--health-cmd "mysqladmin ping -h 127.0.0.1 -uroot -pci_root_password"` ほか）。job の env は `RAILS_ENV: test`・`TZ: Asia/Tokyo`・`CI: "true"`・`MYSQL_USER`・`MYSQL_PASSWORD`・`MYSQL_DATABASE`・`MYSQL_TEST_DATABASE: tascon_test`・`WEB_HOST: localhost`・`WEB_PORT: "8080"`・`RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}`・`COVERAGE: "true"`。手順は libvips → checkout（タグ参照 `actions/checkout@v7`）→ cache（`actions/cache@v6`、key `gems-ruby-4.0.0-${{ runner.os }}-${{ hashFiles('Gemfile.lock') }}`）→ `bundle install --jobs 4` → `bin/rails db:prepare` → `bin/bundle exec rspec` → `coverage/.last_run.json` の率を Step Summary に書く
- `ci.yml` の job `brakeman` は `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` と `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0`。job `checks` は `git config --global --add safe.directory "$GITHUB_WORKSPACE"` を持ち、rubocop・htmlbeautifier・debride（`git ls-files -z '*.rb'` の全ファイル）・`check-docs.sh`・`.lefthook/pre-commit/tests/run.sh`・`.claude/skills/plan-completion/scripts/tests/run.sh`・`check-plan-completion.sh` を走らせる
- `code-review-graph.yml`: ワークフロー名 `code-review-graph`、job `report`（`name: report`）、`env: BASE_REF: ${{ github.base_ref }}`、base の fetch は `git fetch --no-tags --depth=1 origin "+refs/heads/${BASE_REF}:refs/remotes/origin/${BASE_REF}"`、解析が走らなかったときだけ `::error::` を出して落ちる。`timeout-minutes` は無い
- `Gemfile`: `group :test` に `gem "simplecov", "~> 1.3", require: false` だけがある。`Gemfile.lock` は parser 3.3.11.1、rspec-core 3.13.6、simplecov 1.3.2、diff-lcs 1.6.2、irb 1.17.0、regexp_parser 2.12.0、PLATFORMS は `aarch64-linux`・`arm64-darwin-24`・`arm64-darwin-25`・`x86_64-linux`、BUNDLED WITH 2.6.9
- `spec/spec_helper.rb` の先頭:

  ```ruby
  if ENV["COVERAGE"]
    require "simplecov"
    # TEST_ENV_NUMBER is only a test DB suffix here, not a parallel run;
    # without this, SimpleCov skips the report when its value is not 1.
    SimpleCov.parallel_tests = false
    SimpleCov.start "rails"
  end
  ```

- `.gitignore` の最後は `# SimpleCov` と `/coverage/`。`.mutant` の行は無い
- `config/environments/test.rb:27` は `config.eager_load = ENV["CI"].present?`（CI では eager load、手元では lazy）
- spec は 7 ファイル（`spec/models/contact_spec.rb` と `spec/requests/api/v1/` の 6 ファイル）。controller の spec は無く、controller を通るのは request spec だけ
- `docs/decisions/` は 18 件と `index.md`。`index.md` の最後の行は `- CIのチェックを合否を返す物と報告だけの物に分ける (`ci-required-and-report-only-checks.md`)`。既存の決定の記録は日本語と英字・バッククォートの間に空白を入れない書き方（例「job`rspec`のStep Summary」）
- `.claude/rules/decisions-maintenance.md`: 見出し `# <題>`、`Status`・`Verification Status`・`Date`・`Related Files` の 4 行、`## Context`・`## Decision`・`## Considered Options`（各案の長所・短所）・`## Consequences`、日本語
- `.claude/rules/code-comments.md`: `app/**`・`config/**`・`spec/**` ほかのコメントは英語
- リポジトリは PUBLIC で LICENSE は無い（`gh repo view --json visibility,licenseInfo` → `PUBLIC`、`null`）
- Mutant 0.17.1 の gem（`gem fetch mutant -v 0.17.1`・`mutant-rspec -v 0.17.1` を一時ディレクトリに展開して読んだ）:
  - 依存: `diff-lcs >= 1.6, < 3`、`irb ~> 1.15`、`parser ~> 3.3.10`、`regexp_parser ~> 2.10`、`securerandom >= 0.3`、`sorbet-runtime ~> 0.6.0`、`unparser >= 0.8.2, < 0.10`。`required_ruby_version >= 3.3`。`mutant-rspec` は `mutant = 0.17.1` と `rspec-core >= 3.8.0, < 5.0.0`。今の lock の parser・diff-lcs・irb・regexp_parser と両立する
  - 設定ファイルは `.mutant.yml`・`config/mutant.yml`・`mutant.yml` の順に探す（`lib/mutant/config.rb`）
  - 設定のキー（`Config::TRANSFORMS`）: `coverage_criteria`・`environment_variables`（値は文字列だけ）・`fail_fast`・`hooks`・`includes`・`integration`・`jobs`・`matcher`・`mutation`・`requires`・`selection`・`usage`。`mutation` は `ignore_patterns`・`operators`・`timeout`。`matcher` は `subjects`・`ignore`。`selection` は `path`・`strategy`（`auto`・`expression`・`context_map`）。`mutation_timeout` は非推奨の別名で警告を出す
  - `source:<glob>` の式がある（`lib/mutant/expression/source.rb`、`/\Asource:(?<glob_expression>.+)\z/`）
  - `context_map` は既定で `coverage/coverage.json` を読む（`Selection::DEFAULT_PATH = 'coverage'`、`ContextMap::ARTIFACT_BASENAME = 'coverage.json'`）。読むのはトップの `contexts`（test の ID の配列）と `meta.schema_version`（`1.` で始まる物）、ファイルごとの `contexts`。記録が無いと「Test selection strategy `context_map` needs a per test coverage recording」と案内して失敗する
  - hooks のファイルは `hooks` というローカル変数のある binding で eval され、`hooks.register(:env_infection_post) { ... }` の形で登録する。block は `env:` の keyword で呼ばれる（`bootstrap.rb:184`）。引数を書かない block は keyword を無視する（`proc { 1 }.call(env: 2)` は 1 を返すことを確かめた）
  - `mutant environment subject list` は 1 行目に `Subjects in environment: %d`、続けて subject の式を 1 行ずつ出す。`--since REVISION` は `git diff-index <REVISION>` で作業ツリーとの差を見る（merge-base は使わない）
  - `mutant environment show` は `Usage:           opensource`・`Integration:     rspec`（integration の名前）・`Jobs:            1`・`MutationTimeout: 120`・`Selection:       context_map` の形の行を出す
  - session は `mutation/runner.rb` の解析の最後に `.mutant/results/<SESSION_ID>.json.gz` へ書かれる（一時ファイル `.json.gz.tmp` から rename）。生き残りがあっても書かれ、bootstrap が失敗したときは書かれない
  - `mutant session subject` は `ALIVE  TOTAL  SUBJECT` の表を出す。`mutant session show` は `Subjects:`・`Alive:` と、生き残ったミューテーションの diff（`AliveResults`）を出す。どちらも既定で最新の session を読む。したがって要件の「生き残りの diff を出すコマンドが 0.17.1 にあるか」は「ある」で解決し、diff を出せないことを決定の記録に書く分岐は使わない
- 時間: 設計の調べでは #840 の CI の job `rspec` の `COVERAGE=true` の rspec は 95 秒（REQ-005 の「100 秒を超えたら」に当たらない）

## Proposed Implementation

### 全体の進め方（lifecycle との関係）

この計画の Task 1 は、build の formula（`superpowers-build`）の implement の段で 1 つの実装の bead になる。計画の review、分解、実装の review、最終の報告、push は formula の別の段が受け持つので、タスクには書かない。

- 作業の場所: 実装の lane の worktree。main checkout（`/home/ruby/tascon-backend`）のブランチは切り替えない
- ブランチ: リポジトリの `git-spice-workflow` Skill に従い、`ci/add-code-review-graph-report` の上に `ci/add-mutant-report` を作る（`gh stack` は使わない）
- コミット: 英語の Conventional Commits、1 コミット 1 主題。lefthook の pre-commit が走る。rubocop の `--autocorrect` などが直したら、その差分を確かめてコミットに含める
- 手元の確かめ: 開発コンテナの MySQL の test の DB を使う（前の build で `RAILS_ENV=test bin/bundle exec rspec` が手元で通っている）。一時ファイルは `mktemp -d` の下に置き、リポジトリに置かない
- リポジトリの計画ファイル（`.claude/plans/active/`）は作らない（「Open Questions」の仮定）

### Task 1: Mutant の依存・設定・報告だけのワークフロー・決定の記録（ブランチ `ci/add-mutant-report`）

**Files:**
- Modify: `Gemfile`（`group :test`）
- Modify: `Gemfile.lock`（`bin/bundle install` で更新）
- Modify: `spec/spec_helper.rb:1-7`
- Create: `config/mutant.yml`
- Create: `config/mutant/hooks.rb`
- Modify: `.gitignore`（最後に `/.mutant/`）
- Create: `.github/workflows/mutant.yml`
- Create: `docs/decisions/mutation-testing-with-mutant.md`
- Modify: `docs/decisions/index.md`（最後に 1 行）
- Test: 新しい RSpec の example は足さない（アプリの振る舞いを変えないため）。確かめは各ステップのコマンドで行う

- [ ] **Step 1: ブランチを作る**

`git-spice-workflow` Skill に従い、実装の worktree で:

```bash
git fetch origin ci/add-code-review-graph-report
git-spice branch checkout ci/add-code-review-graph-report
git-spice branch create ci/add-mutant-report
git-spice log short
```

Expected: `gs log short` で `ci/add-mutant-report` が `ci/add-code-review-graph-report` のすぐ上にある。`git rev-parse HEAD` が `origin/ci/add-code-review-graph-report` と同じ（作った直後はコミットが無い）。worktree の都合で `branch checkout` ができないときは、Skill の手順のとおりに積む先を指定して作る。

- [ ] **Step 2: `mutant-rspec` を足す**

`Gemfile` の `group :test` を次にする:

```ruby
group :test do
  gem "mutant-rspec", "~> 0.17.1", require: false

  gem "simplecov", "~> 1.3", require: false
end
```

Run:

```bash
bin/bundle install
grep -nE '^    (mutant|mutant-rspec|parser|unparser|sorbet-runtime) ' Gemfile.lock
git diff --stat
```

Expected: `mutant (0.17.1)`・`mutant-rspec (0.17.1)` が入り、`parser (3.3.11.1)` は変わらない。`git diff Gemfile.lock` は gem の追加（mutant・mutant-rspec・unparser・sorbet-runtime など）と `DEPENDENCIES` の 1 行だけで、既存の gem の版は変わらない。`PLATFORMS` と `BUNDLED WITH` は変わらない。既存の gem の版が変わったら、`bin/bundle install` を `bin/bundle lock --conservative` に替えてやり直す。

- [ ] **Step 3: 依存をコミットする**

```bash
git add Gemfile Gemfile.lock
git commit -m "build: add mutant-rspec for mutation testing"
```

- [ ] **Step 4: SimpleCov に `track_tests` を足す**

`spec/spec_helper.rb` の先頭の `if ENV["COVERAGE"]` の塊を次にする（他の行は変えない）:

```ruby
if ENV["COVERAGE"]
  require "simplecov"
  # TEST_ENV_NUMBER is only a test DB suffix here, not a parallel run;
  # without this, SimpleCov skips the report when its value is not 1.
  SimpleCov.parallel_tests = false
  SimpleCov.start "rails" do
    # Record which examples ran each line, so that mutant's context_map
    # selection can pick the tests for a subject.
    track_tests
  end
end
```

- [ ] **Step 5: 記録が出ることを確かめる（AC-1）**

Run:

```bash
rm -rf coverage && COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec; echo "rspec-exit=$?"
ruby -rjson -e '
  d = JSON.parse(File.read("coverage/coverage.json"))
  ids = d["contexts"] || []
  files = d.fetch("coverage").count { |_, v| v.is_a?(Hash) && v["contexts"] }
  puts "schema=#{d.dig("meta", "schema_version")} contexts=#{ids.size} files_with_contexts=#{files}"
  exit(ids.empty? || files.zero? ? 1 : 0)
'; echo "check-exit=$?"
ruby -rjson -e 'p JSON.parse(File.read("coverage/.last_run.json")).dig("result", "line")'
rm -rf coverage && RAILS_ENV=test bin/bundle exec rspec >/dev/null; echo "plain-rspec-exit=$?"; ls -d coverage 2>/dev/null || echo "no coverage dir"
```

Expected: `rspec-exit=0`、`schema=1.…`、`contexts` と `files_with_contexts` が 1 以上で `check-exit=0`。`.last_run.json` の率が数で出る（`ci.yml` の job `rspec` の報告の手順が今までどおり読める）。`COVERAGE` なしの rspec も通り、`no coverage dir`。

`coverage/coverage.json` が無い、または `contexts` が無いとき（REQ-002 の分岐）: `SimpleCov.start "rails" do` の塊の中、`track_tests` の次の行に `formatter SimpleCov::Formatter::MultiFormatter.new([SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::JSONFormatter])` を足して、このステップをやり直す（SimpleCov 1.3.2 は JSONFormatter を本体に持つ: `lib/simplecov/formatter/json_formatter.rb`。別の gem は要らない。`NameError` になったら `require "simplecov"` の次の行に `require "simplecov/formatter/json_formatter"` を足す）。それでも出ないときは止まり、bead に結果を書いて mayor に報告する。

- [ ] **Step 6: `track_tests` をコミットする**

```bash
bin/bundle exec rubocop spec/spec_helper.rb
git add spec/spec_helper.rb
git commit -m "test: record per-test coverage for mutant test selection"
```

Expected: rubocop は `no offenses detected`。

- [ ] **Step 7: Mutant の設定を書く**

`config/mutant.yml`:

```yaml
usage: opensource
requires:
  - ./config/environment
environment_variables:
  RAILS_ENV: test
integration:
  name: rspec
matcher:
  subjects:
    - source:app/**/*.rb
selection:
  strategy: context_map
jobs: 1
mutation:
  timeout: 120.0
hooks:
  - config/mutant/hooks.rb
```

`config/mutant/hooks.rb`:

```ruby
# Load every constant under app/ before mutant matches subjects, because the
# test environment loads lazily outside CI.
hooks.register(:env_infection_post) do
  Rails.application.eager_load!
end
```

`.gitignore` の最後（`/coverage/` の後）に足す:

```gitignore

# Mutant
/.mutant/
```

- [ ] **Step 8: 設定が受け付けられ、subject が出ることを確かめる（AC-2）**

Step 5 の記録（`coverage/coverage.json`）が残っている状態で（消したら `COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec` で作り直す）:

```bash
bin/bundle exec mutant environment show 2>&1 | grep -E '^(Usage|Integration|Jobs|MutationTimeout|Selection|Subjects):'
f=$(mktemp); bin/bundle exec mutant environment subject list > "$f"; echo "exit=$?"
head -n 1 "$f"; grep -c '^Api::V1::ContactsController#' "$f"; grep -cE '^Contact[#.]' "$f"
```

Expected: `Usage:           opensource`、`Integration:     rspec`、`Jobs:            1`、`MutationTimeout: 120`、`Selection:       context_map`、`Subjects:` が 1 以上。subject list は `exit=0`、1 行目が `Subjects in environment: <1 以上>`、controller と model の subject がどちらも 1 以上（要件 AC-2 の「`Integration: ...Rspec`」は、0.17.1 が integration の名前を出すので `rspec` と読む）。

設定のキーが受け付けられないとき（REQ-001 の分岐）: エラーの出たキーを `config/mutant.yml` から外し、同じ値をコマンドの引数（例 `--usage opensource`・`--jobs 1`）で、Step 11 のワークフローの `mutant environment subject list` と `mutant run` の両方と、Step 15 の決定の記録の手元の手順に書く。`source:app/**/*.rb` で controller・model の subject が出ないとき: `matcher.subjects` を `Api*`・`ApplicationController`・`DateRangeFilter`・`ErrorRendering`・`ApplicationJob`・`ApplicationMailer`・`DeviseMailer`・`ApplicationRecord`・`Block`・`UserOverride`・`Contact`・`Task`・`TaskGroup`・`TaskGroupShare`・`User`・`*Resource`・`MimeTypeAndExtensionConsistencyValidator`・`ApplicationCable*` の式に替える（`app/` の下のトップの定数。`git ls-files 'app/**/*.rb'` と照らして漏れが無いことを確かめる）。

- [ ] **Step 9: 1 つの controller の subject でミューテーションが殺されることを確かめる（AC-3・AC-4）**

```bash
cov=coverage/coverage.json
before="$(stat -c %Y "$cov") $(sha256sum "$cov" | cut -d' ' -f1)"
rm -rf .mutant
bin/bundle exec mutant run 'Api::V1::ContactsController#destroy' 2>&1 | tee "$(mktemp -d)/run.txt" | grep -E '^(Selection|Subjects|Selected-Tests|Mutations|Kills|Alive):'
after="$(stat -c %Y "$cov") $(sha256sum "$cov" | cut -d' ' -f1)"
[ "$before" = "$after" ] && echo "coverage unchanged" || echo "coverage CHANGED"
bin/bundle exec mutant session list
```

Expected: `Selection:       context_map`、`Subjects:        1`、`Selected-Tests:` が 1 以上（controller を通る spec は request spec だけなので、選ばれたのは request spec）。`mutant session list` の行で `MUTATIONS` が `ALIVE` より大きい（少なくとも 1 つ殺した）。`coverage unchanged`（AC-4）。`mutant run` の終了コードは生き残りがあれば 0 以外でよい。`Selected-Tests: 0` のときは `context_map` の記録と request spec の対応が取れていないので、止まり、出力を bead に書いて mayor に報告する。

ミューテーションの時間切れ（`Alive` の中に timeout と出る物）があれば、その subject の spec（`spec/requests/api/v1/contacts_spec.rb`）を `time RAILS_ENV=test bin/bundle exec rspec spec/requests/api/v1/contacts_spec.rb` で走らせ、上限内に終わるなら REQ-005 の式（rspec の時間 × 1.25 を 10 秒単位に切り上げ）で `mutation.timeout` を上げる。

- [ ] **Step 10: Mutant の設定をコミットする**

```bash
git status --porcelain
bin/bundle exec rubocop config/mutant/hooks.rb
git add config/mutant.yml config/mutant/hooks.rb .gitignore
git commit -m "chore: configure mutant for the app subjects"
```

Expected: コミット前の `git status --porcelain` に `.mutant/` と `coverage/` が出ない（`.gitignore` が効いている）。rubocop は `no offenses detected`。

- [ ] **Step 11: ワークフローを書く**

`.github/workflows/mutant.yml`:

```yaml
name: mutant

on:
  pull_request:

permissions:
  contents: read

defaults:
  run:
    shell: bash

jobs:
  report:
    name: report
    runs-on: ubuntu-latest
    timeout-minutes: 30
    container: ruby:4.0.0
    services:
      db:
        image: mysql:8.4.8
        env:
          MYSQL_ROOT_PASSWORD: ci_root_password
          MYSQL_USER: ci_user
          MYSQL_PASSWORD: ci_password
          MYSQL_DATABASE: tascon_test
        options: >-
          --health-cmd "mysqladmin ping -h 127.0.0.1 -uroot -pci_root_password"
          --health-interval 2s
          --health-timeout 5s
          --health-retries 60
    env:
      RAILS_ENV: test
      TZ: Asia/Tokyo
      CI: "true"
      MYSQL_USER: ci_user
      MYSQL_PASSWORD: ci_password
      MYSQL_DATABASE: tascon_test
      MYSQL_TEST_DATABASE: tascon_test
      WEB_HOST: localhost
      WEB_PORT: "8080"
      RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
      BASE_REF: ${{ github.event.pull_request.base.ref }}
    steps:
      - name: Install libvips
        run: |
          apt-get update -qq
          apt-get install -y --no-install-recommends libvips42
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Configure git
        run: git config --global --add safe.directory "$GITHUB_WORKSPACE"
      - name: Fetch the base branch
        run: git fetch --no-tags --depth=1 origin "+refs/heads/${BASE_REF}:refs/remotes/origin/${BASE_REF}"
      - uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: /usr/local/bundle
          key: gems-ruby-4.0.0-${{ runner.os }}-${{ hashFiles('Gemfile.lock') }}
          restore-keys: gems-ruby-4.0.0-${{ runner.os }}-
      - name: Install gems
        run: bundle install --jobs 4
      - name: Prepare the database
        run: bin/rails db:prepare
      - name: Record the per-test coverage
        env:
          COVERAGE: "true"
        run: bin/bundle exec rspec
      - name: Count the changed subjects
        id: subjects
        run: |
          list=$(bin/bundle exec mutant environment subject list --since "origin/${BASE_REF}")
          printf '%s\n' "$list"
          count=$(sed -n '1s/^Subjects in environment: \([0-9][0-9]*\)$/\1/p' <<<"$list")
          if [ -z "$count" ]; then
            echo "::error::Could not read the number of changed subjects"
            exit 1
          fi
          echo "count=$count" >> "$GITHUB_OUTPUT"
      - name: mutant
        if: steps.subjects.outputs.count != '0'
        run: |
          set +e
          bin/bundle exec mutant run --since "origin/${BASE_REF}"
          echo "mutant run exited with $?"
      - name: Write the report to the step summary
        if: ${{ !cancelled() }}
        env:
          SUBJECT_COUNT: ${{ steps.subjects.outputs.count }}
        run: |
          if [ "$SUBJECT_COUNT" = "0" ]; then
            printf '%s\n' "### Mutant" "" "No subjects changed in this pull request." >> "$GITHUB_STEP_SUMMARY"
            exit 0
          fi
          if ! compgen -G '.mutant/results/*.json.gz' >/dev/null; then
            printf '%s\n' "### Mutant" "" "Mutant did not run. See the log of the earlier steps." >> "$GITHUB_STEP_SUMMARY"
            echo "::error::Mutant did not run"
            exit 1
          fi
          subjects=$(bin/bundle exec mutant session subject)
          alive=$(bin/bundle exec mutant session show)
          {
            printf '%s\n' "### Mutant" "" "Alive and total mutations per subject:" "" '```'
            printf '%s\n' "$subjects"
            printf '%s\n' '```' "" "<details><summary>Alive mutations</summary>" "" '```'
            printf '%s\n' "${alive:0:500000}"
            printf '%s\n' '```' "" "</details>"
          } >> "$GITHUB_STEP_SUMMARY"
```

書き方の決まり:

- `COVERAGE` は job の env に置かず、`Record the per-test coverage` の手順の env にだけ置く（REQ-002・REQ-003）
- `${{ }}` の値は run の中に直接書かず、env を通す（`BASE_REF`・`SUBJECT_COUNT`）。Step 12 で run の中身をそのまま手元で走らせるため
- Step Summary の文言は、既存のワークフロー（`ci.yml` の `### Coverage`、`code-review-graph.yml` の `::error::`）に合わせて英語にする。要件の「変えた subject は無い」は `No subjects changed in this pull request.`、「Mutant が走らなかった」は `Mutant did not run.` に当たる
- `alive` の文字数を 500000 で切るのは Step Summary の 1 手順あたり 1 MiB の上限のため。`head -c` は pipefail と SIGPIPE で手順を落とすことがあるので使わない

- [ ] **Step 12: ワークフローの手順を手元で走らせる（AC-6 の手元の部分・AC-7）**

ワークフローの run の中身を YAML から取り出し、GitHub Actions と同じ `bash -eo pipefail` で走らせる。下の関数を実装の worktree の根で定義する:

```bash
T=$(mktemp -d)
extract() {
  ruby -ryaml -e '
    steps = YAML.load_file(".github/workflows/mutant.yml").dig("jobs", "report", "steps")
    puts steps.find { |s| s["name"] == ARGV[0] }.fetch("run")
  ' "$1" > "$T/$2.sh"
}
extract "Count the changed subjects" count
extract "mutant" run
extract "Write the report to the step summary" report
git fetch origin ci/add-code-review-graph-report
scenario() {
  rm -rf .mutant
  : > "$T/out"; : > "$T/summary"
  export GITHUB_OUTPUT="$T/out" GITHUB_STEP_SUMMARY="$T/summary" BASE_REF=ci/add-code-review-graph-report
  bash -eo pipefail "$T/count.sh"; local count_exit=$?
  local count; count=$(sed -n 's/^count=//p' "$T/out")
  if [ "$count_exit" -eq 0 ] && [ "$count" != "0" ]; then bash -eo pipefail "$T/run.sh"; fi
  SUBJECT_COUNT="$count" bash -eo pipefail "$T/report.sh"; local report_exit=$?
  echo "[$1] count_exit=$count_exit count=$count report_exit=$report_exit"
  head -n 20 "$T/summary"
}
```

先に `COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec` で記録を作り直してから、3 つの場面を走らせる:

```bash
scenario zero-subjects

sed -i 's/^        head :no_content$/        head(:no_content)/' app/controllers/api/v1/contacts_controller.rb
git diff --stat app/
scenario one-subject
git checkout -- app/controllers/api/v1/contacts_controller.rb

printf '\nraise "broken on purpose to check the mutant report"\n' >> config/environment.rb
scenario broken
git checkout -- config/environment.rb
git status --porcelain
```

Expected:

- `[zero-subjects] count_exit=0 count=0 report_exit=0`、要約に `No subjects changed in this pull request.`（この build の PR は `app/` を変えないので、PR の上の AC-6 も同じ経路を通る見込み）
- `git diff --stat app/` が `contacts_controller.rb` の 1 行の変更を示し、`[one-subject] count_exit=0 count=<1 以上> report_exit=0`、要約に `ALIVE  TOTAL  SUBJECT` の表と `Api::V1::ContactsController#destroy` の行と `<details>` の塊
- `[broken] count_exit=<0 以外> count= report_exit=1`、要約に `Mutant did not run.`（AC-7。確かめ方は「手元でワークフローと同じ手順を走らせて見る」）
- 最後の `git status --porcelain` が空（一時の変更が残っていない）

`sed -i` が何も変えなかったとき（`git diff --stat app/` が空）は、`contacts_controller.rb` の `destroy` の `head :no_content` の行を手で `head(:no_content)` に替えて走らせる。

`[zero-subjects]` で `count_exit` が 0 以外になったとき（REQ-003 の分岐: Ruby のコードを変えない PR で `subject list --since` が失敗する）: `Count the changed subjects` の run を次に替え、`mutant` の手順の `if` は今のまま、`report` の手順は session があれば報告する今の形のままにして、このステップをやり直す:

```bash
changed=$(git diff --name-only "origin/${BASE_REF}" -- 'app/**/*.rb')
printf '%s\n' "$changed"
if [ -z "$changed" ]; then
  echo "count=0" >> "$GITHUB_OUTPUT"
else
  echo "count=changed" >> "$GITHUB_OUTPUT"
fi
```

- [ ] **Step 13: 固定と既存のファイルの不変を確かめる（AC-5・AC-8）**

```bash
grep -nE 'uses:' .github/workflows/mutant.yml
grep -nE 'uses:' .github/workflows/mutant.yml | grep -vE 'uses: [^@]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' || echo "all pinned"
git diff origin/ci/add-code-review-graph-report --stat -- .github/workflows/ci.yml .github/workflows/code-review-graph.yml .github/workflows/codeql.yml lefthook.yml .lefthook/ ; echo "diff-exit=$?"
ruby -ryaml -e 'YAML.load_file(".github/workflows/mutant.yml"); puts "yaml ok"'
```

Expected: `uses:` は 2 行（checkout と cache）で、`all pinned`。`git diff --stat` の出力が空。`yaml ok`。`actionlint` があれば `actionlint .github/workflows/mutant.yml` も走らせ、無ければ「未実行（actionlint が無い）」と bead に書く。

- [ ] **Step 14: ワークフローをコミットする**

```bash
git add .github/workflows/mutant.yml
git commit -m "ci: add a report-only mutant workflow"
```

- [ ] **Step 15: 決定の記録を書く**

`docs/decisions/mutation-testing-with-mutant.md`:

```markdown
# ミューテーションテストをMutantで報告だけ走らせる

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-20
- **Related Files:** `config/mutant.yml`, `config/mutant/hooks.rb`, `.github/workflows/mutant.yml`, `spec/spec_helper.rb`, `Gemfile`

## Context

テストがコードの振る舞いの変化をどれだけ捕まえるかは、行のカバレッジ（SimpleCov）でしか見えなかった。ミューテーションテストの道具Mutantを入れる。CIのチェックを合否を返す物と報告だけの物に分ける (path: ci-required-and-report-only-checks.md)はミューテーションテストを「入れる場合も報告だけにする」と決めており、これに従う。

## Decision

- Mutant 0.17.1（`mutant-rspec`）を、ワークフロー`mutant`のjob`report`でPRごとに走らせる。結果（subjectごとの生き残り/総数と、生き残ったミューテーションのdiff）はStep Summaryに書き、合否を返さない。生き残りではjobを落とさず、Mutantが走らなかった（sessionができなかった）ときだけ落とす。必須チェックの候補にしない
- 対象は、PRが行を変えた`app/`のsubjectだけにする（`--since origin/<base>`）
- テストは、SimpleCovの`track_tests`で記録したtestごとのカバレッジ（`coverage/coverage.json`）から選ぶ（`selection.strategy: context_map`）。同じjobの中で、先に`COVERAGE`付きのrspecで記録を作る
- workerは1つにする（`jobs: 1`）
- `usage: opensource`を使う。このリポジトリが公開のリポジトリで、MITのライセンスで公開されることを前提にする
- ワークフローは`ci.yml`の外の別のファイルに置く。合否を返すjobと同じファイルに置かないため、まとめ役のjobのneedsに入らない
- 1つのミューテーションの上限は120秒（`mutation.timeout`）、jobの上限は30分（`timeout-minutes`）にする

## Considered Options

- **採用: 別のワークフローの報告だけのjobで、変えたsubjectだけを、記録したカバレッジでテストを選び、1 workerで走らせる**: 長所: 報告だけの物を合否を返す物と別のファイルに置け、request specがcontrollerのsubjectのミューテーションを殺したと数えられ、DBの分離のコードが要らず、PRごとの時間が変えた量に比例する。短所: rspecを`ci.yml`のjob`rspec`と合わせて2回走らせ、変えたsubjectが多いPRでは遅く、間接的に振る舞いが変わったsubject（定数の変更など）は選ばれない
- **`ci.yml`にjobを足し、job`rspec`のカバレッジの記録をartifactで渡す**: 長所: rspecが1回で済む。短所: 全部のjobをneedsで待つまとめ役の形と食い違う報告だけのjobが`ci.yml`にでき、job`rspec`に記録のuploadの手順を足すことになる
- **workerごとにMySQLのDBを分けて並列に走らせる**: 長所: 変えたsubjectが多いPRでも速い。短所: MutantのRailsの文書にMySQLの手順が無く、workerごとの`CREATE DATABASE`とschemaの読み込みをhooksに書いて保つ必要があり、CIのDBのユーザーにはDBを作る権限が無い。今の規模では速さの得が小さい
- **テストの選び方を既定の`expression`にする**: 長所: カバレッジの記録が要らない。短所: example groupの説明の先頭の定数名でテストを選ぶため、説明が`"Contacts"`などのrequest specはcontrollerのsubjectに選ばれず、そのミューテーションがすべて生き残りと出る。`mutant_expression`のメタデータで対応を手で書くと、書き漏れた所が黙って生き残りと出る
- **テストの選び方を`auto`にする**: 長所: 記録があれば`context_map`と同じに選ぶ。短所: 記録が壊れたときに黙って`expression`に落ち、報告の意味が変わる

## Consequences

- 手元では、開発コンテナで`COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec`の後に`bin/bundle exec mutant run --since main`を走らせる
- `COVERAGE`を付けたまま`mutant run`を走らせると、workerの中でSimpleCovが始まり、`coverage/coverage.json`の記録が上書きされる
- 生き残りが出てもPRは落ちない。生き残りはStep Summaryで人が見る
- jobが30分を超えると取り消されて落ちるが、必須チェックではないのでマージは止まらない
- forkからのPRでは`RAILS_MASTER_KEY`が渡らずRailsを読み込めないため、jobが落ちる
```

Step 8 で設定のキーを引数に移したときは、Consequences の手元の手順の行を、その引数を足したコマンドにする。Step 9 または Step 12 で `mutation.timeout` を変えたときは、Decision の「120秒」をその値にし、Consequences に測った時間を 1 行足す。

`docs/decisions/index.md` の最後に 1 行足す:

```markdown
- ミューテーションテストをMutantで報告だけ走らせる (path: mutation-testing-with-mutant.md)
```

- [ ] **Step 16: 決定の記録と全体を確かめる（AC-9・AC-8 の続き）**

```bash
bash .lefthook/pre-commit/check-docs.sh; echo "check-docs-exit=$?"
grep -c 'mutation-testing-with-mutant.md' docs/decisions/index.md
grep -nE '^- `?COVERAGE|mutant run --since main' docs/decisions/mutation-testing-with-mutant.md
git diff origin/ci/add-code-review-graph-report -- docs/decisions/ci-required-and-report-only-checks.md | wc -l
bin/bundle exec rubocop; echo "rubocop-exit=$?"
mapfile -d '' files < <(git ls-files -z '*.rb'); bin/bundle exec debride --rails -w debride-whitelist.txt "${files[@]}" | tail -n 1
RAILS_ENV=test bin/bundle exec rspec >/dev/null; echo "rspec-exit=$?"
bash .lefthook/pre-commit/tests/run.sh >/dev/null; echo "precommit-tests-exit=$?"
```

Expected: `check-docs-exit=0`、index の行が 1、Consequences の手元の手順と `COVERAGE` の注意の行が見つかる、`ci-required-and-report-only-checks.md` の差分が 0 行、`rubocop-exit=0`、debride が `Total suspect LOC: 0`、`rspec-exit=0`、`precommit-tests-exit=0`。

- [ ] **Step 17: 決定の記録をコミットする**

```bash
git add docs/decisions/mutation-testing-with-mutant.md docs/decisions/index.md
git commit -m "docs: record running mutant as a report-only check"
git-spice log short
git log --oneline origin/ci/add-code-review-graph-report..HEAD
```

Expected: コミットが 5 つ（build・test・chore・ci・docs）、`gs log short` で `ci/add-mutant-report` が `ci/add-code-review-graph-report` の上の 1 段。

- [ ] **Step 18: 結果を残す**

bead のノートと implementation summary に、AC-1〜AC-9 のそれぞれについて「何を走らせ、何と比べ、結果がどうだったか」を書く。あわせて次を書く:

- 手元の `COVERAGE=1` の rspec の時間（Step 5 を `time` で測る）。CI の時間は PR が開かれた後に見る（REQ-005）
- AC-7 は「手元でワークフローと同じ手順を走らせて見た」こと（Step 12）
- 「Verification」の「PR を出す作業の引き継ぎ」の PR の題名・本文の案
- マージの順（LICENSE の PR tb-cknct (5) の後にマージするか）を mayor に知らせる（要件の Open Questions。`gc mail send mayor` で、決めるのは人と mayor）

## Non-Goals

- Mutant を必須チェックにすること、まとめ役 `checks` を作ること（部分 tb-2dqkd）
- MIT の LICENSE のファイルを足すこと（部分 tb-cknct の (5)）
- 全 subject を対象にする定期の全数実行
- 生き残ったミューテーションを殺すためのテストの追加・アプリのコードの変更
- worker ごとの MySQL の DB の分離
- PR へのコメント（`pull-requests: write`）
- `ci.yml`・`code-review-graph.yml`・`codeql.yml`・`lefthook.yml`・`.lefthook/` の変更、`ci-required-and-report-only-checks.md` の本文の書き換え
- README・ARCHITECTURE.md への手順の記載
- `docs/superpowers/specs/` への設計の写し、リポジトリの計画ファイル（`.claude/plans/active/`）
- PR を開くこと、PR のマージ（`open_pr=false`）

## Validation and Acceptance

### 受け入れの条件とタスクの対応

- AC-1（`track_tests` の記録）: Task 1 Step 5
- AC-2（`environment show` と subject list）: Task 1 Step 8
- AC-3（controller の subject でミューテーションを殺す）: Task 1 Step 9、Step 12 の `one-subject`
- AC-4（`COVERAGE` なしの `mutant run` が記録を上書きしない）: Task 1 Step 9
- AC-5（`uses:` の固定）: Task 1 Step 13
- AC-6（PR の上で `report` が成功）: 手元の同じ手順は Task 1 Step 12 の `zero-subjects`。PR の上は引き継ぎ（下）
- AC-7（Rails が読めないとき落ちる）: Task 1 Step 12 の `broken`（手元で同じ手順を走らせる方法）
- AC-8（既存の物の不変）: Task 1 Step 13・16
- AC-9（決定の記録と `check-docs.sh`）: Task 1 Step 15・16
- AC-10（スタックと PR 本文）: スタックは Task 1 Step 1・17、本文は引き継ぎ

PR の上でしか確かめられない条件（AC-6・AC-10）は、implementation summary に「未確認（PR が無いため）」と書き、下の手順を添える。

### PR を出す作業の引き継ぎ

`gc.var.open_pr=false`・`push=true` のため、この build はブランチを push するが PR を開かない。PR を開く人（mayor か後の段）は次を行う。

1. `git-spice-workflow` Skill の「プルリクエスト作成ルール」に従い、`ci/add-mutant-report` を submit する。題名の案: `ci: add a report-only mutant workflow`
2. 本文の案（英語。チェック名は CI の後に `gh pr checks <PR>` の実際の名前で置き換える）:

   ```markdown
   ### Summary

   Run Mutant mutation testing on the `app/` subjects that a pull request changes, and write the result to the step summary only. It does not gate merging.

   ### Changes

   - Add `mutant-rspec` 0.17.1 to the `test` group, with `config/mutant.yml` (`usage: opensource`, `context_map` test selection, one worker, a 120 second mutation timeout) and `config/mutant/hooks.rb` (eager load before matching subjects).
   - Record per-test coverage with SimpleCov `track_tests` when `COVERAGE` is set, for the `context_map` selection.
   - Add workflow `.github/workflows/mutant.yml` (job `report`, check name `mutant / report (pull_request)`). It runs rspec with coverage, counts the subjects changed since the base branch, runs `mutant run --since`, and writes the alive mutations to the step summary. It fails only when Mutant did not run. It is not a required check.
   - Add the decision record `docs/decisions/mutation-testing-with-mutant.md` and its line in `docs/decisions/index.md`, and ignore `/.mutant/`.
   - `ci.yml`, `lefthook.yml` and `.lefthook/` are unchanged.

   ### Testing

   <the AC results from the implementation summary>

   ### Related Issues (Optional)

   N/A

   ### Related Documents

   - Plan: N/A
   - Spec: N/A

   ### Notes (Optional)

   - `usage: opensource` assumes that the MIT LICENSE pull request is merged to main first.
   - The Mutant EULA section 1.2 says to keep the list of public repositories in the subscription settings. Whether this repository needs that registration is left to a human decision.
   - The registered check name is `report`, the same as the job of the `code-review-graph` workflow. Neither is a required check.
   ```

3. AC-6: CI が終わった後、Checks の画面で `mutant / report` が成功し、Step Summary に `No subjects changed in this pull request.`（この PR は `app/` を変えない）が出ることを見る。`Record the per-test coverage` の手順の時間が 100 秒を超えていたら REQ-005 の式で `mutation.timeout` を上げ、Mutant の手順が 20 分を超えていたら `timeout-minutes` を上げて決定の記録の Consequences に測った時間を書く
4. AC-10: 表示名と登録名を本文と比べ、違えば本文を実際の名前に直す。PR の base が `ci/add-code-review-graph-report` であることを見る

## Open Questions

- **仮定: リポジトリの計画ファイルを作らない**: `.claude/rules/plans-maintenance.md` の「作成の手順」は、作るときの順と複数の段の計画の進め方を決めている。この作業は 1 段・1 PR で、手順の詳細はこの build の artifact にあるため、`.claude/plans/active/` に計画を置かず、PR 本文は `- Plan: N/A` にする（`check-pr-body.sh` は `N/A` を受け付ける）。前の build（test-and-check-tools-ci）は 4 段のスタックだったので計画を置いた
- **仮定: Step Summary の文言は英語**: 既存のワークフローの報告と `::error::` が英語のため。要件の日本語の文言は意味として写した
- **仮定: コミットの type**: `Gemfile` は `build`、`spec_helper.rb` は `test`、Mutant の設定は `chore`、ワークフローは `ci`、決定の記録は `docs`。PR の題名の type は `ci`（ブランチ名と同じ）。`git-spice-workflow` Skill の type の基準と違えば、実装の lane が直して bead に書く
- **仮定: 要件 AC-2 の `Integration: ...Rspec`**: Mutant 0.17.1 の `environment show` は integration の名前 `rspec` を出す（`lib/mutant/reporter/cli/printer/config.rb`）。`Integration:     rspec` を合格とする
- **事実として PR 本文に書く（人の判断に残す）**: マージの順（LICENSE の PR との前後）と、Mutant の EULA 1.2 の公開のリポジトリの一覧への登録の要否。作業は止めない
- **リスク: 同じ登録名 `report`**: `code-review-graph` と `mutant` の job の登録名がどちらも `report` になる。どちらも必須にしないので今は困らないが、片方を必須にするときは名前で区別できない。要件 REQ-003 が job の ID と表示名を `report` と決めているため、この build では変えず、PR 本文の Notes に書く

## Coverage

| ID | Status | 計画の対応 |
| --- | --- | --- |
| REQ-001 | covered | Task 1 Step 2・3・7・8・10 |
| REQ-002 | covered | Task 1 Step 4〜6・9 |
| REQ-003 | covered | Task 1 Step 11・12 |
| REQ-004 | covered | Task 1 Step 11・12 |
| REQ-005 | covered | Task 1 Step 7・9・11・18、引き継ぎ 3 |
| REQ-006 | covered | Task 1 Step 2・11・13 |
| REQ-007 | covered | Task 1 Step 11・13・16、Non-Goals |
| REQ-008 | covered | Task 1 Step 15〜17 |
| REQ-009 | covered | Task 1 Step 15・16 |
| REQ-010 | covered | Task 1 Step 1・17・18、引き継ぎ 1〜4 |

## Decision Log

- 2026-11-19: plan-review で計画を承認。正式な plan/spec を保存する方針を採用。保存しない旨の旧記述はこの決定で変更。出典: /home/ruby/tascon-backend/.gc-artifacts/mutant-mutation-testing/requirements.md, /home/ruby/tascon-backend/.gc-artifacts/mutant-mutation-testing/brainstorming/design-candidate.md, /home/ruby/tascon-backend/.gc-artifacts/mutant-mutation-testing/implementation-plan.md。 保存時の documents base に存在しないリンクは、リンクテキストと元の参照先をプレーンテキストで保持: `ci-required-and-report-only-checks.md`。
