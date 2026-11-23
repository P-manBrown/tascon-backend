# テストと確かめの道具をPRごとのCIに入れる

Spec: docs/design/specs/test-and-check-tools-ci.md

## Context/Purpose

PRごとのCI（`.github/workflows/ci.yml`のワークフロー`CI`）には、job`rspec`と、リントやドキュメントの検査を1つにまとめたjob`checks`しかなかった。テストのカバレッジ、Railsの静的解析、コードの脆弱性の解析、PRで新しく入る依存の既知の脆弱性、変更の影響の報告がCIで見えなかった。

この計画は次の6段を、mainから一直線のスタックで入れる。必須チェックに登録するのは`checks`（と`Validate PR title`）だけにし、ほかの確かめの合否は、`ci.yml`の`checks`がまとめて引き受ける形にする。

1. `docs/add-test-and-check-tools-ci-plan-and-spec`: この計画と、承認済みの要件・設計を写した仕様`docs/design/specs/test-and-check-tools-ci.md`だけの文書のブランチ
2. `ci/run-checks-as-parallel-jobs`: `ci.yml`のjob`checks`の手順を、ジョブごとに分けて同時に走らせる。全部のジョブを`needs`で待つまとめ役のjob`checks`（`if: always()`付きで、1つでも成功以外なら落ちる）を足す。`rspec`も`needs`に入れる
3. `ci/add-simplecov-and-brakeman`: SimpleCov（環境変数`COVERAGE`があるときだけ動き、行のカバレッジの率をjob`rspec`が成果物`pr-report-10-coverage`に残すだけ）と、PRへの報告のまとめ役`.github/workflows/report.yml`と、job`brakeman`（`checks`の`needs`に入れる）。`.github/dependabot.yml`に`github-actions`を足す
4. `ci/add-codeql-and-semgrep`: `.github/workflows/codeql.yml`（job`Analyze (ruby)`。別のワークフローなので`checks`の`needs`に入れない）と、job`semgrep`（`checks`の`needs`に入れる。`semgrep/semgrep-rules`の`ruby/rails`を固定のSHAで取り出して使う）。今のmainでSemgrepが見つける8件は、行ごとの`nosemgrep`と理由のコメントで外す。`.github/dependabot.yml`に`pip`を足す。決定の記録`docs/decisions/test-and-check-tool-selection.md`を足す
5. `ci/add-dependency-review`: job`dependency-review`（`checks`の`needs`に入れる）
6. `ci/add-code-review-graph-report`: `.github/workflows/code-review-graph.yml`（job`report`。報告をStep Summaryに書くだけで、別のワークフローなので`checks`の`needs`に入れない）。決定の記録`docs/decisions/ci-required-and-report-only-checks.md`を足す

新しく持ち込む外の物は、Actionを40桁のコミットのSHA（行末に版のコメント）、Pythonの道具（Semgrep、code-review-graph）を`.github/requirements/`のhash付きのrequirements、Rubyの道具を`Gemfile.lock`で固定し、Dependabotで更新する。既存のjob`rspec`の名前と合否の条件、必須チェックに登録された名前`checks`、既存のワークフローのタグ参照、lefthook、必須チェックの設定、「Allow GitHub Actions to create and approve pull requests」の設定、GitHubのリポジトリの設定（code scanningのdefault setupを含む）は変えない。必須チェックへの登録は人が決める。

## Decision Log

