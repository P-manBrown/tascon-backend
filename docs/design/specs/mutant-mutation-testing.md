# mutant-mutation-testing specification

## Approved requirements

## 要件: tascon-backend に Mutant（ミューテーションテスト）を報告だけで入れる

- 元の設計: `/home/ruby/tascon-backend/.gc-artifacts/mutant-mutation-testing/brainstorming/design-candidate.md`（iteration 2、承認 bead tb-nbyq8、autonomous）
- 承認の要約: `/home/ruby/tascon-backend/.gc-artifacts/mutant-mutation-testing/brainstorming/approval-summary.md`
- 依頼: gc-xtys の 2 のうち tascon-backend の分（部分 tb-yxpiz）
- 設計の文書の写し: `docs/superpowers/specs/` には置かない。この段は main checkout で動いていて自分の worktree を持たず、main checkout は人が開いている場所のため、写しは作業の場所の決まりに合わない。また `docs/superpowers/` はこのリポジトリの文書の置き場所の決まりに無い。設計の文書は上の artifact のパスを正とする

### Problem Statement

tascon-backend のテストがコードの振る舞いの変化をどれだけ捕まえるかは、今は行のカバレッジ（SimpleCov）でしか見えない。依頼は「Mutant（ライセンスは MIT に決まりました）」を入れることで、mayor の notes は「Mutant を必須にするかどうかは決定の記録に従う」とし、積む先 `ci/add-code-review-graph-report`（PR #840）の決定の記録 `docs/decisions/ci-required-and-report-only-checks.md` は「ミューテーションテスト: 今は入れない。入れる場合も報告だけにする」と決めている。

したがって、PR ごとの CI で Mutant が PR の変えた Ruby のコード（`app/` の subject）にミューテーションテストを走らせ、生き残ったミューテーションを Step Summary に報告し、合否を返さない（必須チェックにしない）仕組みを入れる。手元の開発コンテナでも同じ設定で走らせられるようにする。

### W6H

- Who（誰が使う）: PR を出す開発者（人と AI のエージェント）と、PR を読むレビュアー。作るのはこの build の implementer
- What（何を作る）: `mutant-rspec` の依存、`config/mutant.yml`、`config/mutant/hooks.rb`、SimpleCov の `track_tests`、報告だけのワークフロー `.github/workflows/mutant.yml`（job `report`）、決定の記録 `docs/decisions/mutation-testing-with-mutant.md` と `docs/decisions/index.md` の 1 行、`.gitignore` の `/.mutant/`
- When（いつ走る）: すべての `pull_request` の CI。手元では開発者が手で走らせるとき
- Where（どこに置く）: `ci/add-code-review-graph-report`（PR #840）の上に積む 1 本のブランチ。ワークフローは `ci.yml` の外の別のファイル
- Why（なぜ）: テストの強さを見えるようにするため。合否を返さないのは決定の記録 `ci-required-and-report-only-checks.md` の「入れる場合も報告だけにする」に従うため
- Which（どの案）: 設計の案 A。テストの選び方は `context_map`、worker は `jobs: 1`、対象は `--since origin/<base>` で PR の変えた subject だけ
- How（どう動く）: 同じ job の中で `COVERAGE=true` の rspec で test ごとのカバレッジの記録を作り、変えた subject を数え、1 以上なら `COVERAGE` なしで `mutant run` を走らせ、session の結果を Step Summary に書く。session ができなかったときだけ job を落とす

### User Stories

- US-1: PR を出す開発者として、自分の PR が変えた `app/` のコードについて、テストが殺せなかったミューテーションを PR の Checks の Step Summary で見たい。テストの足りない所に気づけるようにするため
- US-2: PR を出す開発者として、Mutant の結果で PR のマージが止まらないようにしたい。報告だけと決めた決定の記録に従うため
- US-3: 開発者として、開発コンテナで CI と同じ設定で Mutant を走らせたい。PR を出す前に結果を見られるようにするため
- US-4: PR のレビュアーとして、Mutant が走らなかったこと（設定や環境の壊れ）を、生き残りと区別して知りたい。報告が空なのが「生き残りが無い」のか「走っていない」のかを取り違えないため
- US-5: リポジトリの保守者として、Mutant を報告だけで入れた理由と、採らなかった案と、手元の手順を決定の記録で辿りたい

### Technical Stories

- TS-1: implementer として、`Gemfile` の `group :test` に `gem "mutant-rspec", "~> 0.17.1", require: false` を足し、`Gemfile.lock` を更新する（`mutant` 0.17.1 と依存が入る。`parser ~> 3.3.10` は今の parser 3.3.11.1 と両立する）
- TS-2: implementer として、`config/mutant.yml` と `config/mutant/hooks.rb` を作り、`mutant environment show` で設定どおりの値が出るようにする
- TS-3: implementer として、`spec/spec_helper.rb` の `if ENV["COVERAGE"]` の中の `SimpleCov.start "rails"` に `track_tests` を足し、`coverage/coverage.json` に test ごとの記録が出るようにする
- TS-4: implementer として、`.github/workflows/mutant.yml` を作り、`ci.yml` と `lefthook.yml` と `.lefthook/` を変えずに、PR ごとに報告だけの job を走らせる
- TS-5: implementer として、決定の記録を `.claude/rules/decisions-maintenance.md` に従って足し、`docs/decisions/index.md` から辿れるようにする

### Behavior Requirements

#### REQ-001 依存と Mutant の設定

- `Gemfile` の `group :test` に `gem "mutant-rspec", "~> 0.17.1", require: false` があり、`Gemfile.lock` に `mutant` と `mutant-rspec` の 0.17.1 が入っている
- `config/mutant.yml` は次の値を持つ:
  - `usage: opensource`
  - `requires: [./config/environment]`
  - `environment_variables: { RAILS_ENV: test }`
  - `integration: { name: rspec }`
  - `matcher.subjects: [source:app/**/*.rb]`
  - `selection: { strategy: context_map }`
  - `jobs: 1`
  - `mutation: { timeout: 120.0 }`（上の段の非推奨の別名 `mutation_timeout` は使わない）
  - `hooks: [config/mutant/hooks.rb]`
