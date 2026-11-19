# PRの題名と本文に日本語が無いかの確かめを別のジョブとして足す（設計と要件）

この設計に基づく計画: `.claude/plans/active/pr-language-check.md`

## 求められている結果

`.github/workflows/related-documents.yml`（PR本文のRelated Documentsの確かめ）に、PRの題名と本文に日本語の文字が無いかを確かめるジョブを、既存のジョブとは別に足す。どちらの確かめで落ちたかがジョブの名前で分かるようにする。

`git-spice-workflow` Skillの「コミット・PRの文章の言語」は、PRのタイトルと本文を英語で書き、日本語は使用しないと決めている。しかしCIにはこれを確かめるものが無く、日本語の混じった題名・本文のPRがそのまま通っている（直近100件のうち7件: #812・#810・#804・#752・#746・#729・#715）。

中身は、P-manBrown/devcontainer-features #87（マージ済み、コミット`9c65340b876134921e4f0aa1f222184365ca00ad`）の`.github/workflows/semantic-pull-request.yml`のジョブ`language`（表示名`Check PR language`）を移したものにする。

## 制約

- 新しいジョブの名前は、必須チェックに登録できるよう、実際に表示される名前（呼び出し側・呼ばれる側・matrixを含む）をPR本文に一覧にする。必須チェックの設定は変えない
- 確かめを足したことは、`docs/decisions/pr-body-related-documents-ci-check.md`に書き足す
- 外のActionを使うときはコミットのIDで固定する
- lefthookの動きは変えない
- PRの題名の形の確かめ（`semantic-pull-request.yml`）は別のまま

## やらないこと

- `semantic-pull-request.yml`・`ci.yml`・`lefthook.yml`・`.lefthook/`の変更
- 必須チェック（ブランチ保護）の設定
- `git-spice-workflow` Skillの文言の変更（#810で同じ趣旨の節が既にある。確かめの名前をSkillに書き足すのは依頼に無く、Skillを変えるとルールの比較テストも要るため）
- 既存ジョブの`actions/checkout@v7`をコミットIDで固定し直すこと（新しく使うActionではない）
- ワークフローのファイル名・`name: Related Documents`の変更
- 日本語の節の名前をPR本文でどう参照するかの書き方の決まり（下の「未解決」）

## 案の比較

### 案A（採用）: #87のジョブを、`related-documents.yml`の別ジョブとしてそのまま移す

- 長所: 2つのリポジトリで同じ文字の範囲・同じ出力・同じジョブ名になる。checkout・トークン・外のActionが要らず、`pull_request`のイベントの値を環境変数で渡すだけなので、題名・本文からのスクリプト注入が起きない。ジョブが独立するので、Related Documentsと言語のどちらで落ちたかがジョブ名で分かる。lefthookに触れない
- 短所: スクリプトがワークフローの中にあり、リポジトリのテストの仕組み（`tests/run.sh`）では回らない。確かめは、ワークフローから取り出したスクリプトを手元で回すことと、PRでの実際の実行で行う

### 案B: スクリプトをファイル（例: `.github/scripts/check-pr-language.py`）に分け、テストを`ci.yml`の`checks`で回す

- 長所: テストを繰り返し回せる
- 短所: ジョブにcheckoutが要る。テストの置き場所と呼び出しを新しく作ることになり、devcontainer-featuresと形が揃わない。テストをlefthookから回すとhookの動きが変わり、「hookは変えない」に反する（CIだけで回すと手元で回し忘れる）

### 案C: `check-pr-body.sh`に言語の確かめを足し、別のジョブから別の引数で呼ぶ

- 長所: PR本文の確かめが1つのスクリプトに集まる
- 短所: `plan-completion` Skillの持ち物（計画の完了の印の確かめ）に、計画と関係の無い確かめが混ざる。題名は本文ではないので引数が増える。bashで日本語の文字の範囲を正しく扱うには`grep -P`等が要り、#87と範囲を揃えにくい

案Aを採る。#87の中身を足すことを最も少ない変更で満たすため。

## 設計

### 1. ワークフロー（`.github/workflows/related-documents.yml`）

- 既存のジョブ`main`（`Check Related Documents`）とトリガーはそのまま
- ジョブ`language`を足す
  - `name: Check PR language`（#87と同じ名前）
  - `if: github.event.pull_request.user.login != 'dependabot[bot]'`（既存ジョブと同じ）。Dependabotの本文には上流のリリースノートが入り、書いた人が直せない日本語・中国語の文字が入りうるため
  - `runs-on: ubuntu-latest`。権限はワークフローの`contents: read`を引き継ぐ
  - ステップは1つ。`env`の`TITLE: ${{ github.event.pull_request.title }}`・`BODY: ${{ github.event.pull_request.body }}`、`shell: python3 {0}`、`run`は#87のスクリプトをそのまま使う
  - checkout・トークン・外のActionは使わない（よって固定すべきActionは無い）
- 数える文字（どれか1文字でも当たれば日本語とみなす）
  - U+3000–303F（和文の記号・句読点、全角の空白）
  - U+3040–309F（ひらがな）
  - U+30A0–30FF（カタカナ）
  - U+31F0–31FF（カタカナの拡張）
  - U+3400–4DBF・U+4E00–9FFF・U+F900–FAFF（漢字）
  - U+FF00–FFEF（半角・全角の形。半角カタカナを含む）
