# test-and-check-tools-ci specification

## Approved requirements

## 要件: テストと確かめの道具を CI に入れる（tascon-backend）

- 依頼: tb-wtiom（HQ 依頼 gc-n91n の部分 2、ラベル `human-request-part`）
- workflow root: tb-u5bv6（`superpowers-build`）、convoy tb-naywy
- 承認済みの設計: `/home/ruby/tascon-backend/.gc-artifacts/test-and-check-tools-ci/brainstorming/design-candidate.md`（design approval lane tb-dq4pf が autonomous で承認、2026-11-18。判定は同じ場所の `approval-summary.md`）
- この要件の置き場所: `/home/ruby/tascon-backend/.gc-artifacts/test-and-check-tools-ci/requirements.md`
- `docs/superpowers/specs/` への写し: 作らない。main checkout は人が開いたままで、追跡されないファイルを置くと lefthook の `pre-push` の `check-git-clean` が push を止めるため、安全に写せない。設計と要件はこの build の成果物の場所だけに置く（前例 `.claude/plans/active/git-spice-merge-and-ci-gates.md` の「Spec: N/A」と同じ扱い）

### Problem Statement

tascon-backend の PR ごとの CI には今、`rspec` と `checks`（`.github/workflows/ci.yml`）しかない。テストのカバレッジ、Rails の静的解析、コードの脆弱性の解析、PR で新しく入る依存の既知の脆弱性、変更の影響の報告が CI で見えない。

依頼 tb-wtiom は、SimpleCov・Brakeman・CodeQL（Ruby）・Semgrep（Rails の規則）・Dependency Review・code-review-graph を PR ごとの CI に入れ、外から持ち込む物（Action、Python の道具の本体、規則）の版を不変の ID で固定し、道具を選んだ理由と必須チェックにする物としない物を `docs/decisions/` に残すことを求めている。PR は道具のまとまりごとに分ける。必須チェックの設定、「Allow GitHub Actions to create and approve pull requests」の設定、lefthook は変えない。

### W6H

- Who（誰のため）: リポジトリの持ち主（P-manBrown）。PR のレビューと、後で必須チェックを選ぶときに使う。実装するのは Gas City の implementer lane
- What（何を）: 6 つの道具の CI への導入、版の固定、Dependabot の更新対象の追加、決定の記録 2 件、PR 本文のチェック名の一覧
- When（いつ）: 今夜（2026-11-18〜19）に PR を出すところまで。マージと必須チェックの登録は範囲外
- Where（どこに）: `.github/workflows/ci.yml`（既存に新ジョブ）、`.github/workflows/codeql.yml`（新規）、`.github/workflows/code-review-graph.yml`（新規）、`.github/requirements/`（新規）、`.github/dependabot.yml`、`Gemfile`・`Gemfile.lock`、`spec/spec_helper.rb`、`.gitignore`、`docs/decisions/`
- Why（なぜ）: カバレッジと安全性の問題と変更の影響を PR の時点で見えるようにし、後で必須チェックを選べる材料を作る。外の物を固定するのは、コードを変えていない PR の結果が外の更新で変わるのを防ぐため
- How（どうやって）: 道具の CLI を CI のステップで直接走らせる。Action は 40 桁の SHA、Python の道具は hash 付き requirements、Ruby の道具は `Gemfile.lock` で固定し、Dependabot で更新する。PR は git-spice の 4 段の一直線のスタック
- How much（どれだけ）: PR 4 本、新しいジョブ 5 つ（`brakeman`・`semgrep`・`dependency-review`・`Analyze (ruby)`・`report`）、決定の記録 2 ファイル

### User Stories

- US-1: リポジトリの持ち主として、PR ごとにテストのカバレッジの率を見たい。ただし率で PR を落としたくない
- US-2: リポジトリの持ち主として、Rails の危ない書き方（Brakeman・Semgrep）とコードの脆弱性（CodeQL）を PR の時点で知りたい
- US-3: リポジトリの持ち主として、PR で新しく入る依存に既知の脆弱性があれば PR を止めたい
- US-4: リポジトリの持ち主として、PR の変更の影響（code-review-graph）を報告として見たい。ただしリスクの点数で PR を落としたり必須にしたりしたくない
- US-5: リポジトリの持ち主として、後で必須チェックに登録できるよう、新しくできるチェックの実際の表示名と登録名を PR の本文で知りたい
- US-6: リポジトリの持ち主として、道具を選んだ理由と必須にする物としない物の理由を、その道具を入れる PR の中で `docs/decisions/` から読みたい

### Technical Stories

- TS-1: 外の Action を SHA で固定し、Dependabot の `github-actions` で更新できるようにする
- TS-2: Python の道具（Semgrep、code-review-graph）の本体と全依存を hash 付きの requirements で固定し、Dependabot の `pip` で更新できるようにする
- TS-3: code-review-graph の公式の composite Action は中の Action がタグ参照で本体の版も浮くため使わず、CLI を直接走らせ、レンダラを本体と同じ版のタグの SHA で取り出す
- TS-4: Semgrep の規則を `semgrep/semgrep-rules` の固定の SHA から取り出し、リポジトリには写さない（Semgrep Rules License v1.0 は再配布を許さないと読めるため）
- TS-5: 新しいジョブを既存の `ci.yml` の型（`on: pull_request`、`permissions: contents: read`、checkout の `persist-credentials: false`、Ruby の道具は `ruby:4.0.0` コンテナと同じキーの `actions/cache`）に合わせる

### Behavior Requirements

#### REQ-001: SimpleCov はカバレッジの率を報告するだけ

- `Gemfile` の test group に `simplecov`（`require: false`）を足し、`Gemfile.lock` を更新する
- `spec/spec_helper.rb` の先頭で、環境変数 `COVERAGE` があるときだけ `require "simplecov"` と `SimpleCov.start "rails"` を走らせる。`COVERAGE` が無いときは SimpleCov を読み込まず、`coverage/` を作らない
- しきい値（`minimum_coverage` など）は付けない。率で rspec の合否は変わらない
- `.gitignore` に `/coverage/` を足す
- `ci.yml` の `rspec` ジョブの `env` に `COVERAGE: "true"` を足し、rspec のステップの後に `coverage/.last_run.json` の率を `$GITHUB_STEP_SUMMARY` に書くステップを 1 つ足す。このステップは既定の `if`（それまでのステップが成功したとき）で走る

#### REQ-002: Brakeman が警告を見つけたらジョブが落ちる

- `Gemfile` の development group に `brakeman`（`require: false`）を足し、`Gemfile.lock` を更新する
- `ci.yml` に新ジョブ `brakeman` を足す: `ruby:4.0.0` コンテナ、checkout（SHA 固定、`persist-credentials: false`）、`actions/cache`（SHA 固定、`rspec`・`checks` と同じキー）、`bundle install`、`bin/bundle exec brakeman --no-pager`
- 警告が 1 件でもあれば終了コードが 0 以外になり、ジョブが落ちる（Brakeman の既定のまま）

#### REQ-003: 既存のジョブとワークフローを変えない

- `ci.yml` の `rspec`・`checks` のジョブ名と合否の条件は変えない。`rspec` に足すのは REQ-001 の環境変数 1 つと報告のステップ 1 つだけ
- 既存のワークフロー（`ci.yml` の既存ジョブ、`related-documents.yml`、`semantic-pull-request.yml`）の `uses:` のタグ参照（`@v7` など）は SHA に書き換えない

#### REQ-004: CodeQL が Ruby のコードを解析する

- `.github/workflows/codeql.yml`（ワークフロー名 `CodeQL`）を新しく作る
- 起動: `pull_request` と `push`（`branches: [main]`）。main への push は、PR の結果を比べる base の解析を code scanning に持たせるため
- `permissions`: `contents: read`、`security-events: write`
- ジョブ `analyze`（表示名 `Analyze (ruby)`）、matrix は使わない。`github/codeql-action/init`（`languages: ruby`、`build-mode: none`）→ `github/codeql-action/analyze`。どちらも SHA 固定
- 結果は code scanning に上がり、GitHub が PR に `CodeQL` のチェックを付ける