- `config/mutant/hooks.rb` は `env_infection_post` で `Rails.application.eager_load!` を呼ぶ
- `.gitignore` に `/.mutant/` がある
- 設定のキーが Mutant 0.17.1 に受け付けられないときは、同じ値をコマンドの引数（`--usage opensource`・`--jobs 1` など）でワークフローと手元の手順の両方に書き、`config/mutant.yml` からそのキーを外す。`source:app/**/*.rb` で `app/` の controller と model の subject が出ないときは、`app/` の下のトップの定数の式（例: `Api*`・`Contact`）を `matcher.subjects` に並べる
- コードのコメントは `.claude/rules/code-comments.md` に従う

#### REQ-002 テストの選び方の記録（SimpleCov の `track_tests`）

- `spec/spec_helper.rb` の `if ENV["COVERAGE"]` の中の `SimpleCov.start "rails"` に `track_tests` が足されている。`COVERAGE` が無いときの振る舞い（SimpleCov が始まらない）は変えない
- `COVERAGE` 付きの rspec の後、`coverage/coverage.json` に test ごとの記録がある
- `coverage/coverage.json` に test ごとの記録が出ないときは、`SimpleCov.formatters` に `SimpleCov::Formatter::JSONFormatter` を足す
- `COVERAGE` なしの `mutant run` は `coverage/coverage.json` を上書きしない

#### REQ-003 ワークフロー `.github/workflows/mutant.yml` の形

- `on: pull_request`、`permissions: contents: read`、`defaults.run.shell: bash`
- job の ID と表示名は `report`。必須チェックに登録しない
- `container: ruby:4.0.0` と MySQL 8.4.8 の service を使い、env は `ci.yml` の job `rspec` と同じ（`RAILS_MASTER_KEY` を含む）。ただし `COVERAGE` は job の env に置かず、rspec の手順の env（または `COVERAGE=true bin/bundle exec rspec` のコマンドの前）にだけ付ける。`mutant environment subject list` と `mutant run` の手順に `COVERAGE` が入らないようにするため（REQ-002 の「`COVERAGE` なしの `mutant run` は `coverage/coverage.json` を上書きしない」）
- 手順の順: libvips を入れる → checkout → `git config --global --add safe.directory "$GITHUB_WORKSPACE"`（`ci.yml` の job `checks` と同じ。コンテナの job では、これが無いと後の `git fetch` と `--since` の git が dubious ownership で失敗する）→ PR の base のブランチ（`github.event.pull_request.base.ref`。スタックの PR では親のブランチ）を fetch（`code-review-graph.yml` と同じ形）→ gems → `bin/rails db:prepare` → `COVERAGE=true bin/bundle exec rspec` → 変えた subject を数える → 0 なら終える／1 以上なら `mutant run` → 報告を書く
- 変えた subject の数は `bin/bundle exec mutant environment subject list --since origin/<base>` の 1 行目 `Subjects in environment: <数>` から読む。`context_map` は記録を読むので、この手順は rspec の後に置く
- `mutant run` は `COVERAGE` を付けずに `bin/bundle exec mutant run --since origin/<base>` で走らせる
- `subject list --since origin/<base>` が Ruby のコードを変えない PR で失敗するときは、数える手順を `git diff --name-only origin/<base> -- 'app/**/*.rb'` が空かどうかに替え、空でなければ `mutant run` を走らせて session をそのまま報告する（subject が 0 の session も成功として扱う）

#### REQ-004 報告と合否

- 「この実行で session ができた」は、`mutant run` の後に `.mutant/results/` に session が 1 つ以上あることで見分ける（CI の job は毎回まっさらな checkout から始まり、`.mutant/` は `.gitignore` で入らないため、前の実行の session は残らない）
- `mutant run` の後、この実行で `.mutant/results/` に session ができていれば、`mutant session subject` の出力（subject ごとの生き残り/総数）を Step Summary に書く。生き残ったミューテーションの diff も、Mutant 0.17.1 の session のコマンド（`mutant session show` など）で出せる範囲で Step Summary に書く
- `mutant run` の終了コードが 0 以外でも、session があれば job は成功にする（生き残りで落とさない）
- session ができていなければ、Step Summary に「Mutant が走らなかった」と書き、job をエラーで落とす
- 変えた subject が 0 なら、Step Summary に「変えた subject は無い」と書いて job を成功で終える
- PR へのコメントは書かない（`pull-requests: write` を要求しない）

#### REQ-005 時間の上限

- 1 つのミューテーションの上限は `mutation.timeout: 120.0` 秒。時間切れのミューテーションは既定の `coverage_criteria.timeout: false` のまま生き残りとして報告に出し、job は成功にする
- job に `timeout-minutes: 30` を付ける。超えたら job は取り消されて落ちるが、必須チェックではないのでマージは止めない
- `mutation.timeout` を変える条件: 実装で新しい job の `COVERAGE=true` の rspec の手順の時間を見て、100 秒を超えていたら、その時間の 1.25 倍を 10 秒単位に切り上げた値にする。報告に時間切れのミューテーションが出て、その変更が止まらなくなる物でない（spec を手で走らせると上限内に終わる）ときも同じ式で上げる
- `timeout-minutes` を変える条件: 受け入れの条件 AC-6 の PR の上の Mutant の手順が 20 分を超えたら、job の全体の時間の 1.5 倍を 10 分単位に切り上げた値にし、決定の記録の Consequences に測った時間と一緒に書く

#### REQ-006 外から持ち込む物の固定

- Ruby の道具は `Gemfile.lock` で固定する
- 新しく足す `uses:` はすべて 40 桁の SHA と版のコメントで固定する。`actions/checkout`・`actions/cache` は `ci.yml` の job `brakeman` と同じ SHA と版のコメントにする

#### REQ-007 既存の物を変えない

- `ci.yml`・`lefthook.yml`・`.lefthook/` に差分が無い
- job `rspec`・`checks` の名前と合否の条件、必須チェックの設定、GitHub のリポジトリの設定を変えない
- Mutant をまとめ役 `checks` の needs に入れない（`ci.yml` の外に置くので needs に入りようがない）

