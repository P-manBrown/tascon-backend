# 設計候補: tascon-backend のライセンスの洗い出し

- 対象 bead: tb-4txu8（HQ 依頼 gc-n91n の 3 つのうちの 1）
- ワークフロー root: tb-nvhlu（superpowers-build）
- 設計 lane bead: tb-igc2n（iteration 1, attempt 1）
- 承認モード: autonomous
- 承認状態: **承認済み（autonomous、tb-cyd40、2026-11-18）**

## Superpowers チェックリスト 1〜5 の記録

1. **プロジェクトの文脈の確認**: 済。確かめた内容は「確かめた事実」節。
2. **Visual Companion**: 提示しない。画面・図の比較を要する問いがない（文書と表だけの成果物）。
3. **確認の質問**: 人の回答を要する問いはない。依頼文とリポジトリから決まらない点は「前提」節に前提として書き、先へ進む。
4. **方式の比較**: 3 案を比較し推奨を決めた（「方式の比較」節）。
5. **設計の提示**: 節に分けて記述（「設計」節）。

## 求められている結果

依存の gem（全 group・配布する platform）と、コード以外の物（画像・フォントなど。`git ls-files` 全体と参照元）のライセンスと権利を一覧にし、オープンソースのライセンス（MIT が候補）を付けるのに妨げになる物と、確かめきれない物を報告する。今夜は PR を出すところまで。

## 守ること（制約）

- `LICENSE` ファイルはまだ付けない（追加しない、README にもライセンス表記を書かない）。
- 調べる道具はリポジトリを汚さない形で使う。道具のインストール・スクリプト・中間出力はシステムの一時ディレクトリに置く。リポジトリの `Gemfile`・`Gemfile.lock`・`.bundle/` は変えない。
- backend の hook（lefthook）の動きを変えない（`lefthook.yml`・`.lefthook/` に触れない）。
- 依頼のほかの部分（CI に入れる道具、PR 本文の確かめ）とは独立。互いを待たず、それらの成果物（CI 用ツールの導入など）を先取りしない。
- リポジトリのルールファイルとスキルに従う（コミット・ブランチ・PR は `git-spice-workflow` スキル、計画は `.claude/rules/plans-maintenance.md`）。
- 法的な結論は出さない。一覧は「判断の材料」と「要確認事項」として書く。

## やらないこと

- `LICENSE` の追加、ライセンスの決定。
- 調べる道具（LicenseFinder など）やスクリプトをリポジトリに入れること、CI への組み込み。
- gem の入れ替え・削除・バージョン変更、ファイルの差し替え（妨げの解消は報告まで）。
- 未追跡のファイル（例: `_bmad/`）や submodule の中身の全ファイル調査（submodule は参照先のリポジトリ単位で扱う）。
- Ruby 本体・OS パッケージ（Docker イメージの中身）の全件調査。gem が使うシステムライブラリは gem の行の注記にとどめる。

## 確かめた事実（2026-11-18 時点の main）

