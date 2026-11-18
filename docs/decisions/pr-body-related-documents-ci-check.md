# PR本文のRelated DocumentsをCIで検査する

- **Status:** Accepted
- **Verification Status:** Unverified
- **Date:** 2026-11-17
- **Related Files:** `.github/workflows/related-documents.yml`, `.claude/skills/plan-completion/scripts/check-pr-body.sh`, `.claude/skills/plan-completion/scripts/lib/markdown.jq`, `.claude/skills/plan-completion/SKILL.md`

## Context

PR本文の`### Related Documents`には、`plan-completion` skillの「PR本文のRelated Documentsの印」で決めた形でPlan行・Spec行を書く。計画の完了の判定（`judge-completion.sh`）はこの行を読むが、形の誤りは判定を走らせるまで見つからず、読めない行として後から人に知らされていた。CIはPRタイトルの検査だけで、PR本文を検査するものは無かった。

`git-spice-workflow` skillの「コミット・PRの文章の言語」は、PRのタイトルと本文を英語で書き、日本語を使用しないと決めている。しかし、これを確かめるものは無く、日本語の混じったタイトル・本文のPRがそのまま通っていた。

## Decision

- PRを開いた・本文を直した・pushした・開き直したときに、GitHub ActionsのワークフローがPR本文の`### Related Documents`を検査し、決まりに合わない行があれば、その行と理由を出して失敗する。誤りを、完了の判定の時ではなく、書いた人がその場で直せる時に見せるため
- 検査は`plan-completion` skillの`scripts/check-pr-body.sh`が行う。節の取り出し・フェンス・CRLF・U+FE0Fの扱いは、`judge-completion.sh`と同じ`scripts/lib/markdown.jq`の関数で読む。判定と検査が同じ読み取りを使い、食い違わないようにするため。手元でも同じスクリプトで検査できる
- 検査するのは形だけにする。✅を付けるべきPR（計画の最後の段のいちばん上のPR）か、パスが実在するかは見ない
- 前の決まりの印（🏃・⬜）の付いた行は、誤りにせず警告にとどめる。[計画の完了をPR本文のRelated DocumentsのPlan行の✅で判定する](plan-completion-by-check-mark-only.md)が「前の印の付いたPRの本文は書き換えない」と決めており、その本文のPRへのpushを失敗させないため
- `### Related Documents`の無いPR本文は誤りにする。決まりは、計画・設計が無いPRにも`N/A`の行を書かせ、行を省かないため
- DependabotのPRは検査しない。PRのテンプレートを使わず、Related Documentsを書かないため
- 必須のチェック（ブランチ保護）にはしない。リポジトリの設定は人が行う
- 同じワークフローの別のジョブ`Check PR language`が、PRのタイトルと本文に日本語の文字が無いかを確かめる。当たった文字を、タイトルか本文の何行目かとともに出して失敗する。Related Documentsの検査と別のジョブにするのは、どちらで落ちたかをジョブ名で分けるため
- 数える文字は、U+3000–303F（和文の記号・句読点、全角の空白）、U+3040–309F（ひらがな）、U+30A0–30FF（カタカナ）、U+31F0–31FF（カタカナの拡張）、U+3400–4DBF・U+4E00–9FFF・U+F900–FAFF（漢字）、U+FF00–FFEF（半角・全角の形）とする。中国語の漢字も当たるが、PRを英語で書く決まりなので誤りとして扱う
- コードの中（バッククォート・フェンス）の文字も数える。決まりは日本語を使用しないとだけ決め、例外を設けていないため
- `Check PR language`は、checkout・トークン・外のActionを使わず、タイトル・本文を環境変数で受けてインラインのPythonで数える。タイトル・本文からスクリプトへの注入を防ぎ、固定すべきActionを増やさないため。中身はP-manBrown/devcontainer-features #87のジョブ`language`と同じにし、2つのリポジトリで文字の範囲・出力・ジョブ名を揃える
- `Check PR language`もDependabotのPRは確かめない。本文に上流のリリースノートが入り、書いた人が直せない日本語・中国語の文字が入りうるため
- `Check PR language`も必須のチェックにはしない。登録するかは人が決める

## Considered Options

- **採用: plan-completion skillにbash + jqのスクリプトを置き、ワークフローから呼ぶ**: 判定と同じ読み取りを使うので食い違わない。既存のテストの仕組み（`tests/run.sh`・lefthookのpre-commit）と手元で確かめられる。CIでリポジトリのチェックアウトが要る
- **`actions/github-script`でワークフローの中にJavaScriptで書く**: ファイルが1つで済むが、フェンス・CRLF・U+FE0Fの扱いを写し直すことになり、判定と食い違いうる。手元で回すテストの仕組みが無い
- **本文を正規表現で調べる外部のアクションを使う**: 書く量は最も少ないが、節の範囲・フェンスの中を除くことを表せず、前の印を警告にする扱いも書けない。外部の依存が増える
- **採用（言語の確かめ）: devcontainer-features #87のジョブを、このワークフローの別のジョブとしてそのまま移す**: 2つのリポジトリで文字の範囲・出力・ジョブ名が揃う。checkout・トークン・外のActionが要らない。スクリプトがワークフローの中にあり`tests/run.sh`では回らないので、ワークフローから取り出して手元で回して確かめる
- **言語の確かめのスクリプトをファイルに分け、`ci.yml`でテストする**: テストを繰り返し回せるが、ジョブにcheckoutが要り、テストの置き場所と呼び出しを新しく作ることになる。devcontainer-featuresと形が揃わない
- **`check-pr-body.sh`に言語の確かめを足す**: PR本文の検査が1つのスクリプトに集まるが、`plan-completion` skillの持ち物に計画と関係の無い確かめが混ざる。タイトルを渡す引数が増え、bashで#87と同じ文字の範囲を扱いにくい

## Consequences

- 書き方の誤りは、PRを出した時にその行と理由とともに見える。本文を直すと`edited`で検査がやり直される
- 前の印の付いたPRは、本文を書き換えないままpushしても失敗しない（警告だけが出る）
- 節の無い古いPR（Dependabot以外）は、次にpush・本文を直した時に失敗が見える。必須のチェックではないのでマージは止まらない
- 決まり（`plan-completion` skillの「PR本文のRelated Documentsの印」）や計画の置き場所を変えるときは、`check-pr-body.sh`とそのテストも合わせて変える
- skill・ルールの日本語の節の名前を引用したPR本文は、`Check PR language`で失敗する。英語で言い換えるか、ファイルのパスで示す
- タイトル・本文を直すと、`edited`で`Check PR language`もやり直される