#### REQ-008 決定の記録

- 新しい `docs/decisions/mutation-testing-with-mutant.md`（表題「ミューテーションテストを Mutant で報告だけ走らせる」）を `.claude/rules/decisions-maintenance.md` に従って書く。中身: Mutant を報告だけで入れること、`--usage opensource` の前提（このリポジトリが MIT で公開されること）、`context_map`・`jobs: 1`・`--since` を選んだ理由、別のワークフローに置いた理由、案 B（`ci.yml` に job を足して記録を artifact で渡す）・案 C（worker ごとの MySQL の DB の分離）と `expression`/`auto` を採らなかった理由
- Related Files: `config/mutant.yml`・`config/mutant/hooks.rb`・`.github/workflows/mutant.yml`・`spec/spec_helper.rb`・`Gemfile`
- Context に、`ci-required-and-report-only-checks.md` の「入れる場合も報告だけにする」に従うと書く。`ci-required-and-report-only-checks.md` の本文（「今は入れない」の行を含む）は書き換えない
- `docs/decisions/index.md` に 1 行足す

#### REQ-009 手元の手順

- 新しい決定の記録の Consequences に、手元の手順を 1 行で書く: 開発コンテナで `COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec` の後に `bin/bundle exec mutant run --since main`
- 同じ Consequences に、`COVERAGE` を付けたまま `mutant run` を走らせると記録が上書きされることを 1 行で書く
- README・ARCHITECTURE.md には書かない

#### REQ-010 ブランチと PR

- `ci/add-code-review-graph-report`（PR #840）の上の 1 段のブランチとして、リポジトリの `git-spice-workflow` Skill に従って積む
- PR の本文に次を書く: 新しいチェックの表示名と登録名（実際の Checks の画面に出る名前のとおり。見込みは `mutant / report`）、必須チェックに入れないこと（報告だけ）、MIT の LICENSE の PR（tb-cknct の (5)）が先に main に入る前提で `usage: opensource` を使うこと、Mutant の EULA 1.2 に「subscription settings に公開のリポジトリの一覧を保つ」とある事実（登録が要るかは人の判断として作業は止めない）
- PR を出す時期は mayor の notes の「朝（日本時間 07:00）まで」。PR を開くかどうかはこの build の `open_pr` の値と後の段の指示に従う
- この build は `open_pr=false`・`push=true` で流れている。build の中で PR を開かないときは、ブランチを push したうえで、上の PR の本文の案を implementation summary に書き、PR を開く人（mayor か後の段）が使えるようにする

### Example Mapping

#### 規則: 変えた subject だけを対象にする（REQ-003）

- 例 1: PR が `app/controllers/api/v1/contacts_controller.rb` の 1 つのメソッドの行を変える → `subject list --since origin/<base>` が 1 以上を出す → `mutant run` が走り、そのメソッドの subject のミューテーションだけが報告に出る
- 例 2: PR が `.github/` と `docs/` だけを変える（この build の PR 自体） → `Subjects in environment: 0` → `mutant run` を走らせず、Step Summary に「変えた subject は無い」と出て job は成功

#### 規則: 生き残りでは落とさず、走らなかったときだけ落とす（REQ-004）

- 例 3: 変えた subject のミューテーションのうち 2 つが生き残る → `mutant run` の終了コードは 0 以外 → session があるので job は成功。Step Summary に subject ごとの生き残り/総数と生き残りの diff が出る
- 例 4: Rails が読み込めない（例: わざと `config/environment` を壊した捨てるコミット） → session ができない → Step Summary に「Mutant が走らなかった」と出て job は落ちる。必須チェックではないのでマージは止まらない
- 例 5: `coverage/coverage.json` が無い（rspec の手順が記録を作れなかった） → `context_map` が失敗して session ができない → job は落ちる

#### 規則: テストは記録から選ぶ（REQ-002）

- 例 6: controller の subject のミューテーション → `context_map` がその行を通った request spec（`RSpec.describe "Contacts"` など、定数名と合わない説明の group）を選ぶ → request spec がミューテーションを殺せば「殺した」と数えられる
- 例 7: 開発者が `COVERAGE=1` を付けたまま `mutant run` を走らせる → worker の中で SimpleCov が始まり記録が上書きされる → これを避ける手順を決定の記録の Consequences に書く

#### 規則: 時間の上限（REQ-005）

- 例 8: 1 つのミューテーションが無限ループになる → 120 秒で打ち切られ、生き残りとして報告に出る。job は成功
- 例 9: 変えた subject が多く job 全体が 30 分を超える → job は取り消されて落ちる。マージは止まらない

### Acceptance Criteria

1. AC-1（REQ-002）: 開発コンテナで `COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec` の後に `coverage/coverage.json` に test ごとの記録がある
2. AC-2（REQ-001）: 開発コンテナで `bin/bundle exec mutant environment show` が `Usage: opensource`、`Integration: ...Rspec`、`Jobs: 1`、`Selection: context_map` を示し、`mutant environment subject list` に `app/` の controller と model の subject が出る
3. AC-3（REQ-001、REQ-002）: 開発コンテナで 1 つの controller の subject に `mutant run` を走らせ、request spec が選ばれて少なくとも 1 つのミューテーションを殺す
4. AC-4（REQ-002）: `COVERAGE` なしの `mutant run` の後でも `coverage/coverage.json` が上書きされていない（実行の前後で更新時刻と中身の hash が同じ）
5. AC-5（REQ-006）: 新しく足した `uses:` がすべて 40 桁の SHA で版のコメントがある。既存のワークフローの行は変わっていない
6. AC-6（REQ-003、REQ-004、REQ-005）: 実際の PR の上で `report` が成功し、Step Summary に subject ごとの結果か「変えた subject は無い」が出る。Ruby のコードを変えない PR でも成功する。この build の PR は `app/` を変えないので、subject が 0 の場合の確かめを兼ねる。subject が 1 以上の場合は AC-3 で確かめる
7. AC-7（REQ-004）: わざと Rails を読み込めなくした状態で、session ができず job が落ちることを見た。確かめ方は「捨てるコミットを PR に push して CI で見る」と「手元でワークフローと同じ手順を走らせて見る」のどちらでもよい。どちらで見たかを implementation summary に書く。捨てるコミットを使ったときは、確かめた後に取り除く
8. AC-8（REQ-007）: `ci.yml`・`lefthook.yml`・`.lefthook/` に差分が無い。job `rspec`・`checks` の名前と合否の条件が変わっていない
9. AC-9（REQ-008、REQ-009）: 新しい決定の記録が `docs/decisions/index.md` から辿れ、`check-docs.sh` が通る。Consequences に手元の手順と `COVERAGE` の注意が 1 行ずつある
10. AC-10（REQ-010）: PR が `ci/add-code-review-graph-report` の上の 1 段で、本文に新しいチェックの表示名と登録名が実際の Checks の画面の名前のとおりに書かれ、必須チェックに入れないこと（報告だけ）、LICENSE の前提、EULA 1.2 の事実が書かれている