- `Gemfile.lock` の GEM 節: 166 エントリ（platform 別の変種を含む）。`BUNDLED WITH 2.6.9`。
- `PLATFORMS`: `aarch64-linux`, `arm64-darwin-24`, `arm64-darwin-25`, `x86_64-linux`（`ruby` platform なし）。
- platform 別の変種がある gem: `ffi 1.17.3`（aarch64-linux-gnu / arm64-darwin / x86_64-linux-gnu）、`nokogiri 1.19.2`（同 3 種）。
- group: `Bundler.definition.specs_for` で default 105、development 114、test 59 を得られる（実行して確認）。
- この環境（aarch64-linux）に入っている gem 163 件は、どれも gemspec の `licenses` が空でない（実行して確認）。
- gem の同梱ライセンス文書を読める: 例 `nokogiri-1.19.2-aarch64-linux-gnu` に `LICENSE.md` と `LICENSE-DEPENDENCIES.md`（同梱 C ライブラリのライセンス）、`ffi` に `COPYING`・`LICENSE`・`LICENSE.SPECS`。
- rubygems.org API v2（`/api/v2/rubygems/<name>/versions/<version>.json?platform=<platform>`）に、このコンテナから到達でき、platform 別の `licenses` を返す（`nokogiri 1.19.2 arm64-darwin` → `["MIT"]` を確認）。
- システムライブラリへの依存: `image_processing` → ruby-vips → libvips（`Docker/api/Dockerfile` で `libvips42` を入れる）、`mysql2` → MySQL クライアントライブラリ。どちらも gem には同梱されない。
- `vendor/` は `.keep` だけ。gem はリポジトリに同梱されていない。
- `git ls-files`: 323 件。バイナリは `.bruno/Collection/480x320.png` の 1 件だけ（`file --mime-type` で確認）。フォント・その他画像はない。
  - `480x320.png` の参照元: `.bruno/Collection/Auth/Change User Info.bru`（`avatar: @file(480x320.png)`）。追加コミット `b48e28cf1`（2025-09-04）。出所の記載なし。
- 第三者由来の候補（中身の出所が外部にあるもの）:
  - `.claude/skills/gh-stack/`（4 ファイル）: frontmatter に `author: github`、`github-repo: https://github.com/github/gh-stack`、`github-ref: refs/tags/v0.3.0`。上流から取り込んだもの（コミット `6c75ae3de`）。
  - `config/locales/devise_token_auth.ja.yml`: 冒頭に devise_token_auth と devise の参照 URL（短縮 URL）。gem の locale を元にした可能性。
  - `config/locales/active_storage_validations.ja.yml`: 冒頭に active_storage_validations の参照 URL（短縮 URL）。
  - `Docker/web/nginx/nginx.conf`: nginx の既定設定を元にした可能性（未確認）。
  - `.github/COMMIT_CONVENTION`: submodule（`https://github.com/P-manBrown/commit-convention.git`）。
- `ARCHITECTURE.md` のルールは鳥瞰図・コードマップ用で、頻繁に変わる情報を書かない。`docs/decisions/` は設計判断の経緯用。

## 前提（自律実行のため bead に記録する）

1. **「配布する platform」** = `Gemfile.lock` の `PLATFORMS` にある 4 つ全部。platform 別の変種は変種ごとに 1 行にする。
2. **「全 group」** = default・development・test。lockfile の各エントリに、それを必要とする group をすべて付ける（推移的な依存を含む）。どの group にも入らないエントリ（platform 不一致など）は「どの group からも使われない」と明記する。`bundler` 自体も 1 行入れる。
3. **成果物の置き場** = `docs/license-inventory.md`（1 ファイル）。`ARCHITECTURE.md`・`docs/decisions/` の用途に合わないため新しいファイルにする。時点（日付と調べた main のコミット）を冒頭に書く「スナップショット」とし、自動更新はしない。
4. **「妨げ」の判定基準**（法的結論ではなく分類）:
   - リポジトリに同梱される物（追跡ファイル）: 第三者の権利があり、ライセンスが不明・再配布不可・MIT と両立しない条件（強いコピーレフトなど）のもの → 妨げ候補。MIT 等で両立するが著作権表示の保持が要るもの → 「表示が必要」として列挙（妨げではない）。
   - gem（リポジトリに同梱されない依存）: 強いコピーレフト（GPL・AGPL）、ライセンスの宣言がない・独自・不明なもの → 妨げ候補または要確認。弱いコピーレフト（LGPL・MPL）→ 注記付きで列挙。寛容なライセンス（MIT・BSD・Apache-2.0・ISC・Ruby など）→ 問題なし。
5. **「確かめきれない物」** = 宣言と同梱ライセンス文書が食い違う、宣言が無い、出所の記録が無い（例: png）、上流のライセンスをこの環境から確認できない、のいずれか。
6. **PR**: 依頼は「今夜は PR を出すところまで」。一方、このワークフローの変数は `open_pr=false`、`push=true`。PR を出すかどうかは formula の後段（finishing / マージ系の lane）の設定に従い、この設計は「PR に載せられる 1 コミット分の変更」を作るところまでを範囲とする。食い違いは「未解決の点」に記録する。

