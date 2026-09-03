---
name: git-spice-workflow
description: git-spiceでのコミット・ブランチ操作、Conventional Commitsのtype判断基準（PRタイトルとローカルコミットの使い分け）、プルリクエスト作成ルールを扱うスキル。「コミットして」「ブランチ作って」「PR作成して」「プルリクエスト作成」「git-spice」「gs commit」「gs branch」「gs stack」等の指示があった場合に加え、自律的にコミット作成・ブランチ操作・プルリクエスト作成などのGit操作を行う場合にも使用する。
---

# git-spiceワークフロー

git-spice使用。スタック型ブランチ管理。

## ブランチ作成ルール

- ブランチ名は`<type>/<変更内容>`形式にする（`<type>`はPRタイトルと同じConventional Commits type）
- git-spiceスタックの標準粒度は「1ブランチ = 1機能 = 1〜2コミット」。複数の異なる機能・Stepのコミットを1ブランチにまとめない
- 複数機能・Stepをまとめた場合→`git-spice branch split --at <commit>:<name>`で機能単位のブランチへ分割する
- `gs branch create <name> -m "..."`（ブランチ作成とコミットメッセージ指定を同時に行う形）はmainブランチ上のprotect-branchフックに阻まれてエラーになる。`gs branch create <name> --no-commit`でブランチを作成・checkoutしてから、`git commit`を別途実行する2段階の手順を使う（`--no-commit`を付けないとステージ済み変更の有無に関わらずコミットが1つ作られてしまう）
- `Agent`ツールの`isolation: "worktree"`で起動したサブエージェント内では、初回チェックアウトブランチがgit-spiceに未追跡のため、いきなり`gs branch create`を実行すると`FTL gs: branch not tracked`で失敗する。先に`gs branch track --base <ベースブランチ>`で追跡を付与してから`gs branch create`を使う

## コミット内容ルール

- 新設したprivateメソッドやassociation（`has_many`等）は、実際に呼び出す・使用するコードより先の別コミットに分離しない。使用コードと同一コミットに含める（lefthookのdebride pre-commit hookが未使用コードとして検出し失敗するため）
- コミット実行前に、ステージした変更が単一の決定・目的に絞られているか自問する。複数の独立したテーマが混ざっていたら、先に分けてコミットする

## コミットメッセージ作成ルール

- すべて英語で作成。日本語は使用しない
- コミットコマンド実行前に、コミットメッセージ全文の日本語訳を提示する
- コミットは原則body付き。複数の妥当なtype候補から選択した場合、または作業中に試行錯誤・修正があった場合はbodyをほぼ必須とする。typo修正等の自明な変更はbody省略可

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

- PR作成前、`ARCHITECTURE.md`・`.claude/plans/`に影響する変更（レイヤー構成の変更、plan完了等）があれば`doc-gardening` skillの実行を検討する
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
