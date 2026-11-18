# PRごとのCIで使うテストと確かめの道具

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-19
- **Related Files:** `.github/workflows/ci.yml`, `.github/workflows/codeql.yml`, `.github/dependabot.yml`, `.github/requirements/semgrep.in`, `.github/requirements/semgrep.txt`, `Gemfile`, `spec/spec_helper.rb`

## Context

PRごとのCIはjob`rspec`と`checks`だけで、テストのカバレッジ、Railsの静的解析、コードの脆弱性の解析、PRで新しく入る依存の既知の脆弱性、変更の影響の報告が見えなかった。リポジトリはpublicで、CIはGitHub Actionsで動く。

## Decision

- PRごとのCIで次の道具を使う
  - SimpleCov: テストのカバレッジの率をjob`rspec`のStep Summaryに書く
  - Brakeman: Railsの静的解析（job`brakeman`）
  - CodeQL（Ruby）: コードの脆弱性の解析。結果はcode scanningに上がる（ワークフロー`CodeQL`）
  - Semgrep: `semgrep/semgrep-rules`の`ruby/rails`の規則（job`semgrep`）
  - Dependency Review: PRで新しく入る依存の既知の脆弱性（job`dependency-review`）
  - code-review-graph: 変更の影響の報告（ワークフロー`code-review-graph`）
- 外から持ち込む物は不変のIDで固定する。Actionは40桁のコミットのSHA、Pythonの道具は`.github/requirements/`のhash付きのrequirements、Rubyの道具は`Gemfile.lock`、取り出す規則とレンダラは`actions/checkout`の`ref:`のSHA

## Considered Options

- **採用: SimpleCov・Brakeman・CodeQL・Semgrep・Dependency Review・code-review-graph**: どれもAPIキーや有料の契約なしにCIで走る。CodeQLとDependency Reviewはpublicのリポジトリで追加の契約なしに使え、CodeQLの結果はcode scanningに上がる。規則に基づく解析で、同じコードと同じ版なら結果が変わらない。Semgrepの規則と2つのPythonの道具は自分で固定の仕方を持つ必要がある
- **DeepSec（vercel-labs/deepsec）**: LLMを使う解析で、正規表現で候補を見つけた後にAIで調べる。モデルの利用にOpenAI・AnthropicのAPIキーかVercel AI Gatewayが要り、利用の費用がかかる（`--max-cost-usd`で上限を付けられる）。READMEは、実行する環境で全権のshellを持つcoding agentとして扱うよう求めている。CIで使うにはsecretが要り、DependabotのPRにはActionsのsecretが渡らない
- **Claude Codeの`/security-review`をCIで走らせる（`anthropics/claude-code-security-review`）**: LLMによるレビューで、Anthropic APIのキー（入力`claude-api-key`）が要り、実行ごとに費用がかかる。CIで使うにはsecretが要り、DependabotのPRにはActionsのsecretが渡らない
- **Semgrepの規則をレジストリ（`p/rails`）から取る**: 設定が1行で済むが、規則の版が固定されず、実行のたびにネットワークから取るため、コードを変えていないPRの結果が規則の更新で変わりうる

## Consequences

- Brakeman・Semgrep・Dependency Reviewは問題を見つけるとjobが落ちる。必須チェックにするかは人が決める
- Semgrepの規則は`semgrep/semgrep-rules`のライセンス（Semgrep Rules License v1.0）が規則の配布を許さないため、リポジトリに写さず、CIで取り出して使う
- Semgrepの規則のSHA（`ci.yml`のjob`semgrep`の`ref:`）はDependabotの対象外で、手で更新する
- 今のmainでSemgrepが見つけた8件は、挙動を変えずに行ごとの`nosemgrep`と理由のコメントで外した。外した行を変えるときは、外す理由がまだ正しいかを見直す
- `.github/dependabot.yml`の`github-actions`は、既存のワークフローのタグ参照（`@v7`など）にも新しいmajorの更新のPRを出す