AC-6・AC-10 と、AC-7 の「捨てるコミットを PR に push する」確かめ方は、PR があって初めて確かめられる（`mutant.yml` は `pull_request` でだけ走る）。build の中で PR が開かれないとき:

- AC-7 は「手元でワークフローと同じ手順を走らせて見る」で確かめる
- AC-6・AC-10 は implementation summary に「未確認（PR が無いため）」と書き、PR が開かれた後に確かめる手（Checks の画面で `report` の結果と Step Summary を見る、表示名と登録名を本文と比べる）を書く。ブランチが `ci/add-code-review-graph-report` の上の 1 段であることは、PR が無くても git-spice の `gs log short` で確かめて書く

#### 実装で確かめる事項（違ったときの扱いは Behavior Requirements に書いた）

- 設定のキーと式（`usage`・`matcher.subjects`・`mutation.timeout`・`selection.strategy`・`jobs`）が受け付けられるか → REQ-001
- `source:app/**/*.rb` で `app/` の subject が出るか → REQ-001
- `track_tests` で `coverage/coverage.json` に test ごとの記録が出るか → REQ-002
- subject が 0 のとき `subject list --since origin/<base>` が成功するか → REQ-003
- 生き残りの diff を出す session のコマンドが 0.17.1 にあるか。無いときは subject ごとの生き残り/総数だけを書き、diff を出せないことを決定の記録の Consequences に 1 行で書く → REQ-004
- `mutation.timeout` と `timeout-minutes` を変える条件に当たるか（時間を測る） → REQ-005

#### テストの期待

- この変更はアプリの振る舞いを変えないので、新しい RSpec の example は足さない。`COVERAGE` なしの `bin/bundle exec rspec` と `COVERAGE=1` の rspec がどちらも今と同じく通ること
- 確かめは AC-1〜AC-10 を実行して見る。各 AC について、何をどう走らせ何と比べたかを implementation summary に書く
- lefthook の pre-commit の確かめ（rubocop など）が新しい Ruby のファイル（`config/mutant/hooks.rb`）と `spec/spec_helper.rb` の変更で通ること

#### 要件の網羅

| ID | Status |
| --- | --- |
| REQ-001 | covered |
| REQ-002 | covered |
| REQ-003 | covered |
| REQ-004 | covered |
| REQ-005 | covered |
| REQ-006 | covered |
| REQ-007 | covered |
| REQ-008 | covered |
| REQ-009 | covered |
| REQ-010 | covered |

### Out Of Scope

- Mutant を必須チェックにすること、まとめ役 `checks` を作ること（部分 tb-2dqkd の作業）
- MIT の LICENSE のファイルを足すこと（部分 tb-cknct の (5)）
- 全 subject を対象にする定期の全数実行（夜間のジョブなど）
- 生き残ったミューテーションを殺すためのテストの追加・アプリのコードの変更
- worker ごとの MySQL の DB の分離（並列の実行、設計の案 C）
- PR へのコメント（`pull-requests: write` が要るため）
- `ci-required-and-report-only-checks.md` の本文の書き換え
- `docs/superpowers/specs/` への設計の文書の写し

### Open Questions

人に聞く問いは無い。設計の承認（tb-nbyq8、autonomous）で、必須にしない判断、別のワークフローに置く判断、`usage: opensource` は、依頼の原文・mayor の notes・決定の記録・Mutant の文書から決まっている。

次の 2 つは人と mayor の判断に残るが、この build の作業は止めない。PR の本文に事実として書く（REQ-010）:

- マージの順: `usage: opensource` は MIT の LICENSE（tb-cknct の (5)、まだ main に無い）を前提にする。この PR を LICENSE の PR より後にマージするかは人と mayor が決める。implementer は build の notes で mayor に知らせる
- Mutant の EULA 1.2 の「subscription settings に公開のリポジトリの一覧を保つ」に当たる登録が要るか。README と docs/commercial.md は open source では `--usage opensource` を使うとだけ書いている

計画（`.claude/plans/`）をリポジトリに置くかは、計画の段が `.claude/rules/plans-maintenance.md` に従って決める。

#### リスク

- rspec を `ci.yml` の job `rspec` と合わせて 2 回走らせる。今は spec が 7 ファイルで rspec は 95 秒
- `jobs: 1` のため、変えた subject が多い PR では遅く、30 分の上限に当たると job が落ちる（必須ではないのでマージは止まらない。REQ-005 の条件で上限を見直す）
- 間接的に振る舞いが変わった subject（定数の変更など）は `--since` で選ばれない（Mutant の docs/incremental.md の Limitations）
- fork からの PR では `RAILS_MASTER_KEY` の secret が渡らないので、job `rspec` と同じく Rails が読み込めず job が落ちる見込み。必須ではないのでマージは止まらない
- 積む先のスタックは、#806 が main に入った後に tb-2dqkd で積み直される予定。積み直しで `ci.yml` の job の形が変わっても、`mutant.yml` は別のファイルなので needs の形とは干渉しない

## Adopted design

## 設計の候補: tascon-backend に Mutant（ミューテーションテスト）を入れる

