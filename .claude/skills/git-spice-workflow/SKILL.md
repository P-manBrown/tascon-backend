---
name: git-spice-workflow
description: git-spiceでのコミット・ブランチ操作、Conventional Commitsのtype判断基準（PRタイトルとローカルコミットの使い分け）、プルリクエスト作成ルール、スタックPRのマージ手順を扱うスキル。「コミットして」「ブランチ作って」「PR作成して」「プルリクエスト作成」「マージして」「スタックをマージして」「git-spice」「gs commit」「gs branch」「gs stack」等の指示があった場合に加え、自律的にコミット作成・ブランチ操作・プルリクエスト作成・マージなどのGit操作を行う場合にも使用する。
---

# git-spiceワークフロー

git-spice使用。スタック型ブランチ管理。

## ブランチ作成ルール

- ブランチ名は`<type>/<変更内容>`形式にする（`<type>`はPRタイトルと同じConventional Commits type）
- `execution-plan`の複数ステップは1ステップずつブランチを切りスタックする

## コミット内容ルール

- 新設したprivateメソッドやassociation（`has_many`等）は、実際に呼び出す・使用するコードより先の別コミットに分離しない。使用コードと同一コミットに含める
- コミット実行前に、ステージした変更が単一の決定・目的に絞られているか自問する。複数の独立したテーマが混ざっていたら、先に分けてコミットする

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

- `.github/pull_request_template.md`テンプレート使用
- すべて英語で作成。日本語は使用しない
- 親ブランチからの差分・当該ブランチのコミットメッセージ参考
- 該当Issue無→`Related Issues: N/A`
- 特記事項無→`Notes: No additional information or considerations at this time.`
- タイトルもコミットメッセージ規約準拠
- 段落内で無駄な改行をしない
- **Changesセクション: 実装プロセスでなく最終状態記述。** 時系列的開発経緯 禁止。マージ後mainブランチへ最終的にもたらされる技術的構成要素（追加API・コンポーネント・スキーマ変更等）を、存在理由添えて列挙
- プルリクエスト作成コマンド実行前に、プルリクエスト全文の日本語訳を提示する
- 記述内容に対象ブランチ以外の変更が含まれていないか確認する

## スタックPRのマージ

### 前提

- mainへのマージはsquash mergeのみ。マージ後、headブランチは自動削除され、1つ上のPRのマージ先はGitHubがmainへ付け替える
- 作業ツリーがクリーンで、スタックの全ブランチのローカルとリモートが一致していること。未コミットの変更がある場合は、push前に`git stash push -u`で退避し、push後に戻す

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
- `git-spice log short --all`で`needs restack`・`needs push`が表示されない。表示される場合は、`git-spice repo restack`と、該当スタックでの`git-spice stack submit`を実行し、再度確認する

### 異常時

- 確認項目が1つでも想定と異なれば、その場で止めてユーザーへ報告する
