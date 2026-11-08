---
name: git-spice-workflow
description: git-spiceでのコミット・ブランチ操作、Conventional Commitsのtype判断基準（PRタイトルとローカルコミットの使い分け）、プルリクエスト作成ルール、スタックPRのマージ手順を扱うスキル。「コミットして」「ブランチ作って」「PR作成して」「プルリクエスト作成」「マージして」「スタックをマージして」「git-spice」「git-spice commit」「git-spice branch」「git-spice stack」等の指示があった場合に加え、自律的にコミット作成・ブランチ操作・プルリクエスト作成・マージなどのGit操作を行う場合にも使用する。
---

# git-spiceワークフロー

git-spice使用。スタック型ブランチ管理。

## ブランチ作成ルール

- ブランチ名は`<type>/<変更内容>`形式にする（`<type>`はPRタイトルと同じConventional Commits type）。作成時点で、後述の「type判断基準」のPRタイトルの基準でtypeを決める
- 計画（`.claude/plans/`）の複数の段は1段ずつブランチを切りスタックする
- 新しい作業のブランチは、未マージのスタックがあればその最上段に積む。内容が独立して見える変更（ドキュメントのみ等）でも`main`から切らない。作成前に`git-spice ls --all`で、枝分かれを含めた全ブランチから最上段を確認する
  - 例外: `plan-completion` skillの完了の処理のブランチは最上段に積まず、PR作成済みのブランチのうち最上段のものの直上へ`--insert`で挿入する。PR作成済みのブランチがなければ`main`の直上に挿入する。挿入後に上の段をrestackしたら、そのうちpush済みのブランチをpushし直す
- `git-spice branch create`には`--no-commit`を付けてブランチだけを作り、変更は`git-spice commit create`でコミットする。`--insert`でスタックの途中に挿入するときは`--no-restack`も付け、上の段のrestackはコミット後に作業ツリーがきれいになってから行う
- PR本文のRelated Documentsには、そのブランチで作業する計画を指すPlan行を、`plan-completion` skillの印の書き方に従って書く

## コミット内容ルール

- 新設したprivateメソッドやassociation（`has_many`等）は、実際に呼び出す・使用するコードより先の別コミットに分離しない。使用コードと同一コミットに含める
- コミット実行前に、ステージした変更が単一の決定・目的に絞られているか自問する。複数の独立したテーマが混ざっていたら、先に分けてコミットする
- コミットしない変更が作業ツリーに残っている間は、`git-spice commit create --no-restack`でコミットする。上に積まれたブランチは、作業ツリーがクリーンになってから`git-spice upstack restack`で1回だけrestackする
- restackで、別のworktreeでcheckoutされているブランチは、restackされずに警告が出てスキップされる。そのworktreeに未コミットの変更が無いことを確かめ、そのworktreeの中で`git-spice branch restack`する。その上のブランチは、`git-spice upstack restack`や`git-spice stack restack`をやり直してもスキップされたままなので、続けて下から順に`git-spice branch restack --branch <ブランチ>`でrestackする

## コミットメッセージ作成ルール

- すべて英語で作成。日本語は使用しない
- コミットコマンド実行前に、コミットメッセージ全文の日本語訳を提示する
- コミットは原則body付き。bodyには変更の目的や理由を記述する。typo修正等の自明な変更はbody省略可

### 規約

フォーマット・type一覧・subject/body/footer記法: `.github/COMMIT_CONVENTION/COMMIT_CONVENTION.md` 参照

### type判断基準（PRタイトル vs ローカルコミット、上記ファイル未記載）

本プロジェクトmainマージ=スカッシュマージ。**PRタイトル→そのままマージコミットメッセージ→CIでコミット規約準拠チェック**。

- **PRタイトル:** SemVer影響type（`feat`=MINOR、`fix`=PATCH、`!`付きBREAKING CHANGE=MAJOR）のみエンドユーザー影響基準で選択（例: ユーザーが触れる機能・体験増加→`feat`、ユーザー視点不具合解消→`fix`）。`build`/`ci`/`docs`/`refactor`/`test`/`perf`/`revert`はSemVer非影響→無理にエンドユーザー影響で判断せず変更の技術的性質で選択
- **`chore`を安易な受け皿にしない:** エンドユーザー非影響だからと何でも`chore`化→type分類価値低下。技術的性質対応typeあれば、SemVer非対応typeでもそちら優先
- **個々のローカルコミット（git-spiceスタック内）:** レビュアー・将来自分向け、「コード変更が技術的に何をしているか」基準
- 同一変更でも視点差でローカルコミットとPRタイトルのtype相違あり得る（想定内、統一不要）

**破壊的変更か否か厳密検証必須。**

## プルリクエスト作成ルール

- 計画の最後の段のいちばん上のPR（Planに✅を付けるPR）を作る前に、そのブランチをcheckoutした状態で、計画の`Validation and Acceptance`の各項目を1件ずつ判定する。「マージ後に判定」と明記した項目は判定しない
  - 機械的な確認は再実行する。再実行しない項目は、根拠にした記録の箇所を控える
  - ステップごとのコミット数は、そのステップを実装した最初のコミットだけを数える。後から積んだレビュー修正・リファクタ・ドキュメント修正のコミットは数に含めない
  - 判定したコミット（ブランチの先端のSHA）と、項目ごとの判定の結果をPRのTestingに書く
  - 満たさない項目、記述と実態が食い違う項目があれば、PRを作らずにユーザーへ報告する