#### REQ-005: Semgrep が Rails の規則で見つけたらジョブが落ちる

- `ci.yml` に新ジョブ `semgrep`（`ubuntu-latest`、コンテナなし）を足す
- 手順: checkout（SHA 固定、`persist-credentials: false`）→ `actions/checkout` で `semgrep/semgrep-rules` を固定の SHA で `path: .semgrep-rules`・`sparse-checkout: ruby/rails`・`persist-credentials: false` で取り出し、`mv .semgrep-rules "$RUNNER_TEMP/semgrep-rules"` でワークスペースの外へ移す → `actions/setup-python`（SHA 固定、Python の版も固定）→ `pip install --require-hashes -r .github/requirements/semgrep.txt` → `semgrep scan --config "$RUNNER_TEMP/semgrep-rules/ruby/rails" --metrics=off --error`
- `.github/requirements/semgrep.in` に直接の依存（`semgrep` の版の指定）を 1 行置き、そこから全依存を hash 付きで並べた `.github/requirements/semgrep.txt` を作る
- 今の main で見つかる物は、PR 2 の中で直すか、その行に `# nosemgrep: 規則のID` を付けて外す。外す理由はコードのコメントに書き、`.claude/rules/code-comments.md` に従う
- 規則の SHA は Dependabot の対象外で、手で更新する（REQ-011 の記録の Consequences に書く）

#### REQ-006: Dependency Review が脆弱性のある依存の追加を止める

- `ci.yml` に新ジョブ `dependency-review`（`ubuntu-latest`）を足す: checkout（SHA 固定、`persist-credentials: false`）→ `actions/dependency-review-action`（SHA 固定）
- `fail-on-severity` は既定（`low`）のまま。既知の脆弱性がある依存が新しく入れば、重さによらず落ちる
- ライセンスの確かめの入力（`allow-licenses` など）は使わない
- 権限はワークフローの `contents: read` のまま。secret を使わないので Dependabot の PR でも走る

#### REQ-007: code-review-graph は報告だけで、リスクの点数では落とさない

- `.github/workflows/code-review-graph.yml`（ワークフロー名 `code-review-graph`）を `ci.yml` とは別に新しく作る
- 起動は `pull_request`、`permissions` は `contents: read` だけ。PR へのコメントは書かない（`pull-requests: write` を付けない）
- ジョブ `report`（表示名 `report`）の手順:
  1. checkout（SHA 固定、`persist-credentials: false`）
  2. base のブランチを `git fetch --no-tags --depth=1 origin "+refs/heads/${BASE_REF}:refs/remotes/origin/${BASE_REF}"` で取る（`BASE_REF` は環境変数で渡す）
  3. `actions/checkout` で `tirth8205/code-review-graph` を、本体と同じ版のタグが指す SHA で、`sparse-checkout: scripts/render_pr_comment.py`・`path: .crg-renderer`・`persist-credentials: false` で取り出し、build の前に `mv .crg-renderer "$RUNNER_TEMP/crg-renderer"` でワークスペースの外へ移す
  4. `actions/setup-python`（SHA 固定）
  5. `pip install --require-hashes -r .github/requirements/code-review-graph.txt`（`.github/requirements/code-review-graph.in` から作る hash 付きのファイル）
  6. `code-review-graph build`
  7. `code-review-graph detect-changes --base "origin/${BASE_REF}" > "$RUNNER_TEMP/crg-report.json"`
  8. `python "$RUNNER_TEMP/crg-renderer/scripts/render_pr_comment.py" --input "$RUNNER_TEMP/crg-report.json" --output "$RUNNER_TEMP/crg-comment.md"`。終了コードが 0 と 4 以外ならジョブを落とす
  9. Markdown を `$GITHUB_STEP_SUMMARY` に書く
  10. レンダラの終了コードが 4（解析が走らなかった）なら `::error::` を出してジョブを落とす
- `--fail-on-risk` に当たる処理は書かない。グラフのキャッシュは使わない（毎回 build する）
- レンダラの取り出しの SHA は Dependabot の対象外で、手で更新する。Dependabot が本体の版を上げたときに合わせる必要があることを REQ-012 の記録の Consequences に書く

#### REQ-008: 新しく持ち込む外の物はすべて不変の ID で固定する

- 新しく足す `uses:` はすべて 40 桁のコミットの SHA で書き、行末に版のコメント（例 `# v7.0.0`）を付ける
- Python の道具は hash 付き requirements から `pip install --require-hashes` で入れる。requirements の各パッケージの行は `--hash=sha256:` を持つ
- Ruby の道具は `Gemfile.lock` で固定する
- 外から取り出す規則とレンダラは `actions/checkout` の `ref:` に 40 桁の SHA を書く

#### REQ-009: Dependabot が新しく固定した物を更新する

- `.github/dependabot.yml` に `package-ecosystem: "github-actions"`（directory `/`）を PR 1 で足す
- `.github/dependabot.yml` に `package-ecosystem: "pip"`（directory `/.github/requirements`）を PR 2 で足す。PR 4 の code-review-graph の requirements も同じエントリで更新される
- どちらも既存のエントリと同じ schedule・`commit-message.prefix: "build"`・`target-branch: "main"` にする

#### REQ-010: PR を道具のまとまりごとに 4 段のスタックに分け、本文にチェック名を並べる

- git-spice の一直線のスタック（main から）にする。ブランチ名・PR の題名の type は実装の時に `git-spice-workflow` Skill の基準で決める
  1. PR 1: SimpleCov と Brakeman（REQ-001、REQ-002）と `github-actions` の Dependabot（REQ-009 の前半）
  2. PR 2: CodeQL と Semgrep（REQ-004、REQ-005）と `pip` の Dependabot（REQ-009 の後半）と決定の記録 REQ-011
  3. PR 3: Dependency Review（REQ-006）
  4. PR 4: code-review-graph（REQ-007）と決定の記録 REQ-012
- reusable workflow と matrix は使わない
- 各 PR の本文に、その PR で新しくできるチェックの表示名と、必須チェックに登録するときの名前を並べる。名前は推測で書かず、実際の PR の Checks の画面（`gh pr checks`）で確かめた物を書く。設計が見込む名前:
  - PR 1: `CI / brakeman (pull_request)`（登録名 `brakeman`）。`CI / rspec` の名前が変わらないことも書く
  - PR 2: `CodeQL / Analyze (ruby) (pull_request)`（登録名 `Analyze (ruby)`）、code scanning のチェック `CodeQL`（登録名 `CodeQL`）、`CI / semgrep (pull_request)`（登録名 `semgrep`）
  - PR 3: `CI / dependency-review (pull_request)`（登録名 `dependency-review`）
  - PR 4: `code-review-graph / report (pull_request)`（登録名 `report`。必須にしない物として書く）
- PR 本文の Related Documents は `related-documents.yml` の検査に通る形にする

#### REQ-011: 決定の記録「テストと確かめの道具の選び方」を PR 2 に入れる

- `docs/decisions/test-and-check-tool-selection.md` を新しく作り、`docs/decisions/index.md` に 1 行足す。形は `.claude/rules/decisions-maintenance.md` に従う
- Decision: PR ごとの CI の道具を SimpleCov・Brakeman・CodeQL（Ruby）・Semgrep（Rails の規則）・Dependency Review・code-review-graph にする
- Considered Options: DeepSec（採らない）、Claude Code の `/security-review` を CI に入れる（今は採らない）、Semgrep の規則をレジストリ（`p/rails`）から取る（採らない）、採用した組み合わせ。各案の長所・短所は、実装の時に各道具の公式の資料で確かめた事実（費用、API キーの要否、結果の再現性、code scanning との連携、保守の状況など）だけで書き、人の意図の推測は書かない（Open Questions の Q1）
- Consequences に、Semgrep の規則の SHA を手で更新することを書く
- Related Files は、この段までにある物（`.github/workflows/ci.yml`、`.github/workflows/codeql.yml`、`.github/dependabot.yml`、`.github/requirements/semgrep.txt` など）

