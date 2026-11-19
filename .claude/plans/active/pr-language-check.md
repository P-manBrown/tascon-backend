# PRの題名と本文の言語の確かめ（Check PR language）を足す

Spec: .claude/specs/pr-language-check.md

## Context/Purpose

`git-spice-workflow` Skillの「コミット・PRの文章の言語」は、PRのタイトルと本文を英語で書き、日本語は使用しないと決めている。しかしCIにはこれを確かめるものが無く、日本語の混じった題名・本文のPRがそのまま通っている（直近100件のうち7件: #812・#810・#804・#752・#746・#729・#715）。

PR本文の確かめのワークフロー`.github/workflows/related-documents.yml`（ジョブ`main`、表示名`Check Related Documents`）に、PRの題名と本文に日本語の文字が無いかを確かめるジョブ`language`（表示名`Check PR language`）を別に足し、その決定を`docs/decisions/pr-body-related-documents-ci-check.md`に書き足す。中身はP-manBrown/devcontainer-features #87（コミット`9c65340b876134921e4f0aa1f222184365ca00ad`）の同名のジョブを移したもの。設計と要件（案の比較、数える文字の範囲、出力、受け入れの条件）は`.claude/specs/pr-language-check.md`にある。

変えるファイルは2つだけで、`semantic-pull-request.yml`・`ci.yml`・`lefthook.yml`・`.lefthook/`・必須チェックの設定・`git-spice-workflow` Skillは変えない。

## Decision Log

- #87のジョブを、`related-documents.yml`の別ジョブとしてそのまま移す（案A）。文字の範囲・出力・ジョブ名が2つのリポジトリで揃い、checkout・トークン・外のActionが要らず、どちらの確かめで落ちたかがジョブ名で分かるため。スクリプトをファイルに分けて`ci.yml`でテストする案Bは、checkoutとテストの置き場所が増え、lefthookから回すとhookの動きが変わるため採らない。`check-pr-body.sh`に足す案Cは、`plan-completion` Skillの持ち物に計画と関係の無い確かめが混ざるため採らない
- 題名・本文はイベントの値を環境変数`TITLE`・`BODY`で受け、`run`の中へ`${{ }}`で埋め込まない。題名・本文からのスクリプト注入を防ぐため
- DependabotのPRでは新しいジョブを動かさない（`if: github.event.pull_request.user.login != 'dependabot[bot]'`）。#87のジョブには無い条件だが、Dependabotの本文には書いた人が直せない日本語・中国語の文字が入りうるため、既存のジョブ`main`に合わせて足す
- コードの中（バッククォート・フェンスの中）の日本語も数え、中国語の漢字も当てる。Skillの決まりが「日本語は使用しない」で例外を設けておらず、#87も同じ扱いのため
- 必須チェックにはしない。リポジトリの設定は人が行う。登録する名前はPR本文のNotesに書く
- `git-spice-workflow` Skillは変えない。#810で同じ趣旨の節が既にあり、確かめの名前を足すのは依頼に無く、Skillを変えるとルールの比較テストも要るため
- 決定の記録は、新しいファイルを作らず、`pr-body-related-documents-ci-check.md`の各節に書き足す。依頼がこのファイルへの書き足しを指定したため。記録は2つ目の決定も含むことになり、`.claude/rules/decisions-maintenance.md`の「1ファイル1決定」と合わない点は、実装のレビューで指摘された（指摘のうえで書き足しを維持した）

## Progress

- [x] Step1: ワークフローにジョブ`language`（`Check PR language`）を足す（`ci/check-pr-language`、#828）
- [x] Step2: 決定の記録に言語の確かめを書き足す（`docs/record-pr-language-check-decision`、#829）

## Validation and Acceptance

受け入れの条件の番号（REQ-001〜REQ-008）は`.claude/specs/pr-language-check.md`のもの。

- ワークフローの構造（REQ-001・REQ-003・REQ-004・REQ-005）: PyYAMLで読み、ジョブ`main`とトリガーが変わっておらず、ジョブ`language`の名前・`if`・`env`・`shell`があり、checkout・トークン・外のActionが無く、`run`の中に`${{ }}`が無いこと。`semantic-pull-request.yml`・`ci.yml`・`lefthook.yml`・`.lefthook/`が`main`から変わっていないこと
- スクリプトの振る舞い（REQ-001・REQ-002）: ワークフローから取り出した`run`を、「確かめ方」の各ケース（英語、空、未設定、テンプレート、ひらがな、カタカナ、漢字、句読点、全角、半角カタカナ、複数か所、CRLF、中国語、各範囲の最初と最後とその1つ外の文字）に回し、終了コードと`::error::`の行が仕様どおりであること
- 直近のPR: `gh pr list`で取れる直近100件の題名・本文に回すと、#812・#810・#804・#752・#746・#729・#715の7件だけが失敗すること
- 決定の記録（REQ-006）: `docs/decisions/pr-body-related-documents-ci-check.md`に、仕様の「決定の記録」の内容が各節に書き足され、タイトル・Status・Verification Status・Date・Related Filesと`docs/decisions/index.md`が変わっておらず、`bash .lefthook/pre-commit/check-docs.sh`が通ること
- PR本文（REQ-007）: ジョブを足すPRのNotesに、`Check PR language`と必須チェックに登録する名前が書かれ、PR本文が英語だけであること
- GitHub上の実行: 各PRで`Check PR language`が実行されて通ること。actionlint・zizmorはビルドの環境に無いので回していない