- 出力
  - 題名に当たれば`::error::Japanese characters in PR title: <当たった文字>`を1行出す。`<当たった文字>`は題名の中で当たった文字だけを、出てきた順に並べたもの
  - 本文は改行（`\n`）で行に分け、各行の終わりの`\r`を除いてから数える。当たる文字のある行ごとに`::error::Japanese characters in PR body line <N>: <当たった文字>`を出す。`<N>`は1から数える行番号
  - 1つでもあれば終了コード1。無ければ`PR title and body contain no Japanese characters.`を出して終了コード0
  - 本文が空または未設定のときは、題名だけで判定する
- 中国語の漢字も当たる。PRを英語で書く決まりなので、誤りとして扱ってよい
- コードの中（バッククォート・フェンスの中）の文字も数える。決まりが「日本語は使用しない」で例外を設けておらず、#87も同じ扱いのため

### 2. 決定の記録（`docs/decisions/pr-body-related-documents-ci-check.md`）

`.claude/rules/decisions-maintenance.md`の形式のまま、日本語で、既存の各節に書き足す。

- Context: `git-spice-workflow` SkillがPRのタイトル・本文を英語で書くと決めているが、それを確かめるものが無かったこと
- Decision: 同じワークフローに別のジョブ`Check PR language`を足し、題名と本文の日本語の文字を行ごとに示して失敗すること。数える文字の範囲。コードの中も数えること。checkout・トークン・外のActionを使わないこと。DependabotのPRは確かめないこと。Related Documentsの確かめと別のジョブにするのは、どちらで落ちたかをジョブ名で分けるため。必須のチェックにはしないこと
- Considered Options: 上の案A〜C
- Consequences: Skill・ルールの日本語の節の名前を引用した本文は失敗するので、英語で言い換えるかパスで示す必要があること。題名・本文を直すと`edited`でやり直されること
- 変えないもの: タイトル・Date・Related Files（ワークフローは既に載っている）・`Verification Status`（Unverifiedのまま）・`docs/decisions/index.md`（タイトルを変えないため）

### 3. PR本文

- Notesに、新しいジョブの表示名の一覧を書く。`Check PR language`で、呼び出し側・呼ばれる側の別もmatrixも無い。必須チェックに登録する名前は`Check PR language`
- 必須チェックの設定は変えていない旨を書く
- 本文自体を英語だけで書く（このPRで足すジョブに当たらないこと）

## 受け入れの条件

| ID | 条件 |
| --- | --- |
| REQ-001 | `related-documents.yml`に、既存の`main`とは別のジョブ`language`（名前`Check PR language`）があり、題名か本文に上の範囲の文字があれば失敗し、無ければ通る |
| REQ-002 | 失敗の出力が、題名か本文の何行目かと、当たった文字だけを示す |
| REQ-003 | 題名・本文はイベントの値を環境変数で受け、`run`の中へ`${{ }}`で埋め込まない。checkout・トークン・外のActionを使わない |
| REQ-004 | DependabotのPRでは新しいジョブが動かない |
| REQ-005 | 既存のジョブ`main`、トリガー、`semantic-pull-request.yml`、`ci.yml`、`lefthook.yml`、`.lefthook/`が変わっていない |
| REQ-006 | `docs/decisions/pr-body-related-documents-ci-check.md`に、言語の確かめを足したことが上の内容で書き足され、`bash .lefthook/pre-commit/check-docs.sh`が通る |
| REQ-007 | PR本文のNotesに、新しいジョブの表示名`Check PR language`と、必須チェックに登録する名前が書かれている |
| REQ-008 | 下の「確かめ方」の確かめが、すべて期待どおりの結果になる |

### 確かめ方

- PyYAMLでワークフローを読み、ジョブ`main`が変わっていないこと、ジョブ`language`の名前・`if`・`env`・`shell`があること、ファイルに日本語の文字が無いことを確かめる
- ワークフローから`run`を取り出し、手元のpython3で次を回し、終了コードと`::error::`の行が期待どおりか見る: 英語、空、未設定、`.github/pull_request_template.md`、ひらがな、カタカナ、漢字、句読点だけ、全角だけ、半角カタカナ、全角の空白、複数か所、CRLF、中国語、各範囲の最初と最後の文字と、その1つ外の文字
- 直近のPRの題名・本文（`gh pr list`で取れる直近100件）に回し、上の7件が失敗し、残りが通ることを確かめる
- `bash .lefthook/pre-commit/check-docs.sh`が決定の記録の変更で通ること
- actionlint・zizmorはビルドの環境に無いので回さない。GitHub上で`Check PR language`が実行されて通ることは、PRで確かめる

## 前提として置いたこと

- 書き足す先のワークフローは`related-documents.yml`
- ジョブ名は#87と同じ`Check PR language`（リポジトリ間で揃う）
- コードの中の日本語も数える（Skillの決まりに例外が無く、#87も同じ）
- DependabotのPRは除く（既存ジョブと同じ。Dependabotの本文は書いた人が直せない）
- Skillは変えない

## 未解決

- Skill・ルールの節の名前が日本語なので、PR本文でそれを指すとき、英語の言い換えにするかパス（と行番号）にするかの決まりが無い。直近100件のうち7件がこれで失敗する書き方だった。この作業の範囲外。必要なら別の作業として`git-spice-workflow` Skillに書き足すかを人が決める