#### REQ-012: 決定の記録「必須チェックにする物としない物」を PR 4 に入れる

- `docs/decisions/ci-required-and-report-only-checks.md` を新しく作り、`docs/decisions/index.md` に 1 行足す。形は `.claude/rules/decisions-maintenance.md` に従う
- Decision: 合否を返すチェック（必須チェックの候補）は `rspec`・`checks`・`brakeman`・`semgrep`・`dependency-review`・`Analyze (ruby)` と code scanning の `CodeQL`。報告だけの物は、カバレッジの率・code-review-graph（fail-on-risk を付けない）・ミューテーションテスト（入れる場合）。必須チェックへの登録はユーザーが決める
- Considered Options: カバレッジにしきい値を付ける、code-review-graph に fail-on-risk を付ける／必須にする、ミューテーションテストを必須にする、採用した形。理由は REQ-011 と同じく確かめた事実だけで書く（Open Questions の Q2）
- Consequences に、code-review-graph のレンダラの SHA を本体の版に合わせて手で更新することを書く
- Related Files は `.github/workflows/ci.yml`、`.github/workflows/code-review-graph.yml`、`spec/spec_helper.rb` など

#### REQ-013: 触らない設定と hook

- lefthook（`lefthook.yml`、`.lefthook/`）に差分を作らない
- 必須チェック（branch protection / ruleset）の設定を変えない
- 「Allow GitHub Actions to create and approve pull requests」の設定を変えない
- GitHub のリポジトリの設定（code scanning の default setup を含む）を変えない

#### REQ-014: 道具が問題を見つけたとき・解析できなかったときの扱い

- Brakeman・Semgrep・Dependency Review が問題を見つけたら、そのジョブが落ちる。必須にするかはユーザーが決める
- code-review-graph の解析が走らなかった（レンダラの終了コード 4）ときはジョブを落とす。リスクの点数では落とさない
- カバレッジの率では落とさない
- 実際の PR で `Analyze (ruby)` が落ち、原因が code scanning の default setup の有効（advanced setup の結果の取り込みの失敗）なら、設定は変えず、ユーザーに default setup を止めるよう知らせる

### Example Mapping

#### REQ-001（SimpleCov）

- 規則: `COVERAGE` があるときだけ動く
  - 例: `COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec` → 成功し、`coverage/.last_run.json` ができる。`git status` に `coverage/` は出ない
  - 例: `COVERAGE` なしで `bin/bundle exec rspec` → `coverage/` ができない
- 規則: 率で落とさない
  - 例: 率が低くても、テストが全部通れば `rspec` ジョブは成功し、Step Summary に率が出る

#### REQ-002（Brakeman）

- 規則: 警告があれば落ちる
  - 例: 今の main → 警告 0 件、終了コード 0（2026-11-18 に Brakeman 8.1.0 で確かめた）
  - 例: `params` を文字列で `where` に入れる行を足す → 終了コードが 0 以外（確かめた後で戻す）

#### REQ-005（Semgrep）

- 規則: 見つかればジョブが落ちる
  - 例: 今の main で見つかった物 → PR 2 の中で直すか、`# nosemgrep: 規則のID` と理由のコメントで外す。外した後に `semgrep` ジョブが成功する
- 規則: 規則は固定の SHA から取り、scan の対象に入れない
  - 例: 規則のディレクトリは `$RUNNER_TEMP` に移してから scan する

#### REQ-006（Dependency Review）

- 規則: 既知の脆弱性がある依存が新しく入れば落ちる
  - 例: 依存を変えない PR → 成功
  - 例: 既知の脆弱性がある版の gem を足す PR → 落ちる（確かめ方は計画で決める）

#### REQ-007（code-review-graph）

- 規則: リスクの点数では落とさない
  - 例: 高いリスクと出た PR → ジョブは成功し、Step Summary に報告が出る
- 規則: 解析が走らなければ落とす
  - 例: レンダラの終了コード 4 → `::error::` を出してジョブが落ちる（Step Summary は先に書く）
  - 例: レンダラの終了コードが 0 と 4 以外 → その場でジョブが落ちる

#### REQ-008（固定）

- 規則: 新しい `uses:` は 40 桁の SHA と版のコメント
  - 例: `uses: actions/checkout@<40 桁の 16 進> # v6.0.0` は満たす。`@v6` は満たさない
- 規則: requirements の全パッケージに hash
  - 例: スクラッチの venv で `pip install --require-hashes -r .github/requirements/semgrep.txt` が通る

#### REQ-014（default setup との衝突）

- 例: 実際の PR で `Analyze (ruby)` が「default setup が有効」の旨で落ちる → 設定は変えず、ユーザーに知らせる。PR 2 の本文にもその状態を書く

### Acceptance Criteria

1. AC-1（REQ-001、REQ-013）: PR 1 の上で、開発コンテナで `COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec` が成功し、`coverage/.last_run.json` ができ、`git status` に `coverage/` が出ない。`COVERAGE` なしでは `coverage/` ができない
2. AC-2（REQ-002）: 開発コンテナで `bin/bundle exec brakeman --no-pager` が 0 で終わる。わざと危ない行を足すと 0 以外で終わる（確かめた後で戻す）
3. AC-3（REQ-003、REQ-008）: 新しく足した `uses:` と `ref:` がすべて 40 桁の SHA で書かれ、`uses:` に版のコメントがある（`grep` で確かめる）。既存の `uses:` の行は変わっていない
4. AC-4（REQ-005、REQ-007、REQ-008）: `.github/requirements/*.txt` のすべてのパッケージの行が `--hash=sha256:` を持ち、スクラッチの venv で `pip install --require-hashes` が通る（開発コンテナに pip が無いので、`venv --without-pip` と `get-pip.py` などでスクラッチの場所に用意し、リポジトリは汚さない）
5. AC-5（REQ-001、REQ-002、REQ-005、REQ-006、REQ-007）: 実際の PR の上で各新ジョブが成功し、`rspec` の Step Summary にカバレッジの率、`report` の Step Summary に code-review-graph の Markdown が出る
6. AC-6（REQ-004、REQ-014）: 実際の PR の上で `Analyze (ruby)` が成功し、PR に `CodeQL` のチェックが付く。落ちた場合は REQ-014 の扱いをした
7. AC-7（REQ-005）: `semgrep` が今のコードで成功する（見つかった物は直したか、理由付きで外した）
8. AC-8（REQ-006）: `dependency-review` が成功する。脆弱性のある版の gem を足すと落ちることを、捨てる PR かローカルの確かめで見た（方法は計画で決める）
9. AC-9（REQ-011、REQ-012）: `docs/decisions/` に新しい決定が 2 ファイルあり、それぞれ REQ-010 の段（PR 2、PR 4）に入っていて、`index.md` から辿れ、`checks` ジョブの `check-docs.sh` が通る
10. AC-10（REQ-003、REQ-013）: `lefthook.yml` と `.lefthook/` に差分が無い。既存の `rspec`・`checks` のジョブ名と合否の条件が変わっていない
11. AC-11（REQ-010）: PR が 4 段の一直線のスタックで、各 PR の本文に、その PR で新しくできるチェックの表示名と登録名が、実際の Checks の画面の名前のとおりに書かれている
12. AC-12（REQ-009）: `.github/dependabot.yml` に `github-actions`（PR 1）と `pip`（PR 2、directory `/.github/requirements`）があり、既存のエントリと同じ schedule・prefix・target-branch になっている

### Out Of Scope