- 必須チェックに登録するのは、`ci.yml`の`checks`（と`Validate PR title`）だけにする。`checks`は、全部のジョブを`needs`で待ち、`if: always()`を付け、`needs`のどれかが成功以外なら落ちるまとめ役のjobにする。`needs`が待てるのは同じワークフローのファイルの中のjobだけなので、必須にする確かめは`ci.yml`に置く。確かめをjobごとに分けて同時に走らせ、1つにまとめるこの形は、devcontainer-featuresの`test.yaml`の`all-tests`と同じにそろえた。必須にする確かめが増えても、GitHubの必須チェックの登録は変えずに済む
- `checks`の`needs`に入れるのは、`rspec`、`checks`の手順を分けたjob、`brakeman`、`semgrep`、`dependency-review`。入れないのは次の2つ。`Analyze (ruby)`（CodeQL）は、mainへのpushでも走らせて基準の解析をcode scanningに持たせるため別のワークフロー`codeql.yml`に置き、結果をcode scanningに上げるために`security-events: write`が要り、default setupが有効だと落ちうる。code-review-graphは報告だけで、必須にしない（決定の記録`docs/decisions/ci-required-and-report-only-checks.md`）。まとめ役が待てない別のワークフローの物は、必須チェックの登録を増やさない限り、合否でPRを止めない
- `checks`の手順は、リントやドキュメントの検査ごとにjobを分け、gemが要るjobだけ、既存の`actions/cache@v6`で同じキーのgemのキャッシュを使う。分ける前の`checks`と同じく、PRのhead（`github.event.pull_request.head.sha`）を取り出す。`rspec`のjobは変えない
- PRは関心事ごとに分ける。文書だけ、`checks`のjobの分割、道具ごとの追加を別のPRにする。`checks`の分割は、名前`checks`を保ったまま1つのPRで入れる。まとめ役を別のPRに分けると、その間に必須の`checks`が実際の確かめを待たなくなるため
- 道具はCLIをCIのステップで直接走らせ、外の物はすべて不変のIDで固定する。公式のActionをSHAで固定して使う案は、code-review-graphのcomposite Actionが中で`actions/setup-python@v7`・`actions/cache@v6`をタグで参照し、本体を版の指定なしで`pip install`するため、本体と中のActionが浮くので採らなかった。1本のPRにまとめる案は、依頼の「PRはまとまりごとに分ける」に反するため採らなかった
- SimpleCovは既存のjob`rspec`の中で、`COVERAGE`があるときだけ動かす。別のjobでrspecを走らせる案は、DB付きのテストを2回走らせ遅くなるため採らなかった。常に動かす案は、手元のrspec・guardの出力と速さを変え、`coverage/`が毎回できるため採らなかった。しきい値は付けず、率で合否を変えない。率は成果物`pr-report-10-coverage`に残し、`report.yml`がPRのコメントに載せる
- `spec/spec_helper.rb`のSimpleCovは`SimpleCov.parallel_tests = false`で並列の検出を切る。このリポジトリの`TEST_ENV_NUMBER`はworktreeごとのテストDBの接尾辞で、並列実行ではないため。切らないと、値が1以外の環境ではSimpleCovが報告も`coverage/.last_run.json`も書かない。手元で確かめるために`TEST_ENV_NUMBER`を`unset`する案は、接尾辞の無い共有のテストDBに当たるため採らなかった
- Brakemanは`Gemfile`のdevelopmentのgroupに入れる。CIだけで`gem install`する案は、版が`Gemfile.lock`で固定されずDependabotも更新しないため採らなかった
- Semgrepの規則は`semgrep/semgrep-rules`を固定のSHAで取り出し、リポジトリには写さない。レジストリの`p/rails`は規則の版が固定されず、コードを変えていないPRの結果が変わりうるため採らなかった。規則を写さないのは、Semgrep Rules License v1.0が規則の再配布を許さないと読めるため。規則のSHAはDependabotの対象外で、手で更新する
- Semgrepの本体とcode-review-graphの本体は、`pip-compile --generate-hashes`で作った全依存のhash付きのrequirementsから`pip install --require-hashes`で入れる。CIのPythonは、requirementsを作るPython（開発コンテナの3.13）と同じ3.13系の固定の版にする
- 今のmainでSemgrepが見つける8件は、挙動を変えずに、行ごとの`nosemgrep`と理由のコメントで外す。この計画はCIに道具を入れる作業で、アプリの挙動を変えないため
- code-review-graphのレンダラ`scripts/render_pr_comment.py`は本体と同じ版のタグのSHAで取り出す（PyPIのパッケージに含まれないため）。レンダラのSHAは手で本体の版に合わせる。報告の出し方は、次のPRへの報告のまとめ役の形に従う
- PRへの報告は、まとめ役のワークフロー`.github/workflows/report.yml`（ワークフロー`PR report`、job`comment`）が1つのコメントに書き、同じコメントを上書きする。合否を決めるワークフローと報告を分け、各ワークフローは報告を、名前が`pr-report-<2桁の順>-<中身>`の短いMarkdownの成果物として残すだけにする。`report.yml`は`workflow_run`で、きっかけの一覧（`workflows`）のワークフローの完了で動き、PRの先頭のコミットの`pull_request`のすべての実行から`pr-report-`の成果物を集め（同じ名前は新しい方）、名前の順に並べ、届いた分だけ載せる。`pull-requests: write`は`report.yml`だけに持たせ、PRのコードは取り出さず動かさない。外のActionは使わず、ランナーの`gh`・`jq`・`unzip`だけで動かす。必須のチェックにはしない。今あるワークフローに報告を足すときは成果物を残すだけで載り、新しいワークフローを足すときだけ`report.yml`の`workflows`に1行足す。Step Summaryだけに書く案は、PRから見るのに画面を何度も移る必要があるため採らなかった。各ワークフローが自分でPRにコメントする案は、PRのコードが動くjobに`pull-requests: write`を持たせることになり、コメントも道具の数だけ増えるため採らなかった。`workflow_run`のワークフローはmainにある版だけが動くため、`report.yml`は段3のPRの中では動かず、mainへのマージ後に確かめる。code-review-graph（段6）もこの形にそろえ、仕様のREQ-007は段6で改める。job`rspec`の報告の2つのステップには`continue-on-error: true`を付け、`coverage/.last_run.json`が無い・成果物を上げられないときも、テストが通ればjobと`checks`を落とさない。`report.yml`は、コメントを書く直前にPRが開いていて先頭がまだそのコミットかを確かめ直し、成果物を集める間にpushが来たときは書かない。同じhead SHAのPRが2つ開いている（同じブランチからbaseの違うPRを開いた）ときは、別のPRに書いたり成果物が混ざったりしうるが、このリポジトリのスタックでは起きないため対処せず、起きたらその時に直す。`report.yml`のconcurrencyのグループには先頭のコミットのSHAを含める。待つ実行は同じグループに1つしか残らないため、ブランチだけのグループでは、古いコミットのCIが遅れて終わると今の先頭の待つ実行を押し出し、先頭の報告が出なくなるため。
- PRへの報告の決まりは、ルール`.claude/rules/github-workflows.md`（`.github/workflows/**`が対象）に置く。`.claude/rules/lefthook-ci-placement.md`は確かめをlefthookとCIのどちらに置くかの振り分けを決めるルールで、報告の決まりはワークフローの書き方にあたるため、別のファイルにした。「`uses:`は40桁のSHAで固定する」をルールに足す案は、比較テストで変更前から新しい`uses:`をSHAで固定したため足さず、既存のタグ参照は技術的負債`docs/tech-debt/active/github-actions-tag-references.md`に記録した
- job`dependency-review`は`actions/dependency-review-action`をv5.0.0のSHAで固定し、`with:`は付けない。`fail-on-severity`の既定（`low`）なら重さによらず既知の脆弱性のある依存の追加で落とせ、ライセンスの確かめはこの計画の対象外のため。公開から2週間未満の最新版（v5.0.1）は、公開直後の版を取り込まないため採らなかった。更新はDependabotに任せる
- code-review-graphは解析が走らなかったとき（レンダラの終了コード4）にjobを落とし、リスクの点数では落とさない。解析していないPRを「問題なし」と見せないため
- CodeQLは`push`（main）でも走らせる。PRの結果を比べる基準の解析をcode scanningに持たせるため
- 実際のPRで`Analyze (ruby)`が、code scanningのdefault setupが有効なために落ちたら、設定は変えず、人にdefault setupを止めるよう知らせる

