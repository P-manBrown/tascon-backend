# ミューテーションテストをMutantで報告だけ走らせる

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-20
- **Related Files:** `config/mutant.yml`, `config/mutant/hooks.rb`, `.github/workflows/mutant.yml`, `spec/spec_helper.rb`, `Gemfile`

## Context

テストがコードの振る舞いの変化をどれだけ捕まえるかは、行のカバレッジ（SimpleCov）でしか見えなかった。ミューテーションテストの道具Mutantを入れる。[CIのチェックを合否を返す物と報告だけの物に分ける](ci-required-and-report-only-checks.md)はミューテーションテストを「入れる場合も報告だけにする」と決めており、これに従う。

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
