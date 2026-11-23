# テストのカバレッジにしきい値が無い
- **Status:** Open
- **Priority:** Low
- **Category:** Test
- **Area:** `spec/spec_helper.rb`、`.github/workflows/ci.yml`（job`rspec`）
- **Detected:** 2026-11-22
- **Description:** SimpleCovは`COVERAGE`があるときだけ動き、行のカバレッジの率を報告するだけで、`minimum_coverage`などのしきい値を付けていない。率でCIの合否は変わらない。2026-11-23時点（コミット51fd3884、118 examples）の行カバレッジは、手元（`CI`なし）で48.73%、CIで67.85%と差があった。CIだけがeager loadし、すべてのファイルの読み込みで走る行も通った行に数えるためである。今は`COVERAGE`があるときもeager loadするので、手元とCIは同じ方法で測る。しきい値はCIで検査するので、将来決めるときはCIの値から決める。テストがまだ少ないため、今しきい値を付けると、決めた値の根拠が無いか、低すぎて意味が無い。しきい値を付けないことは計画`docs/design/plans/active/test-and-check-tools-ci.md`のDecision Logと仕様`docs/design/specs/test-and-check-tools-ci.md`のREQ-001で決めた。
- **Impact:** カバレッジが大きく下がる変更が入っても、CIは止めない。率はPRのコメント（`report.yml`）で見えるだけで、下がったことに気づくかは人に頼る。
- **Proposed Resolution:** テストを書き進めて率が安定したら、次の流れで入れる。(1) その時点の率から数ポイント下を`SimpleCov.minimum_coverage`に設定し、率が上がるたびに引き上げる（下げない仕組みとして使い、急な低下だけを止める）。(2) 必要なら`enable_coverage :branch`で分岐のカバレッジも測り、行と分岐を別々に指定する（例: `minimum_coverage line: 80, branch: 70`）。(3) 全体の率より、PRで変えた行のカバレッジ（diff coverage。例: `undercover` gem）を落とす方が効果が大きい。目安として、Google Testing Blog「Code Coverage Best Practices」（2020）は60%を許容、75%を良好、90%を模範的としている。100%を目指すと意味の薄いテストが増えやすい。`SimpleCov.refuse_coverage_drop`は前回の`coverage/.last_run.json`と比べるため、CIではmainの結果を渡さないと効かない。どの値・方式にするかは、率が安定した時点で決める。
- **Related:** PR #836（https://github.com/P-manBrown/tascon-backend/pull/836）、`docs/design/plans/active/test-and-check-tools-ci.md`、`docs/design/specs/test-and-check-tools-ci.md`