### iteration 2 で直した点（承認の要約 iteration 1 の「直すこと」1〜4）

1. 「設計 3. 決定の記録」: ファイルの名前を `docs/decisions/mutation-testing-with-mutant.md` の 1 つに決めた
2. 「設計 4. 手元での使い方」: 手で走らせる手順は新しい決定の記録の Consequences に書くと決め、理由を書いた
3. 「設計 1」の `mutation.timeout` を `120.0` 秒、「設計 2」の job の `timeout-minutes` を `30` に決め、根拠と、実装で測って変える条件を書いた
4. 「残る点」を「実装で確かめる事項」に分け、確かめた結果が予想と違うときの扱いを 1 行ずつ書いた。設定のキーと式の形、subject が 0 のときの出力は、この回に Mutant 0.17.1 の文書とソースで確かめ、「調べた事実」に足した

変えていないこと: 案 A の推奨、必須にしない判断、`context_map`・`jobs: 1`・`--since origin/<base>`、受け入れの条件 1〜10、LICENSE（tb-cknct の (5)）と EULA 1.2 の扱い

### チェックリストの状態（Superpowers brainstorming 1〜5）

1. プロジェクトの文脈を調べた: 済み（下の「調べた事実」）
2. Visual Companion: 不要と判断。CI の設定と Ruby の設定ファイルの作業で、見た目の問いが無い
3. 確かめの問い: 人に聞く問いは無い。依頼の原文、mayor の notes（tb-yxpiz）、決定の記録で決まらない点は、下の「自律で決めた点」に根拠と一緒に書いた
4. 2〜3 の案と長所・短所と推奨: 済み（「案の比較」）
5. 推奨の設計を節に分けて示した: 済み（「設計」）

### 求められている結果

依頼 gc-xtys の 2 のうち tascon-backend の分（tb-yxpiz）の原文: 「tascon-backend: Mutant（ライセンスは MIT に決まりました）」「必須にする確かめは、まとめ役の checks の needs に入れる形にしてください（依頼 gc-wisp-aaqkt4 と同じ形）」「リポジトリのルールファイルやスキルに従って作業してください」。

mayor の notes（2026-11-19 15:09Z）: 「Mutant を必須にするかどうかは決定の記録に従う」「git-spice-workflow の決まりどおり依存先の最上段 ci/add-code-review-graph-report（PR #840）の上に積む」「朝（日本時間 07:00）までに PR を出す」。

結果: PR ごとの CI で Mutant が PR の変えた Ruby のコードにミューテーションテストを走らせ、生き残ったミューテーションを Step Summary に報告する。合否は返さない（報告だけ）。手元の開発コンテナでも同じ設定で走らせられる。

### 調べた事実

- 積む先 `ci/add-code-review-graph-report`（#840）の上の `docs/decisions/ci-required-and-report-only-checks.md` の Decision: 「ミューテーションテスト: 今は入れない。入れる場合も報告だけにする」。報告だけの物の前例は code-review-graph で、別のワークフロー `.github/workflows/code-review-graph.yml` の job `report` が Step Summary に書き、解析が走らなかったときだけ落ちる
- まとめ役の形（依頼 gc-wisp-aaqkt4）: 「確かめはジョブに分けて同時に走らせ、全部のジョブを needs で待つまとめ役のジョブ checks を1つ足す」「まとめ役が待てるのは同じワークフローのファイルの中のジョブだけなので、必須にする確かめは1つのワークフローに置く」。今の `ci.yml` の `checks` はまだまとめ役ではなく、ステップを並べた job。ジョブ分けとまとめ役は部分 tb-2dqkd でこのスタックの下に入る予定（未着手）
- Mutant 0.17.1（2026-10-21 公開、4 週間前）: `mutant`・`mutant-rspec` とも required_ruby_version `>= 3.3`。README の表で Ruby 4.0 と Rails 7.2・8.0・8.1 に対応。Changelog v0.14.0 で Ruby 4.0 対応。依存の `parser ~> 3.3.10` は今の `Gemfile.lock` の parser 3.3.11.1 と両立する。`mutant-rspec` は `mutant = 0.17.1` を固定で要求する
- Mutant のライセンス: rubygems のメタデータは `Nonstandard`、リポジトリの `LICENSE` は Schirp DSO LTD の EULA。1.2 Free Project License は「Open Source License で公開され、公開のリポジトリにあるプロジェクト」に使える。README: 「Free for open source. Use `--usage opensource` for public repositories.」。docs/commercial.md: 「Running mutant on CI does not require additional subscriptions」
- tascon-backend は public（`gh repo view`: visibility PUBLIC）で、今は LICENSE のファイルが無い（licenseInfo null）。MIT の LICENSE の追加は別の依頼の部分 tb-cknct の (5)（「一番上に MIT の全文の LICENSE を足す（Copyright (c) 2023-2026 P-manBrown、THIRD_PARTY_NOTICES は作らない）」）で、まだ入っていない。依頼の「ライセンスは MIT に決まりました」は、このリポジトリのライセンスが MIT に決まり、`--usage opensource` を使う前提が揃うことを指すと読んだ
- テストの選び方（docs/test-selection.md）: 既定の `expression` は example group の説明の先頭の定数名で選ぶ。このリポジトリの spec は `spec/models/contact_spec.rb`（`RSpec.describe Contact`）以外は request spec で、説明が `"Contacts"`・`"Users"`・`"Registrations"` など controller の定数名と合わないため、`expression` では controller の subject にテストが選ばれず、ミューテーションがすべて生き残りと報告される。v0.17.0 からの `context_map` は SimpleCov 1.2.0 以上の `track_tests` の記録（`coverage/coverage.json`）から、subject の行を実際に通ったテストを選ぶ。SimpleCov は #836 の段で `COVERAGE` があるときだけ動く形で入っている
- データベース: MySQL 8.4（`config/database.yml` の test は `MYSQL_TEST_DATABASE` + `TEST_ENV_NUMBER`）、`use_transactional_fixtures = true`。Mutant の既定は CPU の数だけ worker を fork して同じ DB を使う。docs/rails.md の worker ごとの DB の分離の手順は PostgreSQL と SQLite のもので、MySQL は「CREATE DATABASE を worker ごとにして schema を読み込む」とだけ書かれている
- 結果の保存: Mutant は実行ごとに `.mutant/results/` に session を書き、`mutant session subject`（subject ごとの生き残り/総数）・`mutant session show` で読める。docs/reading-reports.md: 「At this time no machine readable output exists in the opensourced versions of mutant」
- 規模: `app/`・`lib/` の `.rb` は 38 ファイル、1251 行。`_spec.rb` は 7 ファイル
- Dependabot の `bundler`（directory `/`）は既にあり、`Gemfile` に足した gem も更新の対象になる
- 設定のキーと式の形（Mutant 0.17.1 の文書とソースで確かめた）: `usage: opensource` は `ruby/lib/mutant/usage.rb` の案内文が config の `usage` のキーとして示す。1 つのミューテーションの時間の上限は `mutation: { timeout: <秒の float> }`（docs/configuration.md、`ruby/lib/mutant/config.rb`。上の段の `mutation_timeout` は非推奨の別名）。既定の `coverage_criteria.timeout: false` では、時間切れのミューテーションは「殺した」と数えられず生き残りと出る。`matcher.subjects` の `source:lib/**/*.rb` の形の式は docs/configuration.md の例にある
- subject が 0 のとき（`ruby/lib/mutant/cli/command/environment/subject.rb`・`bootstrap.rb`）: `mutant environment subject list` は 1 行目に `Subjects in environment: <数>` を出し、続けて subject を 1 行ずつ出す。bootstrap は subject が空でも失敗しない。ただし `selection: context_map` では bootstrap の中で記録を読むので、`subject list` も `coverage/coverage.json` が無いと失敗する
- SimpleCov: 積む先の `Gemfile.lock` は simplecov 1.3.2（`track_tests` は 1.2.0 から）。`spec/spec_helper.rb` は `SimpleCov.start "rails"` で formatter を指定していない。docs/test-selection.md: 「The default HTML formatter writes it [`coverage.json`] beside its report」
- 時間: #840 の最新の CI（run 44462772248）の job `rspec` は全体 2 分 56 秒。内訳は containers の準備 34 秒、gems 21 秒、`db:prepare` 2 秒、`COVERAGE=true` の `rspec` 95 秒。既存のワークフロー（`ci.yml`・`code-review-graph.yml`）に `timeout-minutes` は無い
- 文書の置き場所: 積む先の `README.md` はフロントエンドのリポジトリの README への案内だけ。`ARCHITECTURE.md` はアプリの層・横断的な仕組み・変更時の参照先の説明だけで、開発の道具の手順は無い。道具の運用の注意は決定の記録の Consequences に書かれている（`test-and-check-tool-selection.md` の Semgrep の規則の SHA の手での更新、`ci-required-and-report-only-checks.md` の code-review-graph のレンダラの SHA）