## 方式の比較

### 案 A（推奨）: lockfile を起点にした一時スクリプト ＋ 同梱文書の確認 ＋ 手作業の出所調べ

- gem: 一時ディレクトリの Ruby スクリプトが `Gemfile.lock` を `Bundler::LockfileParser` で読み、全エントリ（166 ＋ bundler）を列挙。group は `Bundler.definition.specs_for` で付ける。ライセンスは、この環境に入っている変種は gemspec の `licenses` と同梱のライセンス文書（`LICENSE*`・`COPYING*` など）の両方、入っていない platform 変種は rubygems.org API v2 の `licenses` で取る。platform 変種を持つ gem（nokogiri・ffi）は同梱 C ライブラリのライセンス文書（`LICENSE-DEPENDENCIES.md` など）を読む。
- 追跡ファイル: `git ls-files` 全件をスクリプトで分類（拡張子・`file --mime-type`・初出コミット・ヘッダーの参照 URL）し、第三者由来の候補は人の手（この作業者）で上流を確認する。
- 長所: platform 変種まで正確。依頼の「全 group・配布する platform」をそのまま満たす。リポジトリに何も入れない。追加のツールのインストールが要らない。
- 短所: スクリプトを書く手間。ライセンス文書の自動判別は単純な照合にとどまり、食い違いは人が読む。

### 案 B: LicenseFinder を一時 GEM_HOME に入れて実行

- 長所: 成熟した道具。ライセンス文書からの推定もある。
- 短所: この環境の platform（aarch64-linux）しか見ない。group の扱いが粗い（除外指定が中心）。依頼の別部分「CI に入れる道具」の選定と重なり、先取りになる。結局、他の platform と同梱 C ライブラリは別に調べる必要がある。

### 案 C: rubygems.org API だけで調べる

- 長所: インストール不要で全 platform を均一に扱える。
- 短所: gemspec の宣言しか見えず、同梱文書との食い違いや同梱 C ライブラリを見落とす。

**推奨: 案 A。** 依頼の範囲（全 group・配布する platform）を満たす唯一の案で、制約（リポジトリを汚さない、CI 用ツールを先取りしない）にも合う。

## 設計

### 1. 成果物

`docs/license-inventory.md`（日本語）を 1 コミットで追加する。それ以外のファイルは変えない。構成:

1. **冒頭**: 目的、時点（日付・調べた main のコミット）、調べ方の要約（一時ディレクトリのスクリプト、API、同梱文書）、法的結論ではないこと、`LICENSE` は未追加であること。
2. **報告: 妨げになる物**: 項目ごとに対象・理由・根拠（ファイルパスや URL）・考えられる対応（報告のみ、実施しない）。無ければ「無し」と書く。
3. **報告: 確かめきれない物**: 項目ごとに対象・何が確かめきれないか・確かめる方法。
4. **gem の一覧**: 表（名前・バージョン・platform・group・宣言ライセンス・同梱文書で確認したライセンス・根拠・分類）。分類は「問題なし／注記あり／要確認／妨げ候補」。システムライブラリへの依存（libvips、MySQL クライアント）は注記に書く。
5. **コード以外の物（追跡ファイル）の一覧**: 323 件を分類し、件数を示す。自作のコード・文書・設定はカテゴリ単位で件数とパスの範囲を書き、第三者由来・出所不明・バイナリは 1 件ずつ（パス・参照元・出所・ライセンス・分類）。submodule は参照先のリポジトリ単位で 1 行。

### 2. 調べ方（作業の流れ）