- ライセンスの洗い出し（tb-4txu8 / root tb-nvhlu）と、PR 本文の日本語の確かめ（tb-fph4e / root tb-t5a3w）。別の build で同時に進む
- 必須チェック（branch protection / ruleset）の設定の変更。ユーザーが後で決める
- 「Allow GitHub Actions to create and approve pull requests」の設定の変更
- lefthook（`lefthook.yml`、`.lefthook/`）の変更
- 既存の `rspec`・`checks` ジョブの合否の条件と名前の変更、既存のワークフローの Action のタグ参照を SHA に直すこと
- ミューテーションテストの道具の導入（決定の記録で「必須にしない」と書くだけ）
- カバレッジの率のしきい値、カバレッジの HTML の成果物のアップロード
- code-review-graph の PR へのコメント投稿、グラフのキャッシュ、`details` の追加の節
- CodeQL の Ruby 以外の言語（`actions` など）と、定期実行（schedule）
- PR のマージ
- code scanning の default setup の切り替えなど、GitHub のリポジトリの設定の変更

### Open Questions

- **Q1（人の答えが要る。仮定で進める）**: 「DeepSec をやめて CodeQL と Semgrep にした理由は何か。また、Claude Code の `/security-review` を今は CI に入れない理由は何か。」
  - 記録が `docs/decisions/`・`.claude/plans/`・`.claude/tech-debt/`・bead・claude-mem に見つからない。仮定: REQ-011 の記録には公式の資料で確かめた事実だけを長所・短所として書き、人の意図の推測は書かない。PR 2 の本文で「理由はこの事実からまとめた。意図と違えば直す」と人に確かめを頼む
- **Q2（人の答えが要る。仮定で進める）**: 「カバレッジ・ミューテーション・code-review-graph を必須にせず fail-on-risk を付けない理由として、残したい理由は何か。」
  - 仮定: Q1 と同じ扱い（REQ-012 の記録には確かめた事実だけを書き、PR 4 の本文で確かめを頼む）
- **Q3（仮定で進める）**: 「今の rspec・checks はそのまま」は、`rspec` ジョブに `COVERAGE` と報告のステップを足すことを許すか
  - 仮定: 許す。ジョブの名前と合否の条件を変えないことを「そのまま」と読む（REQ-003）
- **Q4（実装の時に確かめる）**: code scanning の default setup が有効か（この環境のトークンでは 403 で読めなかった）。扱いは REQ-014
- **Q5（実装の時に確かめる）**: Semgrep の `ruby/rails` の規則で今の main に見つかる物があるか。あわせて、`ruby/rails` のディレクトリを `--config` に渡したとき、同じ場所の規則のテスト用のファイル（`.rb` など）が規則として読まれずエラーにならないか。エラーになれば、規則の yaml だけを渡す形に変える（REQ-005 の結果は変えない）
- **Q6（仮定で進める）**: `github-actions` の Dependabot を足すと、既存の `@v7` などのタグの参照にも新しい major で更新の PR が来る。仮定: 受け入れる（既存の行は今回は書き換えない）
- **Q7（仮定で進める）**: 依頼は「今夜は PR を出すところまで」だが、workflow root の `gc.var.open_pr` は `false`（`push` は `true`）。build-base の publish の段は `open_pr=false` だと PR を開かない
  - 仮定: PR を出すことは依頼の結果に含まれ、REQ-010・AC-5・AC-6・AC-11 は実際の PR を前提にする。どの lane が git-spice で PR を出すかは planning lane が決める。この build のどの lane も PR を出さない場合、実際の PR を要する受け入れの条件（AC-5・AC-6・AC-11 と、PR 上で確かめる AC-7・AC-8）は確かめられないまま残るので、そのことを最終の報告に書き、PR を出す作業を人か mayor に引き継ぐ

### Constraints

- `docs/decisions/` は `.claude/rules/decisions-maintenance.md` の形式（1決定1ファイル、英語 kebab-case のファイル名、日本語、Status / Verification Status / Date / Related Files、Considered Options は複数案を比べたときだけ）。`docs/decisions/index.md` から辿れること。`checks` ジョブの `check-docs.sh` が通ること
- コミット・ブランチ・PR は `git-spice-workflow` Skill に従う（`gh stack` は使わない）
- 計画（`.claude/plans/`）の要否と形は planning lane が `.claude/rules/plans-maintenance.md` に従って決める
- `coverage/` を `.gitignore` に入れる（lefthook の `pre-push` の `check-git-clean` が追跡されず無視もされないファイルで push を止めるため）
- 開発コンテナに pip / ensurepip / docker が無い。hash 付き requirements はスクラッチの場所の venv で作り、リポジトリを汚さない
- Semgrep の規則はリポジトリに写さない（Semgrep Rules License v1.0）

### Accepted Design

承認済みの設計（design-candidate.md）の方式 A をそのまま採る: 道具の CLI を CI のステップで直接走らせ、外の物はすべて不変の ID で固定し、PR は 4 段の一直線のスタックにする。採らなかった方式は、公式の Action を SHA で固定して使う案（code-review-graph の中の Action と PyPI の本体、Semgrep のレジストリの規則が浮く）と、1 本の PR にまとめる案（依頼の「まとまりごと」に反する）。道具ごとの小さな選択（SimpleCov は既存の `rspec` ジョブで `COVERAGE` のときだけ、Brakeman は Gemfile、Semgrep の本体は hash 付き requirements で規則は SHA 固定、code-review-graph は Step Summary とレンダラの SHA 固定）は Behavior Requirements に反映した。

### Testing Expectations

- ローカル（開発コンテナ）で確かめる: AC-1、AC-2、AC-3、AC-4、AC-9 の `check-docs.sh`、AC-10、AC-12
- 実際の PR の上で確かめる: AC-5、AC-6、AC-7、AC-8、AC-11
- 確かめのためにわざと足した危ない行・脆弱性のある gem は、確かめた後で戻し、コミットに残さない
- Semgrep は開発コンテナで走らせられないため、今の main での結果は PR 2 の CI で初めて分かる。見つかった物の扱いは REQ-005

### Risks

- code scanning の default setup が有効だと `Analyze (ruby)` が落ちる（REQ-014、Q4）
- Semgrep の `ruby/rails` で今の main に見つかる物が多いと、PR 2 の作業が増える（Q5）
- 規則とレンダラの SHA は Dependabot の対象外で、手で更新しないと古くなる。特にレンダラは本体の版とずれると動かない可能性がある（REQ-011・REQ-012 の Consequences に書く）
- `github-actions` の Dependabot が既存のタグ参照にも更新の PR を出す（Q6）
- 決定の記録の理由が人の意図と違う可能性がある（Q1、Q2。PR で確かめを頼む）
- PR を出す lane が決まっていないと、実際の PR を要する受け入れの条件が確かめられない（Q7）

### Spec Self-Review

- プレースホルダ: 空欄・未定の節は無い。`規則のID`・`<40 桁の 16 進>` は実装の時に決まる値の書き方の例で、要件の空欄ではない。ブランチ名・PR 題名の type は `git-spice-workflow` Skill で決めると明記した
- 内部の一貫性: REQ-010 の段の割り当てと REQ-009・REQ-011・REQ-012 の段が一致している。チェック名の一覧は REQ-012 の合否を返すチェックの一覧と一致している
- 範囲: 1 つの計画で扱える大きさ（4 段のスタック）。別の build の作業（ライセンス、PR 本文の日本語）は Out Of Scope に置いた
- 曖昧さ: 「今の rspec はそのまま」（Q3）、PR を誰が出すか（Q7）の二通りの読み方を仮定として明記した

### Coverage