### 制約

- 合否を返さない（決定の記録の「入れる場合も報告だけにする」）。したがってまとめ役 `checks` の needs に入れない。`ci.yml` に置くと「全部のジョブを needs で待つ」まとめ役と食い違うので、`ci.yml` の外に置く
- 外から持ち込む物は不変の ID で固定する（決定の記録 test-and-check-tool-selection の方針）: Ruby の道具は `Gemfile.lock`、Action は 40 桁の SHA と版のコメント
- 既存の job `rspec`・`checks` の名前と合否の条件、必須チェックの設定、lefthook、GitHub のリポジトリの設定は変えない
- `ci/add-code-review-graph-report`（#840）の上に 1 本のブランチとして積む。PR は朝（日本時間 07:00）までに出す（mayor の notes）
- 決定の記録は `.claude/rules/decisions-maintenance.md` に従う（1 決定 1 ファイル、有効でなくなった決定は本文を書き換えず Status だけを変える）
- コードのコメントは `.claude/rules/code-comments.md` に従う

### 範囲外

- Mutant を必須チェックにすること、まとめ役 `checks` を作ること（tb-2dqkd の作業）
- MIT の LICENSE のファイルを足すこと（tb-cknct の (5)）
- 全 subject を対象にする定期の全数実行（夜間のジョブなど）
- 生き残ったミューテーションを殺すためのテストの追加・コードの変更
- worker ごとの MySQL の DB の分離（並列の実行）
- PR へのコメント（`pull-requests: write` が要るため）

### 案の比較

#### 案 A（推奨）: 別のワークフローの報告だけの job。PR の変えた subject だけを、記録したカバレッジでテストを選び、1 worker で走らせる

- 新しいワークフロー `.github/workflows/mutant.yml`（job `report`）。code-review-graph と同じく Step Summary に書き、Mutant が走らなかったときだけ落ちる
- `--since origin/<base>` で PR が行を変えた subject だけを対象にする
- 同じ job の中で先に `COVERAGE` 付きの rspec を走らせて `coverage/coverage.json` を作り、`context_map` でテストを選ぶ
- `jobs: 1` で 1 worker にする
- 長所: 決定の記録とまとめ役の形の両方に合う。request spec が controller の subject を殺すミューテーションとして数えられる。DB の分離のコードが要らない。PR ごとの時間が変えた量に比例する
- 短所: rspec を `ci.yml` の job `rspec` と合わせて 2 回走らせる（今は spec が 7 ファイル）。1 worker なので変えた subject が多い PR では遅い。間接的に振る舞いが変わった subject（定数の変更など）は選ばれない（docs/incremental.md の Limitations）

#### 案 B: `ci.yml` に job を足し、job `rspec` のカバレッジの記録を artifact で渡す

- 長所: rspec を 1 回で済ませられる
- 短所: まとめ役が「全部のジョブを needs で待つ」形になると、報告だけの job が needs に入るか、`ci.yml` の中に needs に入らない job ができて形が崩れる。job `rspec` の合否の条件に関わる手順（artifact の upload）を足すことになる

#### 案 C: 案 A に worker ごとの MySQL の DB の分離を足して並列にする

