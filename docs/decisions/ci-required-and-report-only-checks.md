# CIのチェックを合否を返す物と報告だけの物に分ける

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-19
- **Related Files:** `.github/workflows/ci.yml`, `.github/workflows/codeql.yml`, `.github/workflows/code-review-graph.yml`, `spec/spec_helper.rb`

## Context

PRごとのCIに、テストのカバレッジ、Railsの静的解析、コードの脆弱性の解析、依存の既知の脆弱性、変更の影響の報告を入れた（[PRごとのCIで使うテストと確かめの道具](test-and-check-tool-selection.md)）。必須チェック（ブランチ保護）に登録するかは人が決めるが、そのためには、どのチェックが合否を返し、どれが報告だけかが決まっている必要がある。

## Decision

- 合否を返すチェック（必須チェックの候補）は、job`rspec`・`checks`・`brakeman`・`semgrep`・`dependency-review`・`Analyze (ruby)`と、code scanningの結果のチェック
- 報告だけにする物
  - テストのカバレッジの率: job`rspec`のStep Summaryに書く。しきい値を付けず、率で合否を変えない
  - code-review-graph: ワークフロー`code-review-graph`のjob`report`のStep Summaryに書く。リスクの点数では落とさない（`fail-on-risk`に当たる処理を書かない）。解析が走らなかったときだけjobが落ちる。必須チェックの候補にしない
  - ミューテーションテスト: 今は入れない。入れる場合も報告だけにする
- 必須チェックへの登録は人が決める。この決定はリポジトリの設定を変えない

## Considered Options

- **採用: 規則に基づいて問題を見つける道具だけが合否を返し、率と点数は報告だけにする**: 長所: 合否の理由がjobの出力の具体的な指摘で分かる。短所: カバレッジの率の低下やリスクの点数の上昇では、PRが落ちず、人がStep Summaryを見ないと気づけない
- **カバレッジにしきい値を付ける**: 長所: SimpleCovの最小カバレッジの設定で、率がしきい値を下回るとrspecの終了コードが0以外になるため、率の低下をPRで止められる。短所: テストを足さずにコードを足したPRや、テストを消したPRが落ちる
- **code-review-graphに`fail-on-risk`を付ける、または必須にする**: 長所: `fail-on-risk`は全体のリスクの点数が`high`（0.70以上）・`critical`（0.85以上）に達するとjobを落とすため、影響の広い関数の変更をPRで止められる。短所: 点数は変えた関数の置かれた所（flowへの参加、別のcommunityからの呼び出し、テストの無さ、セキュリティらしい名前、呼び出し元の数）から計算され、変更が正しいかは見ないため、そうした関数への正しい変更も`high`に達して落ちる
- **ミューテーションテストを必須にする**: 長所: Rubyのミューテーションテストの道具mutantのREADMEは、コードを系統的に変え、テストがそれぞれの変更を実際に捕まえるかを確かめると述べている（道具を選んだわけではない）。短所: 道具の導入と固定の仕方の検討が先に要る

## Consequences

- 合否を返すjobのどれを必須チェックにするかは、人がGitHubの設定で決める
- code-review-graphのレンダラ（`code-review-graph.yml`の`tirth8205/code-review-graph`の`ref:`）はDependabotの対象外で、Dependabotが`.github/requirements/code-review-graph.txt`の本体の版を上げたときに、同じ版のタグのSHAへ手で合わせる。ずれるとレンダラが本体の出力を読めない可能性がある
- カバレッジの率が下がってもPRは落ちない。率はStep Summaryで人が見る