| ID | Status | 要件 |
| --- | --- | --- |
| REQ-001 | covered | SimpleCov はカバレッジの率を報告するだけ |
| REQ-002 | covered | Brakeman が警告を見つけたらジョブが落ちる |
| REQ-003 | covered | 既存のジョブとワークフローを変えない |
| REQ-004 | covered | CodeQL が Ruby のコードを解析する |
| REQ-005 | covered | Semgrep が Rails の規則で見つけたらジョブが落ちる |
| REQ-006 | covered | Dependency Review が脆弱性のある依存の追加を止める |
| REQ-007 | covered | code-review-graph は報告だけで、リスクの点数では落とさない |
| REQ-008 | covered | 新しく持ち込む外の物はすべて不変の ID で固定する |
| REQ-009 | covered | Dependabot が新しく固定した物を更新する |
| REQ-010 | covered | PR を 4 段のスタックに分け、本文にチェック名を並べる |
| REQ-011 | covered | 決定の記録「テストと確かめの道具の選び方」を PR 2 に入れる |
| REQ-012 | covered | 決定の記録「必須チェックにする物としない物」を PR 4 に入れる |
| REQ-013 | covered | 触らない設定と hook |
| REQ-014 | covered | 道具が問題を見つけたとき・解析できなかったときの扱い |

## Adopted design

## 設計候補: テストと確かめの道具を CI に入れる（tascon-backend）

- 対象: tb-wtiom（HQ 依頼 gc-n91n の部分 2）、workflow root tb-u5bv6
- 設計の版: iteration 1（brainstorm bead tb-jdzkc）
- 承認の方式: autonomous（`gc.var.brainstorming_approval_mode=autonomous`）
- 承認の状態: **承認済み**（2026-11-18、design approval lane tb-dq4pf が autonomous で承認。判定は brainstorming/approval-summary.md）

### Superpowers checklist（1〜5）の記録

1. プロジェクトの文脈を調べた: 済（下の「調べた事実」）
2. Visual Companion: 不要と判断。見た目の問いが無い（CI の設定と決定の記録だけ）ため、申し出ていない
3. 確認の問い: 自律の実行のため人には聞いていない。依頼文と文脈で決まらない点は「未解決の問い」に問いの文のまま残し、仮定を置いて先へ進めた
4. 2〜3 の方式と比べ: 済（「方式の比べ」）
5. 推す設計を節に分けて示した: 済（「設計」）

### 求められている結果

依頼 tb-wtiom の原文の要点（今夜は PR を出すところまで。PR はまとまりごとに分ける）:

- SimpleCov を入れる。率は報告だけで合否にしない
- Brakeman を PR ごとの CI に入れる
- 今の rspec・checks はそのまま
- CodeQL（Ruby）、Semgrep（Rails の決まり）、Dependency Review Action（PR で新しく入る依存の既知の脆弱性を止める）を PR ごとの CI に入れる。外の Action はコミットの ID で固定する
- code-review-graph（tirth8205/code-review-graph）を報告だけの CI として入れる。fail-on-risk は付けない、必須にしない、「Allow GitHub Actions to create and approve pull requests」の設定は変えない。Action を SHA で固定しても中の Action と PyPI の本体の版が固定されないので、固定の仕方を決めて入れる
- 新しく作るジョブの、実際に表示される名前（呼び出し側・呼ばれる側・matrix を含む）を PR の本文に一覧にする。必須チェックの設定は変えない
- 決めた理由を、その道具を入れる PR の中で `docs/decisions/` に残す（1決定1ファイル）:
  - テストと確かめの道具の選び方（DeepSec をやめて CodeQL と Semgrep にした理由、Claude Code の `/security-review` を今は入れない理由を Considered Options に）
  - 必須チェックにする物としない物（ミューテーション・カバレッジ・code-review-graph を必須にせず fail-on-risk を付けない理由）
- 今の backend の hook（lefthook）の動きは変えない

### 範囲外（non-goals）

- ライセンスの洗い出し（tb-4txu8 / root tb-nvhlu）と、PR 本文の日本語の確かめ（tb-fph4e / root tb-t5a3w）。別の build で同時に進む
- 必須チェック（branch protection / ruleset）の設定の変更。ユーザーが後で決める
- 「Allow GitHub Actions to create and approve pull requests」の設定の変更
- lefthook（`lefthook.yml`、`.lefthook/`）の変更
- 既存の `rspec`・`checks` ジョブの合否の条件と名前の変更、既存のワークフロー（`ci.yml` の既存ジョブ、`related-documents.yml`、`semantic-pull-request.yml`）の Action の参照（`@v7` などのタグ）を SHA に直すこと
- ミューテーションテストの道具の導入（決定の記録で「必須にしない」と書くだけ）
- カバレッジの率のしきい値、カバレッジの HTML の成果物のアップロード
- code-review-graph の PR へのコメント投稿、グラフのキャッシュ、`details` の追加の節
- CodeQL の Ruby 以外の言語（`actions` など）と、定期実行（schedule）

### 制約

- リポジトリのルール: `docs/decisions/` は `.claude/rules/decisions-maintenance.md` の形式（1決定1ファイル、英語 kebab-case のファイル名、日本語、Status / Verification Status / Date / Related Files、Considered Options は複数案を比べたときだけ）。`docs/decisions/index.md` から辿れるようにする。`checks` ジョブの `check-docs.sh` が通ること
- コミット・ブランチ・PR は `git-spice-workflow` Skill に従う（`gh stack` は使わない）。PR 本文の Related Documents は `related-documents.yml` の検査に通ること。計画（`.claude/plans/`）の要否と形は planning lane が `.claude/rules/plans-maintenance.md` に従って決める（前例: `.claude/plans/active/git-spice-merge-and-ci-gates.md` は「Spec: N/A（設計と要件は Gas City の build の成果物にあり…）」の形）
- 既存の CI の型: `ci.yml`（ワークフロー名 `CI`、`on: pull_request`、`permissions: contents: read`、`ruby:4.0.0` コンテナ、`actions/cache` で `/usr/local/bundle`、checkout は `persist-credentials: false`）。新しいジョブもこの型に合わせる
- lefthook の `pre-push` の `check-git-clean` は、追跡されず無視もされないファイルがあると push を止める。SimpleCov が作る `coverage/` は `.gitignore` に入れる必要がある（入れないと、手元で `COVERAGE` を付けて rspec を走らせた後の push が止まる）
- 開発コンテナに pip / ensurepip / docker が無い（`python3 -m venv` が失敗する）。Python の道具の固定ファイル（hash 付き）を作るときは、スクラッチの場所に `venv --without-pip` + `get-pip.py` などで pip を用意する。リポジトリは汚さない

### 調べた事実（2026-11-18）

- `P-manBrown/tascon-backend` は public。CodeQL（code scanning）と Dependency Review は public のリポジトリで追加の契約なしに使える
- code scanning の default setup の有無と branch protection は、この環境のトークンでは 403 で読めなかった（未確認）
- Brakeman 8.1.0 を一時の GEM_HOME で今の main に走らせた結果: Security Warnings 0、Errors 0（Rails 8.1.3）
- Semgrep は開発コンテナに入れられず、今の main での結果は未確認（PyPI の最新は 1.186.0）
- semgrep/semgrep-rules: `ruby/rails/{correctness,performance,security}` がある。ライセンスは Semgrep Rules License v1.0（自分の内部の用途での利用は可、規則の再配布は不可と読める。リポジトリに規則を写さず、CI で取り出して使うだけにする）
- code-review-graph: 最新 v2.4.0（2026-11-11、PyPI も 2.4.0）、MIT。Ruby を解析できる。公式の composite Action（`action.yml`）は、中で `actions/setup-python@v7`・`actions/cache@v6` をタグで参照し、`python -m pip install code-review-graph` を版の指定なしで走らせる（公式の docs/GITHUB_ACTION.md も「タグや SHA で固定しても本体は固定されない」と書いている）。Action の流れは build → `detect-changes --base origin/<base>` → `scripts/render_pr_comment.py` で Markdown → コメント投稿。render が終了コード 4（解析が走らなかった）ならジョブを落とす。`fail-on-risk` の既定は `none`。レンダラ `scripts/render_pr_comment.py` は Action のリポジトリにあり、PyPI のパッケージの CLI ではない
- 既存の記録: DeepSec と `/security-review` を CI に入れない理由を書いた記録は、`docs/decisions/`・`.claude/plans/`・`.claude/tech-debt/`・bead・claude-mem のどこにも見つからなかった。`docs/decisions/security-review-every-run.md` は手元の `/security-review` の実行の方針（Deprecated）で、CI の話ではない
- lefthook は rspec を走らせない（rubocop・htmlbeautifier・debride・docs の確かめなど）