## Validation and Acceptance

1. 開発コンテナで`COVERAGE=1 RAILS_ENV=test bin/bundle exec rspec`が成功し、`coverage/.last_run.json`ができ、`git status`に`coverage/`が出ない。`COVERAGE`なしでは`coverage/`ができない
2. 開発コンテナで`bin/bundle exec brakeman --no-pager`が0で終わる。わざと危ない行を足すと0以外で終わる
3. 新しく足した`uses:`と`ref:`がすべて40桁のSHAで、`uses:`に版のコメントがある。既存の`uses:`の行は変わっていない
4. `.github/requirements/*.txt`のすべてのパッケージの行が`--hash=sha256:`を持ち、スクラッチのvenvで`pip install --require-hashes`が通る
5. 実際のPRの上で各新jobが成功し、`rspec`が成果物`pr-report-10-coverage`にカバレッジの率を残し、`report`のStep Summaryにcode-review-graphの報告が出る。`report.yml`がPRに1つのコメントでカバレッジの率を載せ、次のpushで同じコメントを上書きすることは、マージ後に判定
6. 実際のPRの上で`Analyze (ruby)`が成功し、PRに`CodeQL`のチェックが付く。落ちた場合は、原因がdefault setupなら人に知らせた
7. `semgrep`が今のコードで成功する
8. `dependency-review`が成功する。脆弱性のある版のgemを足すと落ちることを、捨てるPRで見た
9. `docs/decisions/`に新しい決定が2ファイルあり、それぞれ段4・段6に入っていて、`docs/decisions/index.md`から辿れ、`check-docs.sh`が通る
10. `lefthook.yml`と`.lefthook/`に差分が無い。job`rspec`の名前と合否の条件、`checks`の名前が変わっていない
11. PRが6段の一直線のスタックで、各PRの本文に、そのPRで新しくできるチェックの表示名と登録名が、実際のChecksの画面の名前のとおりに書かれている
12. `.github/dependabot.yml`に`github-actions`（段3）と`pip`（段4、directory`/.github/requirements`）があり、既存のエントリと同じschedule・prefix・target-branchになっている
13. `ci.yml`の`checks`が、名前`checks`、`if: always()`付きで、`rspec`・分けたjob・`brakeman`・`semgrep`・`dependency-review`を`needs`に持つ。`code-review-graph.yml`のjob`report`と`codeql.yml`のjobは`needs`に無い。`needs`のどれかが成功以外のとき`checks`が落ちる（`needs`の結果を表すJSONで`jq`の判定を確かめた）
14. 実際のPRの上で、全部のPRの`checks`と`Check Related Documents`が通る。必須チェックの登録（GitHubの設定）は変わっていない
