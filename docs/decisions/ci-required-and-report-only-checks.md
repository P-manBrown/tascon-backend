# CIのチェックを合否を返す物と報告だけの物に分ける

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-19
- **Related Files:** `.github/workflows/ci.yml`, `.github/workflows/codeql.yml`, `.github/workflows/code-review-graph.yml`, `spec/spec_helper.rb`

## Context

PRごとのCIに、テストのカバレッジ、Railsの静的解析、コードの脆弱性の解析、依存の既知の脆弱性、変更の影響の報告を入れた（[PRごとのCIで使うテストと確かめの道具](test-and-check-tool-selection.md)）。必須チェック（ブランチ保護）に登録するのは`ci.yml`のjob`checks`（と`Validate PR title`）だけにする。`checks`は全部のjobを`needs`で待ち、1つでも成功以外なら落ちるまとめ役のjobで、`needs`が待てるのは同じワークフローのjobだけである。そのため、どのチェックが合否を返して`checks`の`needs`に入り、どれが報告だけかが決まっている必要がある。

## Decision

- 合否を返し、`checks`の`needs`に入れるjobは、`ci.yml`のjob`rspec`・`checks`の手順を分けたjob（`rubocop`・`htmlbeautifier`・`debride`・`check-docs`・`pre-commit-check-tests`・`plan-completion-script-tests`・`check-plan-completion`）・`brakeman`・`semgrep`・`dependency-review`。必須チェックに登録するのは、まとめ役の`checks`だけ
- 合否を返すが`checks`の`needs`に入れない物: ワークフロー`CodeQL`のjob`Analyze (ruby)`と、code scanningの結果のチェック。別のワークフローで、`needs`が待てない。mainへのpushでも走らせて基準の解析をcode scanningに持たせる必要もあり、`ci.yml`には置かない。これらは`checks`とは別に必須チェックへ登録することはできるが、今は登録しない
- 報告だけにする物
  - テストのカバレッジの率: job`rspec`のStep Summaryに書く。しきい値を付けず、率で合否を変えない
  - code-review-graph: ワークフロー`code-review-graph`のjob`report`のStep Summaryに書く。リスクの点数では落とさない（`fail-on-risk`に当たる処理を書かない）。解析が走らなかったときだけjobが落ちる。必須チェックの候補にしない
  - ミューテーションテスト: 今は入れない。入れる場合も報告だけにする
- 必須チェックの登録（GitHubの設定）は変えない。今登録してある`checks`が、そのまま新しいjobの合否を引き受ける

## Considered Options

- **採用: まとめ役のjob`checks`だけを必須チェックに登録する**: 長所: 必須にする確かめが増えても、GitHubの設定を変えない。`checks`の`needs`の変更はPRの差分としてレビューできる。短所: `needs`に入れ忘れたjobは、落ちてもPRを止めない。別のワークフローのjobは待てない
- **jobごとに必須チェックへ登録する**: 長所: どのjobが必須かがGitHubの設定に出て、`needs`の入れ忘れが起きない。短所: jobを足す・名前を変えるたびにGitHubの設定を変える必要があり、設定の変更はPRの差分に出ない
- **採用: 規則に基づいて問題を見つける道具だけが合否を返し、率と点数は報告だけにする**: 長所: 合否の理由がjobの出力の具体的な指摘で分かる。短所: カバレッジの率の低下やリスクの点数の上昇では、PRが落ちず、人がStep Summaryを見ないと気づけない
- **カバレッジにしきい値を付ける**: 長所: SimpleCovの最小カバレッジの設定で、率がしきい値を下回るとrspecの終了コードが0以外になるため、率の低下をPRで止められる。短所: テストを足さずにコードを足したPRや、テストを消したPRが落ちる
- **code-review-graphに`fail-on-risk`を付ける、または必須にする**: 長所: `fail-on-risk`は全体のリスクの点数が`high`（0.70以上）・`critical`（0.85以上）に達するとjobを落とすため、影響の広い関数の変更をPRで止められる。短所: 点数は変えた関数の置かれた所（flowへの参加、別のcommunityからの呼び出し、テストの無さ、セキュリティらしい名前、呼び出し元の数）から計算され、変更が正しいかは見ないため、そうした関数への正しい変更も`high`に達して落ちる
- **ミューテーションテストを必須にする**: 長所: Rubyのミューテーションテストの道具mutantのREADMEは、コードを系統的に変え、テストがそれぞれの変更を実際に捕まえるかを確かめると述べている（道具を選んだわけではない）。短所: 道具の導入と固定の仕方の検討が先に要る

## Consequences

- 必須にする確かめを足すときは、`ci.yml`にjobを足して`checks`の`needs`に入れる。GitHubの必須チェックの登録は変えずに済む
- `Analyze (ruby)`が落ちても`checks`は落ちず、PRはマージできる。人がCodeQLの結果を見る
- code-review-graphのレンダラ（`code-review-graph.yml`の`tirth8205/code-review-graph`の`ref:`）はDependabotの対象外で、Dependabotが`.github/requirements/code-review-graph.txt`の本体の版を上げたときに、同じ版のタグのSHAへ手で合わせる。ずれるとレンダラが本体の出力を読めない可能性がある
- カバレッジの率が下がってもPRは落ちない。率はStep Summaryで人が見る