### 方式の比べ

#### 全体の方式

- **A（推す）: CLI を CI のステップで直接走らせ、外の物はすべて不変の ID で固定する。PR は道具のまとまりごとに 4 段の一直線のスタック**
  - Action は SHA で固定（Dependabot の `github-actions` で更新）。Python の道具（Semgrep、code-review-graph）は版と hash を固定した requirements ファイルから `pip install --require-hashes` で入れる（Dependabot の `pip` で更新）。Ruby の道具（SimpleCov、Brakeman）は Gemfile.lock で固定（既存の Dependabot の `bundler` で更新）
  - 長所: 依頼の「固定の仕方を決めて入れる」を道具ごとの例外なしに満たす。中で何が走るかがリポジトリの中に全部見える。結果の再現性がある
  - 短所: 公式の Action をそのまま使うより、ワークフローと固定ファイルが増える。code-review-graph の Action が将来足す機能を自動では受け取らない
- **B: 公式の Action を SHA で固定して使う（code-review-graph の composite Action、Semgrep はレジストリの `p/rails`）**
  - 長所: 書く量が最小
  - 短所: code-review-graph の中の Action と PyPI の本体が浮く（依頼が問題にしている点そのもの）。Semgrep の規則も日々変わり、コードを変えていない PR が急に落ちうる。依頼を満たさない
- **C: 全部を 1 本の PR・1 つのワークフローに入れる**
  - 長所: スタックの操作が要らない
  - 短所: 依頼の「PR はまとまりごとに分ける」に反する。決定の記録を「その道具を入れる PR の中で」残す指示とも合わない

#### 道具ごとの小さな選択

- SimpleCov の報告の場所: **既存の `rspec` ジョブの中で取る（推す）**。別ジョブで rspec をもう一度走らせる案は、DB 付きのテストを 2 回走らせ遅くなる。`rspec` ジョブの名前と合否の条件は変えず、環境変数 1 つと報告のステップ 1 つを足すだけにする（「今の rspec はそのまま」の読み方は「未解決の問い」Q3 に残す）
- SimpleCov を動かす条件: **環境変数 `COVERAGE` があるときだけ（推す）**。常に動かす案は、手元の rspec・guard の出力と速さを変え、`coverage/` が手元に毎回できる
- Brakeman: **Gemfile の development group に入れ、`ci.yml` の新ジョブで `bundle exec brakeman`（推す）**。`gem install` で CI だけに入れる案は、版が Gemfile.lock で固定されず Dependabot も更新しない
- Semgrep の規則: **semgrep/semgrep-rules を SHA で固定して取り出し、`ruby/rails` を使う（推す）**。レジストリの `p/rails` は設定が 1 行で済むが、規則の版が固定されず、ネットワーク越しの取得に頼る
- Semgrep の本体: **hash 付き requirements（推す）**。`semgrep/semgrep` のコンテナを digest で固定する案は、Alpine 系のコンテナで JavaScript の Action（checkout）が動くかを別に確かめる必要があり、Python の道具の固定の仕方が 2 通りになる
- code-review-graph の報告の場所: **ジョブの Step Summary（推す）**。PR へのコメントは `pull-requests: write` が要り、権限が増える。報告だけの目的には Summary で足りる
- code-review-graph の固定: **本体は hash 付き requirements、レンダラは tirth8205/code-review-graph を本体と同じ版のタグの SHA で取り出す（推す）**。composite Action を SHA で固定し、その前に同じ Python に固定版を先に入れて `pip install` を空振りさせる案は、中の `setup-python@v7`・`cache@v6` がタグのまま残り、Action の内部の作りに頼る

### 設計

#### 1. 全体の形（4 段のスタック、すべて main から一直線）

1. `ci/add-simplecov-and-brakeman`: SimpleCov と Brakeman。SHA 固定の Action が初めて入る段なので、`dependabot.yml` の `github-actions` もこの段で足す
2. `ci/add-codeql-and-semgrep`: CodeQL（Ruby）と Semgrep。決定の記録「テストと確かめの道具の選び方」を足す。`dependabot.yml` に Semgrep の requirements の `pip` を足す
3. `ci/add-dependency-review`: Dependency Review
4. `ci/add-code-review-graph-report`: code-review-graph の報告だけのワークフロー。決定の記録「必須チェックにする物としない物」を足す。`dependabot.yml` に code-review-graph の requirements の `pip` を足す

ブランチ名・PR の題名の type は実装の時に `git-spice-workflow` Skill の基準で決める（上は案）。各 PR の本文に、その PR で新しくできるチェックの表示名の一覧を書く（6 節）。

#### 2. SimpleCov と Brakeman（PR 1）

- `Gemfile`: test group に `simplecov`（`require: false`）、development group に `brakeman`（`require: false`）。`Gemfile.lock` を更新
- `spec/spec_helper.rb` の先頭（アプリのコードより前に読み込まれる場所。`.rspec` が `--require spec_helper`）で、`ENV["COVERAGE"]` があるときだけ `require "simplecov"` と `SimpleCov.start "rails"`。しきい値（`minimum_coverage` など）は付けない
- `.gitignore` に `/coverage/`
- `ci.yml` の `rspec` ジョブ: `env` に `COVERAGE: "true"`。rspec のステップの後に「カバレッジの率を Step Summary に書く」ステップを 1 つ（`coverage/.last_run.json` の率を `ruby -rjson` で読み、`$GITHUB_STEP_SUMMARY` に書く）。このステップは rspec が成功したときだけ走る（既定の `if`）。ジョブの名前 `rspec` と合否の条件は変わらない
- `ci.yml` に新ジョブ `brakeman`: `ruby:4.0.0` コンテナ、checkout（SHA 固定、`persist-credentials: false`）、`actions/cache`（SHA 固定、既存と同じキー）、`bundle install`、`bin/bundle exec brakeman --no-pager`。警告が 1 件でもあれば終了コードが 0 以外になりジョブが落ちる（Brakeman の既定）。今の main は警告 0 件
- `dependabot.yml` に `package-ecosystem: "github-actions"`（directory `/`、既存と同じ schedule・`commit-message.prefix: "build"`・`target-branch: "main"`）
- 新しく足す `uses:` は SHA で固定し、行末に版のコメント（例 `# v7.0.0`）を付ける。既存のジョブの `@v7` などは変えない

#### 3. CodeQL と Semgrep（PR 2）

- `.github/workflows/codeql.yml`（ワークフロー名 `CodeQL`）
  - `on: pull_request` と `push: branches: [main]`。main への push でも走らせるのは、PR の結果を比べる基準（base の解析）を code scanning に持たせるため
  - `permissions`: `contents: read`、`security-events: write`
  - ジョブ `analyze`（名前 `Analyze (ruby)`）、matrix は使わない。`github/codeql-action/init`（`languages: ruby`、`build-mode: none`）→ `github/codeql-action/analyze`。どちらも SHA 固定（CodeQL の本体の版は Action の版に結び付くため、Action の SHA で固定される）
  - 結果は code scanning に上がり、GitHub が PR に `CodeQL` のチェックを付ける（アラートの重さで落ちる）。ジョブ `Analyze (ruby)` 自体は解析が走れば成功する