1. 作業ブランチ（`git-spice-workflow` スキルに従う）を worktree で作る。
2. システムの一時ディレクトリ（例: `mktemp -d`）にスクリプトと中間出力（JSON/CSV）を置く。リポジトリは読むだけ。
3. gem のデータを集める（案 A）。API 呼び出しは platform 変種のある gem と、この環境に入っていない変種だけ。
4. 追跡ファイルを分類し、第三者由来の候補（gh-stack skill、locale yml 2 件、nginx.conf、png、submodule、ほかに見つかったもの）の上流ライセンスを確認する。
5. 集めたデータから `docs/license-inventory.md` を書く（表は生成し、報告の 2 節は人が読んで書く）。
6. 確かめ: `git status` で変更が `docs/license-inventory.md` だけであること、`lefthook.yml`・`.lefthook/`・`Gemfile*` が無変更であること、一覧の件数が lockfile の 166 ＋ bundler と `git ls-files` の 323 に合うこと。

### 3. 失敗・例外の扱い

- API に届かない、または応答が無い変種 → その行を「要確認（API 取得失敗）」にし、「確かめきれない物」に入れる。作業は止めない。
- 宣言ライセンスと同梱文書が食い違う → 両方を書き、「確かめきれない物」に入れる。
- 出所の記録が無いファイル → 「確かめきれない物」に入れ、git の履歴から分かることを書く。
- コミット時に lefthook の pre-commit が動く。失敗したら内容を直す（hook を飛ばさない）。

### 4. 確かめ方（テスト）

コードを入れないため自動テストは追加しない。代わりに:

- 件数の照合（gem 行数 = lockfile エントリ数 ＋ bundler、追跡ファイルの分類の合計 = `git ls-files` の件数）。
- 抜き取り: platform 変種（nokogiri・ffi）の 3 変種がそれぞれ行になっていること、group が dev のみの gem（例: rubocop）と default の gem（例: rails）の group が正しいこと。
- `git status`・`git diff --stat` で変更範囲の確認。
- リポジトリの pre-commit hook（lefthook）がそのまま通ること。

## 受け入れ基準

1. `docs/license-inventory.md` があり、変更はこのファイル 1 つだけ。`LICENSE` は無い。
2. `Gemfile.lock` の全エントリ（platform 変種ごと）と bundler が 1 行ずつあり、各行に group・宣言ライセンス・根拠・分類がある。
3. platform 変種を持つ gem は、同梱 C ライブラリのライセンスが注記されている。
4. `git ls-files` の全件がいずれかのカテゴリに入り、合計が一致する。第三者由来・出所不明・バイナリは 1 件ずつ参照元と出所が書かれている。
5. 「妨げになる物」「確かめきれない物」の 2 節があり、各項目に根拠がある（無ければ「無し」）。
6. 調べる道具・中間出力がリポジトリに残っていない。`lefthook.yml`・`.lefthook/`・`Gemfile*` は無変更。
7. コミットとブランチは `git-spice-workflow` スキルに従っている。

## 後段への申し送り（この設計の範囲での扱いは決定済み）

- **PR を出すかどうか**: 依頼は「PR を出すところまで」、ワークフロー変数は `open_pr=false`。設計の範囲外（後段の lane の設定に従う）。人の回答を待たずに進める。後段で PR が出ない場合、依頼の達成には別途 PR 作成が要る点を後段の bead に残すこと。
- **計画の要否**: `.claude/rules/plans-maintenance.md` は複数の段に分かれる実装で計画を求める。この作業は 1 コミットの文書追加で、段に分かれない見込み。判断は planning lane に任せる。

## 承認の状態

- 状態: 承認済み（autonomous、承認 lane tb-cyd40 が判定。要約は approval-summary.md）。
- 根拠: 依頼文（tb-4txu8）が成果（一覧と 2 種の報告）・範囲（全 group・配布する platform・`git ls-files` 全体）・制約（LICENSE 無し、リポジトリを汚さない、lefthook 不変、PR まで）を決めており、残る解釈（platform の範囲、成果物の置き場、妨げの基準）は上の「前提」でリポジトリの事実から決めた。人の回答を要する問いは無い。