- 長所: 変えた subject が多い PR でも速い
- 短所: Mutant の文書に MySQL の手順が無く、`CREATE DATABASE` と schema の読み込みを hooks に自分で書いて保つ必要がある。CI の DB のユーザー `ci_user` は `MYSQL_DATABASE` 以外の DB を作る権限を持たないため root の接続も要る。今の規模（1251 行）では速さの得が小さい（YAGNI）

#### テストの選び方の比較（案 A の中）

- 推奨: `context_map`（`selection.strategy: context_map`）。記録が使えないと Mutant の実行が失敗するので、記録が無いまま全部が生き残りと出ることがない
- 不採用: `expression` のまま、request spec の group に `mutant_expression` のメタデータを書く。controller とテストの対応を手で保つ必要があり、書き漏れた所は黙って生き残りと出る
- 不採用: `auto`。記録が壊れたときに黙って `expression` に落ち、報告の意味が変わる

### 設計（案 A）

#### 1. 依存と設定

- `Gemfile` の `group :test` に `gem "mutant-rspec", "~> 0.17.1", require: false` を足し、`Gemfile.lock` を更新する（`mutant` 0.17.1 と依存が入る）
- 新しい `config/mutant.yml`:
  - `usage: opensource`
  - `requires: [./config/environment]`、`environment_variables: { RAILS_ENV: test }`
  - `integration: { name: rspec }`
  - `matcher.subjects: [source:app/**/*.rb]`
  - `selection: { strategy: context_map }`
  - `jobs: 1`
  - `mutation: { timeout: 120.0 }`。根拠: 1 つのミューテーションで走るのは `context_map` が選んだ spec で、全部の spec の一部。CI の `COVERAGE=true` の全部の spec が 95 秒なので、120 秒なら普通の spec の時間で時間切れにならない。止まらなくなったミューテーション（無限ループなど）1 つの損は 120 秒で済む
  - `mutation.timeout` を変える条件: 実装で新しい job の `COVERAGE=true` の rspec の手順の時間を見て、100 秒を超えていたら、その時間の 1.25 倍を 10 秒単位に切り上げた値にする。報告に時間切れのミューテーションが出て、その変更が止まらなくなる物でない（spec を手で走らせると上限内に終わる）ときも同じ式で上げる
  - `hooks: [config/mutant/hooks.rb]`
- 新しい `config/mutant/hooks.rb`: `env_infection_post` で `Rails.application.eager_load!`（docs/rails.md の推奨。無いと subject が見つからない）
- `spec/spec_helper.rb` の `if ENV["COVERAGE"]` の中の `SimpleCov.start "rails"` に `track_tests` を足す。`coverage/coverage.json` に test ごとの記録が出ることを実装で確かめる（出ない場合は JSON の formatter を足す）
- `.gitignore` に `/.mutant/` を足す

#### 2. ワークフロー `.github/workflows/mutant.yml`

- `on: pull_request`、`permissions: contents: read`、`defaults.run.shell: bash`（既存のワークフローと同じ）
- job `report`（表示名 `report`、チェックの名前は `mutant / report` の形になる見込み。実際の名前は PR の Checks の画面で確かめる）
  - `container: ruby:4.0.0` と MySQL 8.4.8 の service、env は job `rspec` と同じ（`RAILS_MASTER_KEY` を含む）
  - `actions/checkout`・`actions/cache` は `ci.yml` の job `brakeman` と同じ SHA と版のコメントで固定する
  - 手順: libvips を入れる → checkout → base のブランチを fetch（code-review-graph と同じ形）→ gems → `bin/rails db:prepare` → `COVERAGE=true bin/bundle exec rspec`（記録を作る）→ 変えた subject を数える（`mutant environment subject list --since origin/<base>` の 1 行目 `Subjects in environment: <数>` の数を読む。記録を読むので rspec の後に置く）→ 0 なら Step Summary に「変えた subject は無い」と書いて終わる → 1 以上なら `COVERAGE` を付けずに `bin/bundle exec mutant run --since origin/<base>` を走らせ、終了コードを記録する → `.mutant/results/` に session ができていれば `mutant session subject` の出力（と生き残りの diff）を Step Summary に書く → session が無ければ「Mutant が走らなかった」としてエラーで落とす
  - Mutant の終了コードが 0 以外でも、session があれば job は成功にする（生き残りでは落とさない）
  - mutant の実行の段で `COVERAGE` を付けないのは、Mutant の worker が読み込む `spec_helper.rb` で SimpleCov が始まり、記録を上書きするのを防ぐため（docs/test-selection.md の「Keeping the recording」）
  - job に `timeout-minutes: 30` を付ける。根拠: Mutant の前の手順は job `rspec` の測った時間から約 3 分（containers 34 秒、gems 21 秒、`db:prepare` 2 秒、rspec 95 秒、fetch）で、残りの約 27 分を Mutant に充てる。上限が無いと GitHub の既定の 360 分まで runner を使い続ける。時間切れで job が取り消されると job は落ちるが、必須チェックではないのでマージは止めない
  - `timeout-minutes` を変える条件: 実装で受け入れの条件 3 の 1 つの controller の subject の `mutant run` の時間と、受け入れの条件 6 の PR の上の Mutant の手順の時間を測る。受け入れの条件 6 の Mutant の手順が 20 分を超えたら、job の全体の時間の 1.5 倍を 10 分単位に切り上げた値にし、決定の記録の Consequences に測った時間と一緒に書く

#### 3. 決定の記録

- 新しい `docs/decisions/mutation-testing-with-mutant.md`（`.claude/rules/decisions-maintenance.md` の英語 kebab-case。表題は「ミューテーションテストを Mutant で報告だけ走らせる」）: Mutant を報告だけで入れること、`--usage opensource` の前提（このリポジトリが MIT で公開されること）、`context_map` と `jobs: 1` と `--since` を選んだ理由、別のワークフローに置いた理由、案 B・C と `expression`/`auto` を採らなかった理由。Related Files は `config/mutant.yml`・`config/mutant/hooks.rb`・`.github/workflows/mutant.yml`・`spec/spec_helper.rb`・`Gemfile`
- `docs/decisions/index.md` に 1 行足す
- `ci-required-and-report-only-checks.md` の「今は入れない」の行は、`.claude/rules/decisions-maintenance.md`（本文を書き換えない）に従って変えず、新しい記録の Context でこの記録の「入れる場合も報告だけにする」に従うと書く