- Semgrep: `ci.yml` に新ジョブ `semgrep`（`ubuntu-latest`、コンテナなし）
  - checkout（SHA 固定、`persist-credentials: false`）
  - `actions/checkout` で `semgrep/semgrep-rules` を固定の SHA で `path: .semgrep-rules`、`sparse-checkout: ruby/rails` に取り出し（`persist-credentials: false`）、`mv .semgrep-rules "$RUNNER_TEMP/semgrep-rules"` でワークスペースの外へ移す（scan の対象に入れないため）
  - `actions/setup-python`（SHA 固定、Python の版も固定）
  - `pip install --require-hashes -r .github/requirements/semgrep.txt`（`semgrep==<版>` と全依存を hash 付きで並べたファイル。`.github/requirements/semgrep.in` に直接の依存 1 行を置き、`pip-compile --generate-hashes` などで作る）
  - `semgrep scan --config "$RUNNER_TEMP/semgrep-rules/ruby/rails" --metrics=off --error`（見つかれば 0 以外で終わり、ジョブが落ちる）。規則の SHA は手で更新する（`ref:` は Dependabot の対象外）。決定の記録の Consequences に書く
  - 今の main で見つかる物があれば、この PR の中で直すか、行ごとの `# nosemgrep: <rule-id>` で外す（外す理由はコードのコメントに書く。`.claude/rules/code-comments.md` に従う）
- `dependabot.yml` に `package-ecosystem: "pip"`、directory `/.github/requirements`
- 決定の記録 `docs/decisions/test-and-check-tool-selection.md`（新規）と `docs/decisions/index.md` への 1 行
  - Decision: PR ごとの CI で使う道具を、SimpleCov（カバレッジの報告）・Brakeman（Rails の静的解析）・CodeQL（Ruby）・Semgrep（Rails の規則）・Dependency Review（PR で入る依存の既知の脆弱性）・code-review-graph（変更の影響の報告）にする
  - Considered Options: DeepSec（採らない）、Claude Code の `/security-review` を CI に入れる（今は採らない）、Semgrep の規則をレジストリから取る（採らない）、採用した組み合わせ。各案の長所・短所を書く。DeepSec と `/security-review` の理由は「未解決の問い」Q1・Q2 の扱いに従う
  - Related Files: `.github/workflows/ci.yml`、`.github/workflows/codeql.yml`、`.github/dependabot.yml`、`.github/requirements/semgrep.txt` など、この段までにある物

#### 4. Dependency Review（PR 3）

- `ci.yml` に新ジョブ `dependency-review`（`ubuntu-latest`）: checkout（SHA 固定、`persist-credentials: false`）→ `actions/dependency-review-action`（SHA 固定）。`fail-on-severity` は既定（`low`。既知の脆弱性がある依存が新しく入れば重さによらず落とす）。ライセンスの確かめの入力は使わない（ライセンスは別の作業）
- 権限はワークフローの `contents: read` のまま（public のリポジトリで足りる）
- Dependabot の PR でも走る（secret を使わない）

#### 5. code-review-graph（PR 4）

- `.github/workflows/code-review-graph.yml`（ワークフロー名 `code-review-graph`）。合否の関門ではないことが分かるよう、`ci.yml` とは別のファイルにする
  - `on: pull_request`、`permissions: contents: read` だけ（コメントを書かないので `pull-requests: write` は要らない）
  - ジョブ `report`（名前 `report`）: checkout（SHA 固定、`persist-credentials: false`）→ base のブランチを `git fetch --no-tags --depth=1 origin "+refs/heads/${BASE_REF}:refs/remotes/origin/${BASE_REF}"`（`BASE_REF` は環境変数で渡す。公式の Action と同じ）→ `actions/checkout` で `tirth8205/code-review-graph` を本体と同じ版のタグの SHA で、`sparse-checkout: scripts/render_pr_comment.py`（標準ライブラリだけを使う 1 ファイル。2026-11-18 に import を確かめた）、`path: .crg-renderer`、`persist-credentials: false` で取り出し、build の前に `mv .crg-renderer "$RUNNER_TEMP/crg-renderer"` でワークスペースの外へ移す（解析の対象に入れないため）→ `actions/setup-python`（SHA 固定）→ `pip install --require-hashes -r .github/requirements/code-review-graph.txt`（`code-review-graph==<版>` と全依存の hash）→ `code-review-graph build` → `code-review-graph detect-changes --base "origin/${BASE_REF}" > "$RUNNER_TEMP/crg-report.json"` → `python "$RUNNER_TEMP/crg-renderer/scripts/render_pr_comment.py" --input "$RUNNER_TEMP/crg-report.json" --output "$RUNNER_TEMP/crg-comment.md"`、終了コードが 0 と 4 以外なら落とす → Markdown を `$GITHUB_STEP_SUMMARY` に書く → 終了コード 4（解析が走らなかった）なら `::error::` を出して落とす
  - fail-on-risk に当たる処理（`--fail-on-risk`）は書かない。リスクの点数でジョブは落ちない
  - グラフのキャッシュは使わない（毎回 build）
- `dependabot.yml` の `pip` の directory は PR 2 と同じ `/.github/requirements`（同じエントリで両方のファイルを更新する）
- レンダラの取り出しの SHA は手で更新する（`ref:` は Dependabot の対象外）。本体の版を Dependabot が上げたときに合わせる必要があり、決定の記録の Consequences に書く
- 決定の記録 `docs/decisions/ci-required-and-report-only-checks.md`（新規）と `docs/decisions/index.md` への 1 行
  - Decision: 合否を返すチェック（必須チェックの候補）は `rspec`・`checks`・`brakeman`・`semgrep`・`dependency-review`・`Analyze (ruby)` と code scanning の `CodeQL`。報告だけにする物は、カバレッジ（SimpleCov の率）・code-review-graph（fail-on-risk を付けない）・ミューテーションテスト（入れる場合）。必須チェックへの登録はユーザーが決める
  - Considered Options: カバレッジにしきい値を付ける、code-review-graph に fail-on-risk を付ける／必須にする、ミューテーションテストを必須にする、採用した形。理由は「未解決の問い」Q1 と同じ扱い
  - Related Files: `.github/workflows/ci.yml`、`.github/workflows/code-review-graph.yml`、`spec/spec_helper.rb` など

#### 6. PR 本文のジョブ名の一覧

reusable workflow（呼び出し側・呼ばれる側）と matrix は使わない。各 PR の本文に、その PR で新しくできる物を次の形で並べる（Checks の画面の表示名と、必須チェックに登録するときの名前）:

- PR 1: `CI / brakeman (pull_request)`（登録名 `brakeman`）。`CI / rspec` は名前が変わらないことも書く
- PR 2: `CodeQL / Analyze (ruby) (pull_request)`（登録名 `Analyze (ruby)`）、code scanning のチェック `CodeQL`（登録名 `CodeQL`）、`CI / semgrep (pull_request)`（登録名 `semgrep`）
- PR 3: `CI / dependency-review (pull_request)`（登録名 `dependency-review`）
- PR 4: `code-review-graph / report (pull_request)`（登録名 `report`。必須にしない物として書く）

表示名は推測で書かず、実際の PR の Checks の画面（`gh pr checks` の名前）で確かめた物を書く。

#### 7. エラーの扱い

- 道具が問題を見つけたとき（Brakeman・Semgrep・Dependency Review）: そのジョブが落ちる。必須にするかはユーザーが決める
- code-review-graph が解析できなかったとき（終了コード 4）: ジョブを落とす（公式の Action と同じ。解析していない PR を「問題なし」と見せないため）。リスクの点数では落とさない
- カバレッジ: 率では落とさない
- code scanning の default setup が有効なとき: advanced setup（`codeql.yml`）の結果の取り込みが失敗する。実際の PR で `Analyze (ruby)` が落ちたら、ユーザーに default setup を止めるよう知らせる（設定の変更はしない）

#### 8. 確かめ（受け入れの条件）