- `.github/pull_request_template.md`テンプレート使用
- すべて英語で作成。日本語は使用しない
- 親ブランチからの差分・当該ブランチのコミットメッセージ参考
- Testingセクションは、コミットメッセージとclaude-memの記録を確かめ、当該ブランチで実施したテストを書く。計画の最後の段のいちばん上のPRには、上の判定の結果も書く
- 該当Issue無→`Related Issues: N/A`
- 特記事項無→`Notes: No additional information or considerations at this time.`
- タイトルもコミットメッセージ規約準拠
- push済みブランチの名前のtypeがPRタイトルのtypeと食い違う場合→ブランチは改名せず、PRタイトルを正しいtypeにして、食い違いをユーザーへ報告する
- 段落内で無駄な改行をしない
- **Changesセクション: 実装プロセスでなく最終状態記述。** 時系列的開発経緯 禁止。マージ後mainブランチへ最終的にもたらされる技術的構成要素（追加API・コンポーネント・スキーマ変更等）を、存在理由添えて列挙
- 記述内容に対象ブランチ以外の変更が含まれていないか確認する

## mainへの追従

- スタックを最新の`main`の上に載せ直すときは、作業ツリーがクリーンな状態で、`git-spice repo sync`でローカルの`main`を更新し、`git-spice stack restack --branch <スタック内のブランチ>`でそのスタックだけをrestackする。`git-spice repo restack`は他のスタックもrestackするので使わない
- 別のworktreeでcheckoutされているブランチとその上のブランチは、「コミット内容ルール」のとおりrestackする
- pushは、スタック内のブランチをcheckoutした状態で`git-spice stack submit --update-only`で行い、PRの無いブランチにPRを作らない

## スタックPRのマージ

### 前提

- mainへのマージはsquash mergeのみ。マージ後、headブランチは自動削除され、1つ上のPRのマージ先はGitHubがmainへ付け替える
- 作業ツリーがクリーンで、スタックの全ブランチのローカルとリモートが一致していること。未コミットの変更がある場合は、push前に`git stash push -u`で退避し、push後に戻す
- マージを始める前に、マージする範囲にPlanに✅を付けたPRがあれば、そのPRごとに次を確かめる。1つでも満たさなければマージを始めない
  - そのPRのTestingに、`Validation and Acceptance`の全項目（「マージ後に判定」を除く）を満たした判定の結果がある
  - 判定したコミットがそのPRのheadと同じ。違えば、マージ前に判定し直してTestingを直す
- マージを始める前に、マージする範囲の一番上のブランチの先端で`bin/bundle exec rspec`を実行し、終了コードが0（failuresが0件で、`errors occurred outside of examples`もない）であることを確かめる。満たさなければマージを始めない。確かめた後に、マージする範囲のブランチへ変更が加わったら、確かめ直す

### 1本ごとの手順

1. `git-spice ls`で一番下のブランチとPR番号`<N>`を特定し、`gh pr view <N> --json baseRefName,headRefOid,mergeStateStatus`で次を確認する
   - マージ先がmain
   - head SHAがローカルのブランチと一致
   - `mergeStateStatus`が`CLEAN`（CI実行中なら`CLEAN`になるまで待つ）
   - 次のブランチと一番下のブランチとの差分を控える
2. `gh pr merge <N> --squash --match-head-commit <手順1のhead SHA>`でマージする
   - `--subject`・`--body`・`--delete-branch`は付けない
3. `git-spice repo sync --restack=aboves`でローカルへ反映し、次を確認する
   - 出力に`#<N> was merged`と`<次のブランチ>: restacked on main`がある
   - mainの最新コミットが`<PRタイトル> (#<N>)`
   - 次のブランチの`main`との差分が、手順1で控えた差分と一致する
4. `git-spice branch submit --branch <次のブランチ>`でpushし、次のPRのマージ先がmain、head SHAがローカルと一致、`mergeStateStatus`が`CLEAN`になったことを確認する
5. 手順1へ戻る。最後のPRをマージしたら「完了時の確認」へ進む

- `--restack=upstack`・`git-spice stack submit`等で、スタック全体を毎回restack・pushしない

### 完了時の確認

- マージしたブランチがローカル・リモートとも残っていない
- 手順3（`git-spice repo sync --restack=aboves`）では、マージしたスタックの上に積まれた別のブランチも積み直される。そのうちGitHubにPRがあるものだけを`git-spice branch submit --update-only --branch <ブランチ>`でpushする。PRが無い（ローカルにしか無い）ブランチは、ローカルで積み直されるがpushしない
- ほかのスタックや、ローカルにしか無いブランチに`needs restack`・`needs push`が表示されても何もしない（`git-spice repo restack`・`git-spice stack submit`は実行しない）

### 異常時

- 確認項目が1つでも想定と異なれば、その場で止めてユーザーへ報告する
- 1本ごとの手順の手順3（`git-spice repo sync --restack=aboves`）の後で止まり、やり直すときは、`repo sync`はマージを取り込み済みで次のブランチを積み直さない。`git-spice branch restack --branch <次のブランチ>`でそのブランチだけをmainの上に積み直し、差分がそのブランチの変更だけになったことを確かめてから、手順4（`git-spice branch submit --branch <次のブランチ>`）へ進む