#### 4. 手元での使い方

- 開発コンテナで `COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec` の後に `bin/bundle exec mutant run --since main`
- この手順は新しい決定の記録 `mutation-testing-with-mutant.md` の Consequences に 1 行で書く。README・ARCHITECTURE.md には書かない。理由: README はフロントエンドのリポジトリへの案内だけで、ARCHITECTURE.md はアプリの構造だけを書く文書であり、このリポジトリでは道具の運用の注意を決定の記録の Consequences に書いている（「調べた事実」の「文書の置き場所」）
- 同じ Consequences に、`COVERAGE` を付けたまま `mutant run` を走らせると記録が上書きされること（docs/test-selection.md の「Keeping the recording」）を 1 行で書く

#### 5. エラーの扱い

- Rails が読み込めない、記録が無い（`context_map` が失敗する）、gem が入らない → session ができない → job が落ちる
- 生き残ったミューテーション → job は成功。Step Summary に出る
- 変えた subject が無い → job は成功。Step Summary に「無い」と出る
- 1 つのミューテーションが 120 秒を超える → そのミューテーションは生き残りとして報告に出る。job は成功
- job が 30 分を超える → job は取り消されて落ちる（必須ではないのでマージは止めない）

### 受け入れの条件

1. 開発コンテナで `COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec` の後に `coverage/coverage.json` に test ごとの記録がある
2. 開発コンテナで `bin/bundle exec mutant environment show` が `Usage: opensource`、`Integration: ...Rspec`、`Jobs: 1`、`Selection: context_map` を示し、`mutant environment subject list` に `app/` の controller と model の subject が出る
3. 開発コンテナで 1 つの controller の subject に `mutant run` を走らせ、request spec が選ばれて少なくとも 1 つのミューテーションを殺す
4. `COVERAGE` なしの `mutant run` の後でも `coverage/coverage.json` が上書きされていない
5. 新しく足した `uses:` がすべて 40 桁の SHA で版のコメントがある。既存のワークフローの行は変わっていない
6. 実際の PR の上で `report` が成功し、Step Summary に subject ごとの結果か「変えた subject は無い」が出る。Ruby のコードを変えない PR でも成功する
7. わざと Rails を読み込めなくした状態（捨てるコミット、または手元で同じ手順）で、session ができず job が落ちることを見た
8. `ci.yml`・`lefthook.yml`・`.lefthook/` に差分が無い。job `rspec`・`checks` の名前と合否の条件が変わっていない
9. 新しい決定の記録が `docs/decisions/index.md` から辿れ、`check-docs.sh` が通る
10. PR が `ci/add-code-review-graph-report` の上の 1 段で、本文に新しいチェックの表示名と登録名が実際の Checks の画面の名前のとおりに書かれ、必須チェックに入れないこと（報告だけ）が書かれている

### 自律で決めた点（承認の根拠）

- 必須にしない: 依頼の「必須にする確かめは checks の needs に入れる形」は必須にする物の置き方で、Mutant を必須にするかは mayor の notes が「決定の記録に従う」とし、記録は「入れる場合も報告だけにする」。したがって needs に入れない
- 別のワークフローに置く: 報告だけの前例（code-review-graph）と、まとめ役が `ci.yml` の全部の job を needs で待つ形との両立から決まる
- ライセンス: 「MIT に決まりました」と Mutant の EULA 1.2・README から、`usage: opensource` を使う
- テストの選び方・worker の数・対象: リポジトリの spec の形（request spec が中心）、DB（MySQL）、規模、Mutant の文書の推奨から決めた。人の好みで変わる選択ではないと判断した
- 人に聞く問いは無い

### 残る点（人の判断ではなく、計画・実装・PR で扱う）

- LICENSE のファイルはまだ無い（tb-cknct の (5)）。`usage: opensource` はその前提に立つので、PR の本文に「MIT の LICENSE の PR が先に main に入る前提」と書き、mayor にも notes で知らせる。この PR のマージの順は人と mayor が決める
- Mutant の EULA 1.2 には「subscription settings に公開のリポジトリの一覧を保つ」とある。README と docs/commercial.md は open source では `--usage opensource` を使うとだけ書いている。登録が要るかは人の契約上の判断なので、PR の本文に事実として書く（作業は止めない）
- 計画（`.claude/plans/`）をリポジトリに置くかは計画の段が `.claude/rules/plans-maintenance.md` に従って決める

### 実装で確かめる事項（文書・ソースで予想を立てた。実行して違ったときの扱いを決めてある）

- 設定のキーと式（`usage`・`matcher.subjects`・`mutation.timeout`・`selection.strategy`・`jobs`）: `mutant environment show` で値が設定どおりに出ることを見る。キーが受け付けられないときは、同じ値をコマンドの引数（`--usage opensource`・`--jobs 1`・`--selection context_map` など）でワークフローと Consequences の手元の手順に書き、`config/mutant.yml` からそのキーを外す
- `source:app/**/*.rb`: `mutant environment subject list` に `app/` の controller と model の subject が出ることを見る。出ないときは、`app/` の下のトップの定数の式（例: `Api*`・`Contact`）を `matcher.subjects` に並べる
- `track_tests` で `coverage/coverage.json` に test ごとの記録が出るか: 出ないときは `SimpleCov.formatters` に `SimpleCov::Formatter::JSONFormatter` を足す
- subject が 0 のとき: `subject list --since origin/<base>` が `Subjects in environment: 0` を出して成功することを、Ruby のコードを変えない PR（受け入れの条件 6）で見る。失敗するときは、数える手順を `git diff --name-only origin/<base> -- 'app/**/*.rb'` が空かどうかに替え、空でなければ `mutant run` を走らせて session をそのまま報告する（subject が 0 の session も成功として扱う）