1. PR 1 の上で、開発コンテナで `COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec` が成功し、`coverage/.last_run.json` ができ、`git status` に `coverage/` が出ない。`COVERAGE` なしでは `coverage/` ができない
2. 開発コンテナで `bin/bundle exec brakeman --no-pager` が 0 で終わる。わざと危ない行（例: `params` を `where` に文字列で入れる）を足すと 0 以外で終わる（確かめた後で戻す）
3. 新しく足した `uses:` がすべて 40 桁の SHA と版のコメントで書かれている（`grep` で確かめる）。既存の `uses:` は変わっていない
4. `.github/requirements/*.txt` のすべての行が `--hash=sha256:` を持ち、`pip install --require-hashes` が通る（スクラッチの venv で確かめる）
5. 実際の PR の上で、各新ジョブが成功し、`rspec` の Step Summary にカバレッジの率、`report` の Step Summary に code-review-graph の Markdown が出る
6. `Analyze (ruby)` が成功し、PR に `CodeQL` のチェックが付く
7. `semgrep` が今のコードで成功する（見つかった物は直すか、理由付きで外した）
8. `dependency-review` が成功する。脆弱性のある版の gem を足すと落ちることを、捨てる PR かローカルの確かめで見る（方法は計画で決める）
9. `docs/decisions/` に新しい決定が 2 ファイルあり、`index.md` から辿れ、`check-docs.sh` が通る
10. `lefthook.yml` と `.lefthook/` に差分が無い。既存の `rspec`・`checks` のジョブ名と合否の条件が変わっていない
11. 各 PR の本文に、6 節の名前の一覧が、実際の Checks の画面の名前のとおりに書かれている

### 自律で決めた根拠

- 道具の種類、入れる場所（PR ごとの CI）、合否にしない物（カバレッジ・code-review-graph）、固定の要求（Action は SHA、code-review-graph は中まで）、触らない物（必須チェック・PR 作成の設定・lefthook）は依頼文が決めている
- 方式の選択（4 段のスタック、CLI を直接走らせる、hash 付き requirements、Step Summary、Semgrep の規則の SHA 固定）は、依頼の「固定の仕方を決めて入れる」「PR はまとまりごと」と、既存の `ci.yml` の型（ステップを直接走らせる、Decision Log の理由）から決めた
- 決定の記録の理由のうち人の意図にあたる部分（Q1・Q2）は、記録に無いため仮定として扱い、PR で人が確かめる形にした

### 未解決の問い

- **Q1（人の答えが要る）**: 「DeepSec をやめて CodeQL と Semgrep にした理由は何か。また、Claude Code の `/security-review` を今は CI に入れない理由は何か。」
  - 記録が見つからない。仮定: 決定の記録には、実装の時に各道具の公式の資料で確かめた事実（費用、API キーの要否、結果の再現性、GitHub の code scanning との連携、保守の状況など）だけを長所・短所として書き、人の意図の推測は書かない。PR の本文で「理由はこの事実からまとめた。意図と違えば直す」と人に確かめを頼む
- **Q2（人の答えが要る）**: 「カバレッジ・ミューテーション・code-review-graph を必須にせず fail-on-risk を付けない理由として、残したい理由は何か。」
  - 仮定: Q1 と同じ扱い（確かめた事実だけを書き、PR で確かめを頼む）
- **Q3（仮定で進める）**: 「今の rspec・checks はそのまま」は、`rspec` ジョブに `COVERAGE` と報告のステップを足すことを許すか
  - 仮定: 許す。ジョブの名前と合否の条件を変えないことを「そのまま」と読む。別ジョブで rspec を 2 回走らせる案は遅くなるため採らない
- **Q4（実装の時に確かめる）**: code scanning の default setup が有効か（403 で読めなかった）。有効なら `codeql.yml` の結果の取り込みが失敗する。7 節の扱い
- **Q5（実装の時に確かめる）**: Semgrep の `ruby/rails` の規則で今の main に見つかる物があるか。あれば PR 2 の中で直すか理由付きで外す。あわせて、`ruby/rails` のディレクトリを `--config` に渡したとき、同じ場所の規則のテスト用の `.rb` などが規則として読まれずエラーにならないことを確かめる
- **Q6（仮定で進める）**: `github-actions` の Dependabot を足すと、既存の `@v7` などのタグの参照にも、新しい major が出たときに更新の PR が来る。仮定: 受け入れる（既存の行は今回は書き換えない）

## 承認の後の変更

承認の時点の要件と設計（上の2つの節）は書き換えず、その後に変えた点をここに書く。変えた経緯と決定は、計画`docs/design/plans/active/test-and-check-tools-ci.md`の`Decision Log`にある。

- この仕様の置き場所: 承認の時点の「リポジトリには写さない」を改め、この仕様と計画をリポジトリの`docs/design/`に置いた。上の節に出る作業用の置き場（`.gc-artifacts/`）のパスは、承認の時点の記録として残す
- スタックの段: REQ-010の4段に、文書だけのブランチと、`ci.yml`の`checks`をジョブに分けるブランチを、一番下に足して6段にした
- 必須チェック: 登録するのは`ci.yml`の`checks`（と`Validate PR title`）だけにした。`checks`は全部のジョブを`needs`で待つまとめ役のjobで、`if: always()`を付け、1つでも成功以外なら落ちる。REQ-003の「既存のジョブを変えない」は、job`checks`の手順をジョブに分ける変更で置き換え、名前`checks`は保った
- `checks`の`needs`に入れる物: `rspec`、分けたjob、`brakeman`（REQ-002）、`semgrep`（REQ-005）、`dependency-review`（REQ-006）。入れない物: CodeQL（REQ-004。別のワークフロー`codeql.yml`で、`needs`が待てない）、code-review-graph（REQ-007。報告だけ）
- 決定の記録（REQ-011・REQ-012）: 合否を返すチェックを、`checks`の`needs`に入れる物へ書き直した
- PRへの報告（REQ-001、REQ-003）: カバレッジの率を`rspec`のStep Summaryに書く形を改め、PRへの報告は、まとめ役のワークフロー`.github/workflows/report.yml`（ワークフロー`PR report`、job`comment`）が1つのコメントに書き、同じコメントを上書きする形にした。`rspec`は、`coverage/.last_run.json`の率を短いMarkdown`coverage/pr-report.md`に書き、成果物`pr-report-10-coverage`（`actions/upload-artifact`をSHAで固定、保持7日）として残すだけで、PRにコメントを書かない。REQ-003の「`rspec`に足すのは報告のステップ1つ」は2つ（率のMarkdownを書く・成果物として残す）になった。`report.yml`は`workflow_run`（`types: completed`、`workflows`は`CI`）で動き、`pull_request`から起きた実行だけを扱う。権限は`actions: read`・`contents: read`・`pull-requests: write`で、`pull-requests: write`を持つのはこのワークフローだけ。PRのコードは取り出さず動かさず、外のActionは使わずにランナーの`gh`・`jq`・`unzip`だけで動く。実行のコミットを先頭に持つ開いたPRだけに書き、そのコミットの`pull_request`のすべての実行から名前が`pr-report-`で始まる期限切れでない成果物を集め（同じ名前は新しい方）、名前の順に並べ、届いた分だけ載せる。印`<!-- pr-report -->`で始まる`github-actions[bot]`のコメントがあれば上書きする。必須のチェックにはしない。今あるワークフローに報告を足すときは、成果物`pr-report-<2桁の順>-<中身>`を残すステップを足すだけにし、新しいワークフローを足すときだけ`report.yml`の`workflows`に1行足す。`workflow_run`のワークフローはmainにある版だけが動くため、`report.yml`がコメントを書くことはmainへのマージ後に確かめる（AC-5のうちカバレッジの部分）。code-review-graph（REQ-007）の「PRへのコメントは書かない」もこの形にそろえ、段6で改める
