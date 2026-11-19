# ライセンスの洗い出し

Spec: .claude/specs/license-inventory.md

## Context/Purpose

`LICENSE`をこのリポジトリに付ける前に、どのライセンスの物を使っているかを事実で確かめるため、`Gemfile.lock`の全エントリ（4 platform・全group）と`git ls-files`の全件のライセンスの一覧と、ライセンスの選択を妨げる物・確かめきれない物の2つの報告を、`docs/license-inventory.md`の1コミットで追加する。`LICENSE`の追加・CI用ツール・依存の変更は範囲外。

この計画は、Gas Cityのbuild（`superpowers-build`、作業名`license-inventory`）で承認された計画を、リポジトリの置き場所に写したもの。要件は`.claude/specs/license-inventory-requirements.md`、設計は`.claude/specs/license-inventory.md`にある。実装（`docs/license-inventory.md`の追加）は、計画の「Task 1」として`docs/license-inventory`ブランチ（PR #830）で行った。以降の「Implementation Plan」は承認時の計画の本文で、書かれた数（167・323など）は`main`が`c73626cd`の時点の値。

## Decision Log

- 2026-11-18: 調べ方は、`Gemfile.lock`を起点にした一時スクリプト、同梱文書の確認、手作業の出所調べとする（設計の案A）。LicenseFinder（案B）は環境のplatformしか見ず、rubygems.org APIだけ（案C）は同梱文書との食い違いや同梱 C ライブラリを見落とすため採らない
- 2026-11-18: 成果物の置き場は`docs/license-inventory.md`の1ファイルとし、日付と調べた`main`のコミットを冒頭に書くスナップショットにする。`ARCHITECTURE.md`・`docs/decisions/`の用途に合わないため
- 2026-11-18: 「配布するplatform」は`PLATFORMS`の4つ全部、「全group」はdefault・development・testとし、platform変種は1行ずつにする
- 2026-11-18: 実装のTaskは1つにする。分けると、件数の照合の検査が途中の段で成り立たないため
- 2026-11-18: 調べる道具は一時ディレクトリに置き、リポジトリに残さない
- 2026-11-18: WTFPLは寛容な一覧に入れず、gemは「要確認」、由来のファイルは「確かめきれない」とする。その他の前提は「Risks and Assumptions」に書いた

## Validation and Acceptance

受け入れ基準（設計の「受け入れ基準」と同じ）。

- `docs/license-inventory.md`があり、変更はこのファイル1つだけ。`LICENSE`は無い
- `Gemfile.lock`の全エントリ（platform変種ごと）とbundlerが1行ずつあり、各行にgroup・宣言ライセンス・根拠・分類がある
- platform変種を持つgemは、同梱 C ライブラリのライセンスが注記されている
- `git ls-files`の全件がいずれかのカテゴリに入り、合計が一致する。第三者由来・出所不明・バイナリは1件ずつ参照元と出所が書かれている
- 「妨げになる物」「確かめきれない物」の2節があり、各項目に根拠がある（無ければ「無し」）
- 調べる道具・中間出力がリポジトリに残っていない。`lefthook.yml`・`.lefthook/`・`Gemfile*`は無変更
- コミットとブランチは`git-spice-workflow` skillに従っている

確かめ方は、以降の「Verification」に書いた。

# Implementation Plan

**Goal:** `Gemfile.lock` の全エントリと `git ls-files` の全件のライセンスの一覧と、「妨げになる物」「確かめきれない物」の 2 つの報告を、`docs/license-inventory.md` の 1 コミットで追加する。

**Architecture:** 調べる道具は、システムの一時ディレクトリ（`$WORK`）に置く Ruby スクリプト 4 本（gem の収集、追跡ファイルの分類、上流のライセンスの取得、出来上がった文書の検査）。表は生成し、報告の 2 節と 1 件ずつ扱うファイルの行は、生成物と上流を人が読んで書く。リポジトリに入るのは `docs/license-inventory.md` だけ。

**Tech Stack:** Ruby 4.0（`Bundler::LockfileParser`・`Bundler.definition.specs_for`・`Gem::Specification`・`Net::HTTP`）、`file --mime-type`、git、git-spice、lefthook。

---

## Summary

- 依頼 bead tb-4txu8、ワークフロー root tb-nvhlu。承認済みの要件（REQ-001〜007）と設計（案 A）の実装の計画
- 実装の Task は **1 つ**（Task 1）。変更は `docs/license-inventory.md` の追加 1 ファイルで、1 コミットにまとまる。Task を分けると、検査（件数の照合）が途中の段で成り立たないため分けない
- 計画を書く前に、計画に載せるスクリプトをこの lane の一時ディレクトリで 2026-11-18 の main（`c73626cd`）に対して実際に動かし、次を確かめた（数は実装時の main で変わりうる。スクリプトは数を固定していない）
  - gem の収集: 167 行（`Gemfile.lock` の 166 エントリ ＋ `bundler`）。分類は 問題なし 156・注記あり 6・要確認 5。`rubocop` の group は development だけ、`rails` は default。nokogiri・ffi の 3 変種はどれも default を含む
  - 追跡ファイルの分類: 323 件がすべてカテゴリに入り、合計が一致
  - 文書の検査スクリプト: 文書が無いと失敗し、行の欠け・件数の食い違いを見つけ、正しい形の文書で OK を返す
  - 調べた後の `git status` はこの lane の前からある未追跡の `_bmad/` だけ（リポジトリに何も残らない）
- 要件の候補（REQ-004）に加えて、ヘッダーの短縮 URL から第三者由来の候補がさらに 7 件見つかった（下の「Current System」）。Task 1 で 1 件ずつ扱う
- この計画は、承認後に、リポジトリの決まりの置き場所（`.claude/plans/active/`）へ写した。実装の時点ではリポジトリに計画は無かった

## Current System

### リポジトリの状態（2026-11-18 の main `c73626cd`）

- `docs/` には `docs/decisions/` だけがある。`docs/license-inventory.md` と `LICENSE` は無い
- `Gemfile.lock`: GEM 節 166 エントリ、`PLATFORMS` は `aarch64-linux`・`arm64-darwin-24`・`arm64-darwin-25`・`x86_64-linux`、`BUNDLED WITH 2.6.9`
- この環境（aarch64-linux、Ruby 4.0.0、Bundler 2.6.9）に入っていない変種は 4 つ: `ffi-1.17.3-arm64-darwin`・`ffi-1.17.3-x86_64-linux-gnu`・`nokogiri-1.19.2-arm64-darwin`・`nokogiri-1.19.2-x86_64-linux-gnu`。`Bundler.definition.specs_for` はこの 4 つに group を返さない（ほかの 162 エントリと `bundler` には返す）
- 宣言ライセンスの内訳（gemspec と API）: MIT 129、Ruby 27、BSD-2-Clause 26、Apache-2.0 5（うち 1 つは `msgpack` の表記揺れ `Apache 2.0`）、BSD-3-Clause 4、ISC 1、WTFPL 1（`devise_token_auth`）、`diff-lcs` が MIT・Artistic-1.0-Perl・GPL-2.0-or-later の 3 つ（同梱の `LICENCE.md` に「3 つのうちから選べる」とある）
- 同梱 C ライブラリ
  - nokogiri: `LICENSE-DEPENDENCIES.md` の platform 別の節。Linux 版は libxml2（MIT）・libxslt（MIT）・libgumbo（Apache 2.0）・zlib（zlib license）。Darwin 版はそれに libiconv（LGPL）が加わる（同じ文書に「libiconv は Windows と Darwin の版だけに同梱」とある）
  - ffi: `COPYING` に「libffi は MIT」とある
- gem の同梱文書が無いのは 9 gem（debride・htmlbeautifier・lefthook・lumberjack・minitest・omniauth-google-oauth2・omniauth-twitter・path_expander・sexp_processor）。LEGAL 文書に例外の記載があるのは base64・json・rdoc
- `git ls-files`: 323 件。シンボリックリンク 1 件（`.bruno/Collection/.env`）、submodule 1 件（`.github/COMMIT_CONVENTION`、`https://github.com/P-manBrown/commit-convention.git`、GitHub API はライセンスを返さない（404））、バイナリ 1 件（`.bruno/Collection/480x320.png`、追加コミット `b48e28cf1` 2025-09-04、参照元 `.bruno/Collection/Auth/Change User Info.bru`）
- 第三者由来の候補（ヘッダーの URL を展開して確かめた上流）

  | パス | ヘッダーの URL | 上流 | 上流のライセンス（GitHub API） |
  | --- | --- | --- | --- |
  | `.claude/skills/gh-stack/` の 4 ファイル | `https://github.com/github/gh-stack` | github/gh-stack（`refs/tags/v0.3.0`） | MIT |
  | `config/locales/devise_token_auth.ja.yml` | `https://tinyurl.com/2ochwp9b`・`https://tinyurl.com/22favuhh` | devise_token_auth の `config/locales/ja.yml`、devise-i18n の `rails/locales/ja.yml` | WTFPL、MIT |
  | `config/locales/active_storage_validations.ja.yml` | `https://tinyurl.com/yw8trctz` | active_storage_validations の `config/locales/ja.yml` | MIT |
  | `config/locales/active_record.ja.yml`（要件の候補に無い） | `https://tinyurl.com/aczke9k` | rails-i18n の `rails/locale/ja.yml` | MIT |
  | `app/views/devise/mailer/confirmation_instructions.html.erb`（同） | `https://tinyurl.com/23vzmcv3` | devise_token_auth の同名ファイル | WTFPL |
  | `app/views/devise/mailer/email_changed.html.erb`（同） | `https://tinyurl.com/2y44ysbj` | devise の同名ファイル | MIT |
  | `app/views/devise/mailer/password_change.html.erb`（同） | `https://tinyurl.com/257jo5go` | devise の同名ファイル | MIT |
  | `app/views/devise/mailer/reset_password_instructions.html.erb`（同） | `https://tinyurl.com/2ysv8kyb` | devise の同名ファイル | MIT |
  | `app/views/devise_token_auth/omniauth_external_window.html.erb`（同） | `https://is.gd/v9evAO` | devise_token_auth の同名ファイル | WTFPL |
  | `app/models/concerns/user_override.rb`（同） | `https://tinyurl.com/2detqylw` | devise_token_auth の `app/models/devise_token_auth/concerns/user.rb` | WTFPL |
  | `Docker/web/nginx/nginx.conf` | 無し | nginx の公式 Docker イメージの既定の設定の可能性（未確認）。nginx/nginx と nginx/docker-nginx はどちらも BSD-2-Clause | — |

- 上流の issue や文書を指すだけのヘッダーの URL がある、カテゴリに入れるファイル: `app/controllers/api/v1/auth/omniauth_callbacks_controller.rb`（devise_token_auth の issue 1591 のコメント）、`app/controllers/api/v1/auth/passwords_controller.rb`（issue 1561）、`app/controllers/api/v1/auth/registrations_controller.rb`（issue 432）、`config/initializers/cors.rb`、`config/initializers/pagy.rb`、`Guardfile`、`.gitignore`、`.gitattributes`、`public/robots.txt` など
- コミット時の lefthook の pre-commit: `docs/*.md` に `.lefthook/pre-commit/check-docs.sh` が動く。`docs/` の下の Markdown の相対リンクを、リンク元のディレクトリを基準に通常ファイルの存在（`-f`）で確かめる。`protect-branch` は main へのコミットを止める。pre-push の `check-git-clean` は作業ツリーが汚れていると push を止める
- この環境の Claude Code では、Bash の `curl`・`wget` と、コマンドの中に直接書いた HTTP（例: `ruby -e '... Net::HTTP.get(...)'`）を context-mode の hook が止める。HTTP はファイルに置いた Ruby スクリプト（`Net::HTTP`）を `ruby <ファイル>` で走らせて使う（下のスクリプトはそうしてあり、この lane で走ることを確かめた）

## Proposed Implementation

### File structure

- Create: `docs/license-inventory.md`（日本語、1 ファイル。リポジトリに入る唯一の変更）
- 一時ディレクトリ `$WORK`（`mktemp -d` で作る。リポジトリの外）に置く物。どれもリポジトリに入れない
  - `$WORK/collect_gems.rb`: gem の行を集め、`$WORK/gems.json` と `$WORK/gems_table.md` を書く
  - `$WORK/classify_files.rb`: `git ls-files` を分類し、`$WORK/files.json` を書き、件数と確かめる候補を表示する
  - `$WORK/upstream_license.rb`: 短縮 URL を展開し、GitHub のリポジトリのライセンスを GitHub API で取る
  - `$WORK/fetch.rb`: URL の中身を標準出力に出す（上流のファイルとの比較用）
  - `$WORK/check_inventory.rb`: 出来上がった文書を `Gemfile.lock` と `git ls-files` に照らして検査する（受け入れ基準 1〜6 の機械的に確かめられる部分）
  - `$WORK/01-head.md`・`$WORK/02-gems-intro.md`・`$WORK/03-files.md`・`$WORK/commit-msg.txt`: 文書の部品とコミットメッセージ

### 文書の形（`check_inventory.rb` が前提にする形）

見出しと表の見出し行は、この通りの文字列で書く（この計画の中では、計画自体の節と混ざらないよう、文書の第 2 階層の見出しをコード表記で示す）。

- 見出しの並び: `# tascon-backend のライセンスの洗い出し` → 冒頭（目的、時点、調べ方、法的結論ではないこと、`LICENSE` が未追加であること）→ `## 妨げになる物` → `## 確かめきれない物` → `## gem の一覧` → `## コード以外の物（追跡ファイル）`（その中に `### カテゴリ別の件数` と `### 1 件ずつ扱う物`）
- 第 2 階層の見出し `## gem の一覧` と `## コード以外の物（追跡ファイル）` は、Step 11 の組み立てのコマンドが入れる（部品のファイルには書かない）。`## 妨げになる物` と `## 確かめきれない物` は Step 9 で `$WORK/01-head.md` に書く
- 「妨げになる物」の 1 項目の形:

  ```markdown
  ### <対象>

  - 理由: ...
  - 根拠: ...
  - 考えられる対応: ...（報告のみ。実施しない）
  ```

- 「確かめきれない物」の 1 項目の形:

  ```markdown
  ### <対象>

  - 何が確かめきれないか: ...
  - 根拠: ...
  - 確かめる方法: ...
  ```

- 表の見出し行（上から gem の一覧、カテゴリ別の件数、1 件ずつ扱う物）:

  ```markdown
  | 名前 | バージョン | platform | group | 宣言ライセンス | 同梱文書で確かめたライセンス | 根拠 | 分類 | 注記 |
  | カテゴリ | 件数 | パスの範囲 | 備考 |
  | パス | 参照元 | 出所 | ライセンス | 分類 |
  ```

- 該当が無い報告の節は、本文を `無し` の 1 行だけにする
- 文書の中で相対リンク（Markdown のリンク記法）を使わない。リポジトリのパスはすべてコード表記（バッククォート）で書く。URL は `https://...` のまま書いてよい（`check-docs.sh` は http のリンクを飛ばす）。こうすると、ディレクトリ・submodule・空白を含むパスをリンクにしてしまう失敗が起きない
- 表のセルの中の `|` は `\|` にする（`collect_gems.rb` はそうしている）

### 分類の決め方（設計の「前提」4・5 を、この作業で出てくる物に当てはめた規則）

- gem の行の分類は `collect_gems.rb` が付ける。規則: 宣言がすべて寛容なライセンス（MIT・BSD-2-Clause・BSD-3-Clause・Apache-2.0・ISC・Ruby・0BSD・Unlicense・CC0-1.0・Zlib）なら「問題なし」。寛容なものと非寛容なものが混ざる、または LGPL・MPL なら「注記あり」。GPL・AGPL だけなら「妨げ候補」。宣言無し・上の一覧に無い宣言（例: WTFPL）は「要確認」。同梱 C ライブラリやシステムライブラリがある gem は「問題なし」を「注記あり」にする。この環境に入っていない変種は「要確認」、API に届かなければ「要確認（API 取得失敗）」。同梱文書の判別結果が宣言と同じ系統を 1 つも含まなければ「要確認」にして注記を付ける
- gem の行のうち「妨げ候補」は「妨げになる物」に、「要確認」「要確認（API 取得失敗）」は「確かめきれない物」に 1 項目ずつ入れる。「確かめきれない物」の見出しは `### <名前> <バージョン> <platform>` の形にする（検査スクリプトが `nokogiri 1.19.2 arm64-darwin` のような文字列で探す）
- WTFPL の扱い（要件に明記が無い点。この計画の前提として決める）: WTFPL は寛容だが OSI の承認が無く、上の寛容な一覧に入れない。gem（`devise_token_auth`）は「要確認」、WTFPL の上流に由来するファイルは「確かめきれない」とし、どちらも「確かめきれない物」に入れて、確かめる方法に「持ち主が、WTFPL の物を MIT のプロジェクトに含めてよいかを、上流の LICENSE（`https://github.com/lynndylanhurley/devise_token_auth/blob/master/LICENSE`）を読んで決める」と書く
- 1 件ずつ扱うファイルの分類: 自作なら「問題なし」。第三者由来で、上流のライセンスが寛容で、著作権表示の保持が要る（MIT・BSD など）なら「表示が必要」（妨げではない。「ライセンス」の列に「上流の著作権表示がリポジトリに無い」かどうかを書く）。上流のライセンスが不明・再配布不可・MIT と両立しない（強いコピーレフトなど）なら「妨げ候補」で「妨げになる物」に入れる。出所の記録が無い、上流をこの環境から確かめられない、WTFPL なら「確かめきれない」で「確かめきれない物」に入れる
- 上流の issue や文書を指すだけのファイル（コードや文の写しが無いと読んで確かめた物）はカテゴリに入れたままにし、カテゴリの「備考」にその旨とファイル名を書く。読んで写しがあると分かったら、`classify_files.rb` の `INDIVIDUAL` に足して 1 件ずつ扱う

### Task 1: `docs/license-inventory.md` を追加する（gem とコード以外の物のライセンスの一覧と 2 つの報告）

**Files:**
- Create: `docs/license-inventory.md`
- Test（リポジトリに入れない）: `$WORK/check_inventory.rb`

**Context:** この Task は、この計画の「Current System」と、「Proposed Implementation」の「File structure」「文書の形」「分類の決め方」を前提にする。実装の bead にはこの計画のパス（`.claude/plans/active/license-inventory.md`）を載せ、それらの節も読んでから始める。

**Acceptance criteria（要件の受け入れの条件 1〜7 と同じ）:**
1. `main` との差分が `docs/license-inventory.md` の追加だけで、`LICENSE` が無い
2. gem の一覧の行数が `Gemfile.lock` の GEM 節のエントリ数 ＋ 1 で、各行に group・宣言ライセンス・根拠・分類がある
3. nokogiri・ffi が 3 行ずつで、どの行も group に default を含み、同梱 C ライブラリの注記がある。この環境に入っていない 4 変種の「同梱文書で確かめたライセンス」が「未インストールのため未確認」で、4 変種が「確かめきれない物」に `gem fetch` を使う確かめる方法付きで入っている。`rubocop` の group は development だけ、`rails` の group に default がある
4. カテゴリの件数の合計が `git ls-files | wc -l` と一致し、REQ-004 の候補・バイナリ・submodule と、この計画で見つけた候補が 1 件ずつ参照元・出所付きで書かれている
5. 「妨げになる物」「確かめきれない物」の 2 節があり、各項目に根拠がある（無ければ「無し」）
6. リポジトリに道具・スクリプト・中間出力が無く、`lefthook.yml`・`.lefthook/`・`Gemfile`・`Gemfile.lock`・`.bundle/` に差分が無い。lefthook の pre-commit を飛ばさずに通っている。相対リンクが無い
7. ブランチとコミットが `git-spice-workflow` Skill の形に従っている

- [ ] **Step 1: 作業場所とブランチを用意する**

実装の lane が worktree を用意していればそこで作業する。無ければ `superpowers:using-git-worktrees` に従って `main` から worktree を作る。実装の lane がブランチも用意済みなら、それが `main` から切られた `<type>/<変更内容>` の形のブランチであることを確かめて使い、下の `branch create` は飛ばす。無ければ worktree の中で、`git-spice-workflow` Skill に従ってブランチを作る（ほかの作業に依存しないので `main` から切る。type はこの変更の技術的な性質から `docs`）。

```bash
git-spice ls --all
git-spice branch create docs/license-inventory --no-commit --target main
git branch --show-current
```

Expected: 最後の行が `docs/license-inventory`。`git-spice ls --all` で `docs/license-inventory` の下にほかのブランチが積まれていない。worktree で依存（gem）が入っていなければ、リポジトリの `project-setup` Skill に従って入れる（`bundle exec ruby -e 'puts :ok'` が `ok` を出せばよい）。

- [ ] **Step 2: 一時ディレクトリを作り、文書の検査スクリプトを置く**

```bash
WORK="$(mktemp -d)"
echo "$WORK"
```

以降のコマンドの `$WORK` は、ここで表示されたパスに読み替える（シェルの変数がコマンドの間で引き継がれないため）。Write ツールで `$WORK/check_inventory.rb` を次の内容で作る。

```ruby
# Usage (from the worktree root): bundle exec ruby "$WORK/check_inventory.rb" docs/license-inventory.md
# Checks the inventory against Gemfile.lock and `git ls-files`. Prints every failure and exits 1 if any.
require 'bundler'

path = ARGV.fetch(0)
failures = []
fail_with = ->(msg) { failures << msg }

unless File.file?(path)
  puts "FAIL: #{path} does not exist"
  exit 1
end
doc = File.read(path)

# Returns the body of "## <title>" up to the next "## " heading.
section = lambda do |title|
  doc[/^## #{Regexp.escape(title)}\n(.*?)(?=^## |\z)/m, 1]
end

# Returns the rows (arrays of cells) of the first table in text whose header starts with header_prefix.
table = lambda do |text, header_prefix|
  lines = text.to_s.lines.map(&:strip)
  start = lines.index { |l| l.start_with?(header_prefix) }
  next nil unless start

  lines[(start + 2)..].take_while { |l| l.start_with?('|') }.map do |l|
    l.sub(/\A\|/, '').sub(/\|\z/, '').split(/(?<!\\)\|/).map(&:strip)
  end
end

# REQ-001: the header states purpose, snapshot, method, that it is not a legal conclusion, and that LICENSE is absent.
head = doc.split(/^## /, 2).first
main_short = `git rev-parse --short=8 main`.strip
fail_with.call("header does not name the main commit #{main_short}") unless head.include?(main_short[0, 7])
fail_with.call('header has no date (YYYY-MM-DD)') unless /\d{4}-\d{2}-\d{2}/.match?(head)
fail_with.call('header does not say it is not a legal conclusion') unless head.include?('法的')
fail_with.call('header does not say LICENSE is not added') unless head.include?('LICENSE')
fail_with.call('LICENSE file exists') if File.exist?('LICENSE')

# REQ-005: both report sections exist; each item has 根拠 and the action / the way to check.
{ '妨げになる物' => '考えられる対応', '確かめきれない物' => '確かめる方法' }.each do |title, action|
  body = section.call(title)
  if body.nil?
    fail_with.call("section ## #{title} is missing")
    next
  end
  next if body.strip == '無し'

  items = body.split(/^### /)[1..] || []
  fail_with.call("section ## #{title} has neither items (### ...) nor 無し") if items.empty?
  items.each do |item|
    name = item.lines.first.strip
    fail_with.call("#{title} / #{name}: no 根拠 line") unless /^- 根拠: \S/.match?(item)
    fail_with.call("#{title} / #{name}: no #{action} line") unless /^- #{action}: \S/.match?(item)
  end
end

# REQ-002 / REQ-003: one row per lockfile entry plus bundler, with the required cells.
lock = Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock'))
gems = table.call(section.call('gem の一覧'), '| 名前 | バージョン | platform | group |')
if gems.nil?
  fail_with.call('gem table is missing')
else
  expected = lock.specs.size + 1
  fail_with.call("gem table has #{gems.size} rows, expected #{expected}") unless gems.size == expected
  gems.each do |r|
    fail_with.call("gem row #{r[0]} #{r[2]} has #{r.size} cells, expected 9") unless r.size == 9
    [3, 4, 6, 7].each { |i| fail_with.call("gem row #{r[0]} #{r[2]} has an empty cell #{i + 1}") if r[i].to_s.empty? }
  end
  %w[nokogiri ffi].each do |n|
    rows = gems.select { |r| r[0] == n }
    fail_with.call("#{n} has #{rows.size} rows, expected 3") unless rows.size == 3
    rows.each { |r| fail_with.call("#{n} #{r[2]} group lacks default") unless r[3].split(', ').include?('default') }
    fail_with.call("#{n} rows lack the bundled C library note") unless rows.all? { |r| r[8].include?('同梱 C ライブラリ') }
    rows.reject { |r| r[2] == 'aarch64-linux-gnu' }.each do |r|
      fail_with.call("#{n} #{r[2]} doc cell is #{r[5]}") unless r[5] == '未インストールのため未確認'
      unchecked = section.call('確かめきれない物').to_s
      unless unchecked.include?("#{n} #{r[1]} #{r[2]}") && unchecked.include?('gem fetch')
        fail_with.call("#{n} #{r[1]} #{r[2]} is not in 確かめきれない物 with the gem fetch method")
      end
    end
  end
  rubocop = gems.find { |r| r[0] == 'rubocop' }
  fail_with.call("rubocop group is #{rubocop && rubocop[3]}") unless rubocop && rubocop[3] == 'development'
  rails = gems.find { |r| r[0] == 'rails' }
  fail_with.call('rails group lacks default') unless rails && rails[3].split(', ').include?('default')
end

# REQ-004: the category counts add up to `git ls-files`; the listed candidates are rows of the per-file table.
files_section = section.call('コード以外の物（追跡ファイル）')
categories = table.call(files_section, '| カテゴリ | 件数 |')
individual = table.call(files_section, '| パス | 参照元 | 出所 | ライセンス | 分類 |')
tracked = `git ls-files`.lines.size
if categories.nil? || individual.nil?
  fail_with.call('category table or per-file table is missing')
else
  sum = categories.sum { |r| r[1].to_i }
  fail_with.call("category counts add up to #{sum}, git ls-files has #{tracked}") unless sum == tracked
  individual_count = categories.select { |r| r[0].start_with?('個別') }.sum { |r| r[1].to_i }
  unless individual.size == individual_count
    fail_with.call("per-file table has #{individual.size} rows, 個別 categories count #{individual_count}")
  end
  paths = individual.map { |r| r[0].delete('`') }
  %w[
    .claude/skills/gh-stack/SKILL.md
    .claude/skills/gh-stack/references/commands.md
    .claude/skills/gh-stack/references/stack-design.md
    .claude/skills/gh-stack/references/troubleshooting.md
    config/locales/devise_token_auth.ja.yml
    config/locales/active_storage_validations.ja.yml
    Docker/web/nginx/nginx.conf
    .bruno/Collection/480x320.png
    .github/COMMIT_CONVENTION
  ].each { |p| fail_with.call("per-file table lacks #{p}") unless paths.include?(p) }
  individual.each do |r|
    fail_with.call("per-file row #{r[0]} has an empty cell") if r.size != 5 || r.any?(&:empty?)
  end
end

# REQ-006: relative links are left to check-docs.sh; this document uses none.
fail_with.call('the document has a relative Markdown link') if doc.scan(/\]\(([^)]+)\)/).flatten.any? do |l|
  l !~ %r{\A(https?://|#)}
end

if failures.empty?
  puts 'OK'
else
  failures.each { |f| puts "FAIL: #{f}" }
  exit 1
end
```

- [ ] **Step 3: 検査スクリプトが、文書が無い状態で失敗することを確かめる**

Run（worktree の根で）: `bundle exec ruby "$WORK/check_inventory.rb" docs/license-inventory.md`
Expected: `FAIL: docs/license-inventory.md does not exist` と終了コード 1。Bundler の `already initialized constant Gem::Platform::...` の警告が出るが、この環境の Ruby 4.0 と Bundler 2.6.9 の組み合わせの既知の警告で、結果に関係しない。

- [ ] **Step 4: gem の行を集める**

Write ツールで `$WORK/collect_gems.rb` を次の内容で作る。

```ruby
# Usage (from the worktree root): bundle exec ruby "$WORK/collect_gems.rb" "$WORK"
# Reads Gemfile.lock. Writes "$WORK/gems.json" and "$WORK/gems_table.md". Prints a one-line JSON summary.
require 'bundler'
require 'json'
require 'net/http'

out_dir = ARGV.fetch(0)
GROUPS = %i[default development test].freeze
ALIASES = { 'Apache 2.0' => 'Apache-2.0', 'BSD' => 'BSD-2-Clause' }.freeze
PERMISSIVE = %w[MIT BSD-2-Clause BSD-3-Clause Apache-2.0 ISC Ruby 0BSD Unlicense CC0-1.0 Zlib].freeze
WEAK = /\A(LGPL|MPL)/
STRONG = /\A(GPL|AGPL)/
DOC_RE = /\A(LICEN[CS]E|COPYING|MIT-LICENSE|LEGAL|NOTICE)/i
C_LIB_DOCS = { 'nokogiri' => 'LICENSE-DEPENDENCIES.md' }.freeze
SYSTEM_LIB = {
  'mysql2' => 'システムの MySQL クライアントライブラリ（libmysqlclient または libmariadb）にリンクする。gem には同梱されない',
  'ruby-vips' => 'システムの libvips（LGPL-2.1-or-later）を実行時に読み込む。Docker/api/Dockerfile で libvips42 を入れる。gem には同梱されない',
  'image_processing' => 'ruby-vips 経由でシステムの libvips を使う（ruby-vips の行を参照）'
}.freeze

def normalize(id)
  ALIASES.fetch(id, id)
end

# "GPL-2.0-or-later" -> "GPL", "Apache-2.0" -> "Apache", "BSD-3-Clause" -> "BSD-3-Clause"
def family(id)
  id.sub(/-(only|or-later)\z/, '').sub(/-\d+(\.\d+)*\z/, '')
end

def detect(raw)
  text = raw.gsub(/\s+/, ' ')
  found = []
  found << 'LGPL' if /GNU (LESSER|LIBRARY) GENERAL PUBLIC LICENSE/i.match?(text)
  found << 'GPL' if /GNU GENERAL PUBLIC LICENSE|GNU GPL/i.match?(text)
  found << 'MPL-2.0' if /Mozilla Public License/i.match?(text)
  found << 'Apache-2.0' if /Apache License,? Version 2\.0/i.match?(text)
  if /is copyrighted free software|2-clause BSDL|covered (under|by) (either )?the Ruby('s)? license/i.match?(text)
    found << 'Ruby'
  end
  found << 'BSD-2-Clause' if /BSD-2-Clause license/i.match?(text)
  found << 'MIT' if /Permission is hereby granted, free of charge/i.match?(text)
  if %r{Permission to use, copy, modify, and(/or)? distribute this software for any purpose}i.match?(text)
    found << 'ISC'
  end
  found << 'WTFPL' if /DO WHAT THE FUCK YOU WANT TO/i.match?(text)
  if /Redistribution and use in source and binary forms/i.match?(text)
    found << (/Neither the name|names of (its|the) contributors/i.match?(text) ? 'BSD-3-Clause' : 'BSD-2-Clause')
  end
  found.empty? ? ['判別不可'] : found
end

def classify(licenses)
  return '要確認' if licenses.nil? || licenses.empty?
  return '問題なし' if licenses.all? { |l| PERMISSIVE.include?(l) }
  return '注記あり' if licenses.any? { |l| PERMISSIVE.include?(l) || l =~ WEAK }
  return '妨げ候補' if licenses.any? { |l| l =~ STRONG }

  '要確認'
end

# Reads the platform section of nokogiri's LICENSE-DEPENDENCIES.md and returns "libxml2（MIT）, ..." for it.
def nokogiri_c_libs(doc_path, platform)
  lines = File.readlines(doc_path, chomp: true)
  heading = platform.include?('darwin') ? /\A### Native Darwin/ : /\A### Native Linux/
  start = lines.index { |l| l =~ heading }
  return '該当する platform の節が見つからない' unless start

  names = lines[(start + 1)..].take_while { |l| !l.start_with?('#') }.filter_map { |l| l[/\A\* \[([^\]]+)\]/, 1] }
  names.map do |n|
    at = lines.index("### #{n}")
    lic = at && lines[(at + 1)..].find { |l| !l.strip.empty? }
    "#{n}（#{lic ? lic.strip : '不明'}）"
  end.join(', ')
end

def api_licenses(name, version, platform)
  uri = URI("https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}.json?platform=#{platform}")
  res = Net::HTTP.get_response(uri)
  return [nil, "API #{res.code}"] unless res.is_a?(Net::HTTPSuccess)

  data = JSON.parse(res.body)
  return [nil, "API の platform 不一致（#{data['platform']}）"] unless data['platform'] == platform

  [Array(data['licenses']).map { |l| normalize(l) }, nil]
rescue StandardError => e
  [nil, "API 取得失敗（#{e.class}）"]
end

lock = Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock'))
groups = Hash.new { |h, k| h[k] = [] }
GROUPS.each do |g|
  Bundler.definition.specs_for([g]).each { |s| groups[[s.name, s.version.to_s, s.platform.to_s]] << g }
end

entries = lock.specs.map { |s| [s.name, s.version.to_s, s.platform.to_s] }
entries << ['bundler', lock.bundler_version.to_s, 'ruby']

rows = entries.map do |name, version, platform|
  installed = Gem::Specification.find_all_by_name(name, version).find { |i| i.platform.to_s == platform }
  sibling_key = groups.keys.find { |k| k[0] == name && k[1] == version && k[2] != platform }
  sibling = sibling_key && Gem::Specification.find_all_by_name(name, version).find { |i| i.platform.to_s == sibling_key[2] }
  evidence = []
  notes = []
  g = groups[[name, version, platform]]
  if g.empty? && installed.nil? && sibling_key
    g = groups[sibling_key]
    evidence << "group はこの環境の変種（#{sibling_key[2]}）から引き継いだ"
  end
  if installed
    declared = installed.licenses.map { |l| normalize(l) }
    evidence << 'gemspec の licenses'
    docs = Dir.children(installed.full_gem_path).grep(DOC_RE)
              .select { |f| File.file?(File.join(installed.full_gem_path, f)) }.sort
    detected = []
    doc_parts = docs.map do |f|
      next "#{f}: 同梱 C ライブラリの文書（注記を参照）" if C_LIB_DOCS[name] == f

      text = File.binread(File.join(installed.full_gem_path, f)).force_encoding('UTF-8').scrub
      ids = detect(text)
      detected.concat(ids - ['判別不可'])
      "#{f}: #{ids.join(', ')}"
    end
    doc_col = docs.empty? ? '同梱文書無し' : doc_parts.join('; ')
    evidence << (docs.empty? ? '同梱文書無し' : "同梱文書 #{docs.join(', ')}")
    category = classify(declared)
    if !detected.empty? && (detected.map { |l| family(l) } & declared.map { |l| family(l) }).empty?
      category = '要確認'
      notes << '宣言と同梱文書の判別結果が食い違う候補（人が読んで確かめる）'
    end
    notes << '宣言が複数。同梱文書で選択式か併用かを確かめる' if declared.size > 1 && !declared.all? { |l| PERMISSIVE.include?(l) }
    notes << '判別不可の同梱文書がある（人が読んで確かめる）' if doc_parts.any? { |p| p.include?('判別不可') }
    notes << 'LEGAL・NOTICE の文書に例外の記載がある（人が読んで確かめる）' if docs.any? { |f| f =~ /\A(LEGAL|NOTICE)/i }
  else
    declared, err = api_licenses(name, version, platform)
    evidence << (err ? "rubygems.org API v2: #{err}" : "rubygems.org API v2 の licenses（/api/v2/rubygems/#{name}/versions/#{version}.json?platform=#{platform}）")
    doc_col = '未インストールのため未確認'
    category = err ? '要確認（API 取得失敗）' : '要確認'
  end
  src = installed || sibling
  if C_LIB_DOCS.key?(name) && src
    libs = nokogiri_c_libs(File.join(src.full_gem_path, C_LIB_DOCS[name]), platform)
    from = installed ? '' : "（この環境に入っている変種 #{src.full_name} の同梱文書から引いた）"
    notes << "同梱 C ライブラリ: #{libs}。根拠 #{C_LIB_DOCS[name]} の #{platform.include?('darwin') ? 'Native Darwin' : 'Native Linux'} の節#{from}"
    category = '注記あり' if category == '問題なし'
  end
  if name == 'ffi' && src
    from = installed ? '' : "（この環境に入っている変種 #{src.full_name} の同梱文書から引いた）"
    notes << "同梱 C ライブラリ: libffi（MIT）。根拠 COPYING の libffi の記載#{from}"
    category = '注記あり' if category == '問題なし'
  end
  if SYSTEM_LIB.key?(name)
    notes << SYSTEM_LIB[name]
    category = '注記あり' if category == '問題なし'
  end
  {
    name: name, version: version, platform: platform,
    groups: g.empty? ? ['どの group からも使われない'] : g.map(&:to_s),
    declared: declared, doc: doc_col, evidence: evidence, category: category, notes: notes, installed: !installed.nil?
  }
end

File.write(File.join(out_dir, 'gems.json'), JSON.pretty_generate(rows))
cell = ->(v) { v.to_s.gsub('|', '\\|') }
table = [
  '| 名前 | バージョン | platform | group | 宣言ライセンス | 同梱文書で確かめたライセンス | 根拠 | 分類 | 注記 |',
  '| --- | --- | --- | --- | --- | --- | --- | --- | --- |'
]
rows.sort_by { |r| [r[:name], r[:platform]] }.each do |r|
  declared = if r[:declared].nil? then '取得できず'
             elsif r[:declared].empty? then '宣言無し'
             else r[:declared].join(', ')
             end
  cells = [r[:name], r[:version], r[:platform], r[:groups].join(', '), declared, r[:doc],
           r[:evidence].join('; '), r[:category], r[:notes].empty? ? '-' : r[:notes].join('; ')]
  table << "| #{cells.map { |c| cell.call(c) }.join(' | ')} |"
end
File.write(File.join(out_dir, 'gems_table.md'), table.join("\n") + "\n")
puts JSON.generate(rows: rows.size, lock_specs: lock.specs.size,
                   categories: rows.group_by { |r| r[:category] }.transform_values(&:size))
```

Run（worktree の根で）: `bundle exec ruby "$WORK/collect_gems.rb" "$WORK" 2>/dev/null`
Expected（main `c73626cd` のとき）: `{"rows":167,"lock_specs":166,"categories":{"問題なし":156,"要確認":5,"注記あり":6}}`。`rows` は必ず `lock_specs + 1`。main が進んで数が変わっていたら、その数を正とする。`要確認（API 取得失敗）` が出たら、その行を「確かめきれない物」に入れて先へ進む（止めない）。

- [ ] **Step 5: 人の判断が要る gem の行の注記を書き直す**

`$WORK/gems.json` の `notes` に「人が読んで確かめる」「選択式か併用か」を含む行について、同梱文書を読み、`$WORK/gems_table.md` のその行の「注記」のセルを、Edit ツールで読んだ結果に置き換える。main `c73626cd` での対象と、読んだ結果の書き方は次のとおり（実装時に同じ文書を読んで確かめてから書く）。

- `diff-lcs`: `宣言が複数。同梱文書で選択式か併用かを確かめる` → `LICENCE.md に GPL-2.0-or-later・Artistic-1.0-Perl・MIT の 3 つから選べるとある（MIT を選べる）`。分類は「注記あり」のまま
- `json`: `LEGAL・NOTICE の文書に例外の記載がある（人が読んで確かめる）` → `LEGAL: Ruby または public-domain。例外 ext/json/ext/vendor/fpconv.h（BSL-1.0）・jeaiii-ltoa.h（MIT）・ryu.h（Apache-2.0 または BSL-1.0）`
- `rdoc`: 同じ注記 → `LEGAL.rdoc` に挙がっている例外（Aliki（MIT）・Darkfish（BSD-3-Clause）・SDoc（MIT）・peg-markdown（MIT）など）を、文書に書かれている名前とライセンスのとおりに列挙する
- `base64`: 同じ注記 → 同梱の `LEGAL` を読み、例外の名前とライセンスを列挙する。場所は `bundle exec gem contents base64 | grep -i legal` で分かる

読む対象の一覧を出すコマンド:

```bash
bundle exec ruby -rjson -e 'JSON.parse(File.read(ARGV[0])).each { |r| n = r["notes"].grep(/人が読んで|選択式/); puts "#{r["name"]} #{r["version"]} #{r["platform"]}: #{n.join(" / ")}" unless n.empty? }' "$WORK/gems.json"
```

- [ ] **Step 6: 追跡ファイルを分類する**

Write ツールで `$WORK/classify_files.rb` を次の内容で作る。

```ruby
# Usage (from the worktree root): ruby "$WORK/classify_files.rb" "$WORK"
# Classifies every `git ls-files` entry. Writes "$WORK/files.json" and prints the per-category counts,
# the files listed one by one, and the files whose first 10 lines hold a URL (to review by hand).
# Exits 1 when a file matches no category, so the categories stay complete.
require 'json'
require 'open3'

out_dir = ARGV.fetch(0)

# Files listed one by one (third-party candidates, origin unknown). Binaries and submodules are added automatically.
INDIVIDUAL = %w[
  .claude/skills/gh-stack/SKILL.md
  .claude/skills/gh-stack/references/commands.md
  .claude/skills/gh-stack/references/stack-design.md
  .claude/skills/gh-stack/references/troubleshooting.md
  config/locales/devise_token_auth.ja.yml
  config/locales/active_storage_validations.ja.yml
  config/locales/active_record.ja.yml
  Docker/web/nginx/nginx.conf
  app/views/devise/mailer/confirmation_instructions.html.erb
  app/views/devise/mailer/email_changed.html.erb
  app/views/devise/mailer/password_change.html.erb
  app/views/devise/mailer/reset_password_instructions.html.erb
  app/views/devise_token_auth/omniauth_external_window.html.erb
  app/models/concerns/user_override.rb
].freeze

CATEGORIES = [
  ['アプリのコード', %r{\A(app|lib)/}],
  ['DB のマイグレーションとスキーマ', %r{\Adb/}],
  ['テスト', %r{\Aspec/}],
  ['Rails・Ruby の設定と起動スクリプト',
   %r{\A(config/|bin/|public/|Gemfile\z|Gemfile\.lock\z|Rakefile\z|config\.ru\z|Guardfile\z|\.rspec\z|\.rubocop\.yml\z|\.ruby-version\z|debride-whitelist\.txt\z)}],
  ['コンテナと開発環境の設定',
   %r{\A(Docker/|\.devcontainer/|\.vscode/|compose\.yml\z|\.dockerignore\z|\.editorconfig\z|\.env\z|\.worktreeinclude\z)}],
  ['Git と GitHub の設定', %r{\A(\.github/|\.gitignore\z|\.gitattributes\z|\.gitmodules\z)}],
  ['lefthook（コミット時の確かめ）', %r{\A(lefthook\.yml\z|\.lefthook/)}],
  ['API の手動確認用の Bruno コレクション', %r{\A\.bruno/}],
  ['Claude Code の設定・ルール・Skill・計画・技術的負債', %r{\A\.claude/}],
  ['文書', %r{\A(docs/|README\.md\z|ARCHITECTURE\.md\z|AGENTS\.md\z)}],
  ['空ディレクトリを保つための空ファイル', %r{\A(log|tmp|storage|vendor)/}]
].freeze

def sh(*cmd)
  out, status = Open3.capture2(*cmd)
  raise "failed: #{cmd.join(' ')}" unless status.success?

  out
end

entries = sh('git', 'ls-files', '-s', '-z').split("\0").map do |line|
  meta, path = line.split("\t", 2)
  { mode: meta.split(' ', 2).first, path: path }
end

files = entries.map do |e|
  path = e[:path]
  submodule = e[:mode] == '160000'
  symlink = e[:mode] == '120000'
  mime = if submodule then 'submodule'
         elsif symlink then "symlink -> #{File.readlink(path)}"
         else sh('file', '--mime-type', '-b', '--', path).strip
         end
  binary = !submodule && !symlink && !(mime.start_with?('text/') || %w[application/json inode/x-empty].include?(mime))
  added = sh('git', 'log', '--diff-filter=A', '--format=%h %cs', '-1', '--', path).strip
  urls = if submodule || symlink || binary
           []
         else
           File.foreach(path).first(10).join.scan(%r{https?://[^\s)>"']+}).uniq
         end
  category = if submodule then '個別（submodule）'
             elsif binary then '個別（バイナリ）'
             elsif INDIVIDUAL.include?(path) then '個別（第三者由来の候補）'
             else CATEGORIES.find { |(_, re)| re.match?(path) }&.first
             end
  referenced_by = if category&.start_with?('個別')
                    # A binary is referenced by its file name (e.g. @file(480x320.png)); a text file by its path.
                    needle = binary ? File.basename(path) : path
                    out, = Open3.capture2('git', 'grep', '-l', '-F', '--', needle)
                    out.split("\n").reject { |f| f == path }
                  else
                    []
                  end
  { path: path, category: category, mime: mime, added: added, urls: urls, referenced_by: referenced_by }
end

File.write(File.join(out_dir, 'files.json'), JSON.pretty_generate(files))

unmatched = files.select { |f| f[:category].nil? }
counts = files.group_by { |f| f[:category] }.transform_values(&:size)
puts "total=#{files.size} categorized_sum=#{counts.reject { |k, _| k.nil? }.values.sum}"
counts.each do |k, v|
  ranges = files.select { |f| f[:category] == k }.map { |f| f[:path].include?('/') ? "#{f[:path].split('/').first}/" : f[:path] }.uniq.sort
  puts "  #{k}: #{v} | #{ranges.join(' ')}"
end
puts 'individual:'
files.select { |f| f[:category]&.start_with?('個別') }.each do |f|
  puts "  #{f[:path]} | #{f[:category]} | #{f[:mime]} | added #{f[:added]} | urls #{f[:urls].join(' ')} | referenced_by #{f[:referenced_by].join(', ')}"
end
puts 'header URLs in categorized files (review by hand):'
files.reject { |f| f[:category].nil? || f[:category].start_with?('個別') || f[:urls].empty? }.each do |f|
  puts "  #{f[:path]} | #{f[:urls].join(' ')}"
end
unless unmatched.empty?
  warn "unmatched (add a category or an INDIVIDUAL entry): #{unmatched.map { |f| f[:path] }.join(', ')}"
  exit 1
end
```

Run（worktree の根で）: `ruby "$WORK/classify_files.rb" "$WORK"`
Expected（main `c73626cd` のとき）: 1 行目が `total=323 categorized_sum=323`、終了コード 0。`individual:` に 16 行（バイナリ 1・submodule 1・第三者由来の候補 14）。`unmatched ...` が出て終了コード 1 になったら、そのファイルを読み、自作なら `CATEGORIES` の合うカテゴリの正規表現に足し、第三者由来・出所不明なら `INDIVIDUAL` に足して、もう一度走らせる。

- [ ] **Step 7: ヘッダーの URL があるカテゴリのファイルを読み、写しが無いことを確かめる**

`classify_files.rb` の出力の `header URLs in categorized files (review by hand):` に並ぶファイルのうち、`.claude/plans/`・`.claude/tech-debt/`・`docs/decisions/` の文書（作業記録の中の参考 URL）以外を読む。短縮 URL は Step 8 の `upstream_license.rb` で展開できる。上流のコードや文の写しが無ければカテゴリのままにして、Step 10 でカテゴリの「備考」に「上流の issue・文書への参照だけ（写しが無いことを読んで確かめた）: <ファイル名>」と書く。写しがあれば `INDIVIDUAL` に足して Step 6 をやり直す。main `c73626cd` での対象は `app/controllers/api/v1/auth/` の 3 つの controller、`config/initializers/cors.rb`、`config/initializers/pagy.rb`、`Guardfile`、`.gitignore`、`.gitattributes`、`.gitmodules`、`public/robots.txt`、`README.md`、`Gemfile`、`Gemfile.lock`、`.env`、`.bruno/Collection/environments/Development.bru`。

- [ ] **Step 8: 1 件ずつ扱うファイルの上流を確かめる**

Write ツールで `$WORK/upstream_license.rb` を次の内容で作る。

```ruby
# Usage: ruby "$WORK/upstream_license.rb" <url-or-owner/repo>...
# A short URL (is.gd, tinyurl.com) is expanded first. For a GitHub repository, prints the license that
# the GitHub API detects (SPDX id) and the URL of the license file.
require 'json'
require 'net/http'

# Follows up to 5 redirects. Returns [final_url, last_response].
def follow(url)
  res = nil
  5.times do
    res = Net::HTTP.get_response(URI(url))
    break unless res.is_a?(Net::HTTPRedirection)

    url = URI.join(url, res['location']).to_s
  end
  [url, res]
end

ARGV.each do |arg|
  url = arg.start_with?('http') ? follow(arg).first : "https://github.com/#{arg}"
  repo = url[%r{\Ahttps://github\.com/([^/]+/[^/#?]+)}, 1]&.delete_suffix('.git')
  unless repo
    puts "#{arg} -> #{url} | GitHub のリポジトリではない"
    next
  end
  _, res = follow("https://api.github.com/repos/#{repo}/license")
  if res.is_a?(Net::HTTPSuccess)
    data = JSON.parse(res.body)
    puts "#{arg} -> #{url} | #{repo} | #{data.dig('license', 'spdx_id')} | #{data['html_url']}"
  else
    puts "#{arg} -> #{url} | #{repo} | GitHub API #{res.code}"
  end
rescue StandardError => e
  puts "#{arg} | 取得失敗（#{e.class}）"
end
```

Run:

```bash
ruby "$WORK/upstream_license.rb" github/gh-stack https://tinyurl.com/2ochwp9b https://tinyurl.com/22favuhh https://tinyurl.com/yw8trctz https://tinyurl.com/aczke9k https://tinyurl.com/23vzmcv3 https://tinyurl.com/2y44ysbj https://tinyurl.com/257jo5go https://tinyurl.com/2ysv8kyb https://is.gd/v9evAO https://tinyurl.com/2detqylw nginx/nginx nginxinc/docker-nginx https://github.com/P-manBrown/commit-convention.git
```

Expected（2026-11-18 に確かめた値）: gh-stack・devise・devise-i18n・active_storage_validations・rails-i18n は `MIT`、devise_token_auth は `WTFPL`、nginx と docker-nginx は `BSD-2-Clause`、commit-convention は `GitHub API 404`。GitHub API が 403（回数の上限）を返したら、時間を置いてやり直すか、その行を「確かめきれない」にして先へ進む。

続けて、写しの範囲を確かめる。Write ツールで `$WORK/fetch.rb` を次の内容で作る。

```ruby
# Usage: ruby "$WORK/fetch.rb" <url> > <file>
# Prints the body of url to stdout, following up to 5 redirects. Exits 1 on a non-2xx response.
require 'net/http'

url = ARGV.fetch(0)
5.times do
  res = Net::HTTP.get_response(URI(url))
  if res.is_a?(Net::HTTPRedirection)
    url = URI.join(url, res['location']).to_s
    next
  end
  unless res.is_a?(Net::HTTPSuccess)
    warn "HTTP #{res.code} #{url}"
    exit 1
  end
  print res.body
  exit 0
end
warn "too many redirects: #{url}"
exit 1
```

上流のファイル（GitHub の `blob` の URL を `https://raw.githubusercontent.com/<owner>/<repo>/<ref>/<path>` に直したもの）を取ってきて、リポジトリのファイルと比べる。例:

```bash
mkdir -p "$WORK/upstream"
ruby "$WORK/fetch.rb" https://raw.githubusercontent.com/heartcombo/devise/a259ff3c28912a27329727f4a3c2623d3f5cb6f2/app/views/devise/mailer/email_changed.html.erb > "$WORK/upstream/email_changed.html.erb"
diff "$WORK/upstream/email_changed.html.erb" app/views/devise/mailer/email_changed.html.erb
```

Expected: 差分が出る（2026-11-18 に確かめた結果では、リポジトリの版は 1 行目に `<%# Override https://tinyurl.com/2y44ysbj %>` があり、文を日本語にした上流の上書き）。上流の構造を元にした上書きなので、「出所」に「上流 <URL> を元に日本語化・変更」、「ライセンス」に上流のライセンスを書く。

同じことを、Current System の表の上流を持つ 1 件ずつ扱うファイルすべてに行う（`master`・`main` を指す URL は、取り込んだ時点ではなく今の上流と比べることになる点を「出所」の列に書く）。gh-stack の上流の場所は `skills/gh-stack/SKILL.md`・`skills/gh-stack/references/commands.md`・`skills/gh-stack/references/stack-design.md`・`skills/gh-stack/references/troubleshooting.md`（`https://api.github.com/repos/github/gh-stack/git/trees/v0.3.0?recursive=1` で確かめた）で、`https://raw.githubusercontent.com/github/gh-stack/v0.3.0/skills/gh-stack/<相対パス>` と比べる。nginx.conf は、上流のファイルをこの環境から特定できなければ「確かめきれない」にする。png は `git show --stat b48e28cf1` と `git log --format='%h %an %cs %s' -- .bruno/Collection/480x320.png` で分かることを「出所」に書き、「確かめきれない」にする。

- [ ] **Step 9: 冒頭と 2 つの報告を書く**

Write ツールで `$WORK/01-head.md` を作る。冒頭は次の形にし、`<...>` を実際の値にする（`git rev-parse --short main` と `date +%F`）。

```markdown
# tascon-backend のライセンスの洗い出し

tascon-backend にオープンソースのライセンス（MIT が候補）を付けるかを決めるための材料として、依存の gem とリポジトリに入っているファイルのライセンスと権利の状況をまとめる。

- 時点: <YYYY-MM-DD> の main（<短いコミット ID>）のスナップショット。自動では更新しない。依存の更新（Dependabot の bundler の日次更新）で古くなる
- 範囲: `Gemfile.lock` の全エントリ（`PLATFORMS` の 4 つの platform の変種ごと）と `bundler`、`git ls-files` の全件。未追跡のファイル、submodule の中身、Ruby 本体と Docker イメージの OS パッケージは含めない
- 調べ方: システムの一時ディレクトリに置いた Ruby スクリプトで、`Gemfile.lock` を `Bundler::LockfileParser` で読み、group を `Bundler.definition.specs_for` で付けた。ライセンスは、この環境（aarch64-linux）に入っている変種は gemspec の `licenses` と同梱のライセンス文書、入っていない変種は rubygems.org API v2 の `licenses` から取った。追跡ファイルは拡張子・`file --mime-type`・初出コミット・ヘッダーの参照 URL で分類し、第三者由来の候補は上流を GitHub API と上流のファイルとの比較で確かめた。スクリプトはリポジトリに入れていない
- 分類: gem は「問題なし／注記あり／要確認／妨げ候補」、1 件ずつ扱うファイルは「問題なし／表示が必要／確かめきれない／妨げ候補」。基準は各表の前に書く
- これは法的な結論ではない。判断の材料と、確かめが要る事項の一覧である
- `LICENSE` はまだ追加していない
```

続けて同じファイルに `## 妨げになる物` と `## 確かめきれない物` を、「文書の形」と「分類の決め方」に従って書く。

- 「妨げになる物」: gem の「妨げ候補」の行と、1 件ずつ扱うファイルの「妨げ候補」を 1 項目ずつ。無ければ本文は `無し`
- 「確かめきれない物」: 少なくとも次を 1 項目ずつ（main `c73626cd` のとき）
  - `ffi 1.17.3 arm64-darwin`・`ffi 1.17.3 x86_64-linux-gnu`・`nokogiri 1.19.2 arm64-darwin`・`nokogiri 1.19.2 x86_64-linux-gnu`: 何が確かめきれないか「この環境に入っていない変種で、同梱文書を読んでいない（宣言は API で取得）」、根拠「rubygems.org API v2 の URL、この環境に入っている変種の同梱文書」、確かめる方法「システムの一時ディレクトリで `gem fetch <名前> -v <バージョン> --platform <platform>` と `gem unpack <名前>-<バージョン>-<platform>.gem` をして同梱文書を読む」。nokogiri の Darwin 版は libiconv（LGPL）を同梱する点も書く
  - `devise_token_auth 1.2.6 ruby`（WTFPL）と、WTFPL の上流に由来するファイル（Step 8 の結果による）
  - `.bruno/Collection/480x320.png`（出所の記録が無い。git の履歴から分かることを書き、確かめる方法は「持ち主が出所を確かめるか、自作の画像に差し替える」）
  - `.github/COMMIT_CONVENTION`（持ち主の別リポジトリで、ライセンスが宣言されていない。確かめる方法は「持ち主が commit-convention のライセンスを決める」）
  - `Docker/web/nginx/nginx.conf`（Step 8 で上流を特定できなかった場合）
  - gem の「要確認」の行のうち上に無い物、Step 4 の `要確認（API 取得失敗）` の行、Step 5 で宣言と同梱文書の食い違いと分かった物

- [ ] **Step 10: gem の一覧とコード以外の物の部品を書く**

Write ツールで `$WORK/02-gems-intro.md` を作る（見出し `## gem の一覧` は Step 11 の組み立てが入れる）。

```markdown
`Gemfile.lock` の 1 エントリ（platform の変種ごと）と `bundler` を 1 行にした。group は推移的な依存を含めて付けた。この環境に入っていない変種の group は、同じ名前・バージョンでこの環境に入っている変種から引き継ぎ、根拠にそう書いた。「同梱文書で確かめたライセンス」は同梱のライセンス文書の文面からの判別で、判別が宣言と食い違う候補と判別できなかった文書は人が読んで注記に結果を書いた。

分類の基準: 宣言がすべて寛容なライセンス（MIT・BSD・Apache-2.0・ISC・Ruby など）なら「問題なし」、寛容なものと非寛容なものが混ざる・LGPL・MPL・同梱 C ライブラリやシステムライブラリがあるなら「注記あり」、GPL・AGPL だけなら「妨げ候補」、宣言無し・その他の宣言・未インストールの変種・API 取得失敗は「要確認」。gem はリポジトリに同梱されない依存として分類した。

```

Write ツールで `$WORK/03-files.md` を作る（見出し `## コード以外の物（追跡ファイル）` は Step 11 の組み立てが入れる）。中身は次の形。カテゴリの表は `classify_files.rb` の出力の件数とパスの範囲をそのまま写し、1 件ずつの表は Step 6〜8 の結果から書く。

```markdown
`git ls-files` の <件数> 件を、次のカテゴリに分けた（合計 <件数>）。自作のコード・文書・設定はカテゴリ単位で書き、第三者由来の候補・出所不明・バイナリ・submodule は下の表で 1 件ずつ書いた。

分類の基準: 自作は「問題なし」。第三者由来で寛容なライセンス（著作権表示の保持が要る物）は「表示が必要」（妨げではない）。出所の記録が無い・上流をこの環境から確かめられない・WTFPL は「確かめきれない」。ライセンスが不明・再配布不可・MIT と両立しない条件は「妨げ候補」。

### カテゴリ別の件数

| カテゴリ | 件数 | パスの範囲 | 備考 |
| --- | --- | --- | --- |
| アプリのコード | <件数> | `app/`・`lib/` | 自作。上流の issue・文書への参照だけ（写しが無いことを読んで確かめた）: <Step 7 のファイル名> |
| （classify_files.rb が出したカテゴリを 1 行ずつ。個別（…）の 3 つも件数付きで 1 行ずつ入れ、パスの範囲は「下の表」とする） | | | |

### 1 件ずつ扱う物

| パス | 参照元 | 出所 | ライセンス | 分類 |
| --- | --- | --- | --- | --- |
| `.bruno/Collection/480x320.png` | `.bruno/Collection/Auth/Change User Info.bru`（`avatar: @file(480x320.png)`） | 出所の記載無し。追加コミット `b48e28cf1`（2025-09-04、<作者>） | 不明 | 確かめきれない |
| （Step 6 の individual: の残り 15 行を同じ形で） | | | | |
```

この中の 2 行の「（…）」は書き方の説明で、文書には残さない（実際の行に置き換える）。「参照元」は `classify_files.rb` の `referenced_by` を使い、空のときは読み込む仕組みを書く（例: `config/locales/` の yml は「Rails の i18n が `config/locales/` の下を読み込む」、`app/views/devise/mailer/` は「devise のメール送信が同名のビューを使う」、gh-stack は「Claude Code が `.claude/skills/` の Skill として読み込む」、nginx.conf は `Docker/web/Dockerfile`）。submodule の行は「参照元」を `.gitmodules`、「出所」を `https://github.com/P-manBrown/commit-convention.git`（このリポジトリの持ち主の別リポジトリ）とする。「Rails・Ruby の設定と起動スクリプト」の備考に「`rails new` の生成物を元にしたファイルを含む（Rails は MIT）」と書く。`.bruno/Collection/.env` はシンボリックリンク（リンク先はリポジトリの `.env`）で Bruno のカテゴリに入っている旨を、そのカテゴリの備考に書く。

- [ ] **Step 11: 文書を組み立てて検査する**

```bash
{
  cat "$WORK/01-head.md"
  printf '\n## gem の一覧\n\n'
  cat "$WORK/02-gems-intro.md"
  printf '\n'
  cat "$WORK/gems_table.md"
  printf '\n## コード以外の物（追跡ファイル）\n\n'
  cat "$WORK/03-files.md"
} > docs/license-inventory.md
bundle exec ruby "$WORK/check_inventory.rb" docs/license-inventory.md 2>/dev/null
bash .lefthook/pre-commit/check-docs.sh
```

Expected: `check_inventory.rb` が `OK` を出して終了コード 0。`check-docs.sh` が何も出さずに終了コード 0。`FAIL:` が出たら、その行が指す部品（`$WORK` の md）を直して組み立てからやり直す。`gems_table.md` を直した場合も組み立てからやり直す（`docs/license-inventory.md` を直接直すと、次の組み立てで消える）。

- [ ] **Step 12: 抜き取りで中身を確かめる**

```bash
grep -E '^\| (nokogiri|ffi|rubocop|rails|bundler|diff-lcs|devise_token_auth) \|' docs/license-inventory.md
grep -c '未インストールのため未確認' docs/license-inventory.md
grep -n -E '<(YYYY|短い|件数|作者|Step|対象)|（classify_files|（Step 6' docs/license-inventory.md
```

Expected: nokogiri と ffi が 3 行ずつで group に `default` がある。`rubocop` の group が `development`、`rails` が `default`、`bundler` が `default, development, test`。`diff-lcs` と `json`・`rdoc`・`base64` の注記が Step 5 の結果になっている。2 つ目の数が 4（gem の 4 行。報告の節で同じ語を使えばその分増える）。3 つ目は何も出ない（書き方の説明が残っていない）。文書全体を通して読み、「（…）」の説明文や `<...>` が残っていないことを確かめる。

- [ ] **Step 13: 変更の範囲を確かめる**

```bash
git status --porcelain
git diff --stat main -- Gemfile Gemfile.lock lefthook.yml .lefthook .bundle
ls LICENSE 2>&1
```

Expected: `git status --porcelain` が `?? docs/license-inventory.md` の 1 行だけ（worktree によっては、もとからある未追跡の物が並ぶ。それらは触らない）。2 つ目は何も出さない。3 つ目は `ls: cannot access 'LICENSE': No such file or directory`。

- [ ] **Step 14: コミットする**

Write ツールで `$WORK/commit-msg.txt` を次の内容で作る（`git-spice-workflow` Skill に従い英語。subject は小文字で始め、末尾に `.` を付けない。body は最終状態と理由）。

```text
docs: add the license inventory of gems and tracked files

Add docs/license-inventory.md, a dated snapshot that lists the license
of every Gemfile.lock entry (each platform variant, every group) and of
every tracked file, with two reports: what may block adding an open
source license and what could not be confirmed, each with its evidence.

The repository owner needs this to decide whether to add a license
such as MIT. It is not a legal conclusion, and no LICENSE file is
added.
```

Skill はコミットの前にメッセージの日本語訳をユーザーに示すことを求める。自律の lane では、実装の bead の notes に次の訳を書いてからコミットする: 「docs: gem と追跡ファイルのライセンスの一覧を追加する / Gemfile.lock の全エントリ（platform の変種ごと・全 group）と全追跡ファイルのライセンスと、オープンソースのライセンスを付ける妨げになりうる物・確かめきれなかった物の 2 つの報告（それぞれ根拠付き）を載せた、日付付きのスナップショット docs/license-inventory.md を追加する。/ リポジトリの持ち主が MIT などのライセンスを付けるかを決めるために要る。法的な結論ではなく、LICENSE ファイルは追加しない。」

```bash
git add docs/license-inventory.md
git-spice commit create -F "$WORK/commit-msg.txt"
git log -1 --stat --format='%h %s'
git status --porcelain
```

Expected: lefthook の pre-commit（`check-docs.sh`・`check-plan-completion.sh`・`protect-branch` など）が通ってコミットができる。`--no-verify` は使わない。hook が落ちたら内容を直して Step 11 からやり直す。`git log -1 --stat` の変更が `docs/license-inventory.md` の 1 ファイルだけ。最後の `git status --porcelain` に `docs/license-inventory.md` が無い。

- [ ] **Step 15: 一時ディレクトリを消す**

```bash
rm -rf "$WORK"
git status --porcelain
```

Expected: `git status --porcelain` に、このタスクで足した物が無い（スクリプトと中間出力はリポジトリの外にあったので、リポジトリには何も残っていない）。

### Sequencing and dependencies

- Task は 1 つ。Step 1〜15 の順に行う。Step 5・7・8 の結果は Step 9・10 の内容になる。Step 7 で `INDIVIDUAL` を足した場合は Step 6 からやり直す
- この作業は依頼のほかの部分（CI に入れる道具、PR 本文の確かめ）を待たず、それらの成果物を使わない

## Non-Goals

- `LICENSE` の追加、ライセンスの決定、README などへのライセンスの表記
- 調べる道具（LicenseFinder など）やスクリプトのリポジトリへの追加、CI への組み込み
- gem の入れ替え・削除・バージョンの変更、ファイルの差し替えや上流の著作権表示の追加（妨げや「表示が必要」の解消は報告まで）
- 未追跡のファイル（例: `_bmad/`）と submodule の中身の全ファイルの調査
- Ruby 本体・Docker イメージの OS パッケージの全件の調査（gem が使うシステムライブラリは gem の行の注記にとどめる）
- push・PR の作成（後段の lane の設定 `push=true`・`open_pr=false` に従う）

## Verification

- Task 1 の Step 3 で、検査スクリプトが文書の無い状態で失敗することを確かめる（テストが働くことの確認）
- Step 11: `bundle exec ruby "$WORK/check_inventory.rb" docs/license-inventory.md` が `OK`（受け入れ基準 1〜6 の機械的な部分: 冒頭の項目、2 つの報告の節と各項目の根拠、gem の行数とセル、nokogiri・ffi・rubocop・rails、未インストールの 4 変種と「確かめきれない物」、カテゴリの合計と `git ls-files` の一致、候補の行、相対リンクが無いこと）
- Step 11: `bash .lefthook/pre-commit/check-docs.sh` が終了コード 0
- Step 12: 抜き取り（nokogiri・ffi・rubocop・rails・bundler・diff-lcs の行と注記、説明文の残り）
- Step 13: `git status --porcelain`・`git diff --stat main -- Gemfile Gemfile.lock lefthook.yml .lefthook .bundle`・`ls LICENSE`
- Step 14: lefthook の pre-commit を飛ばさずにコミットが通り、`git log -1 --stat` が 1 ファイル
- 受け入れ基準 7（`git-spice-workflow` の形）: ブランチ名 `docs/license-inventory`、`main` から切ったこと、英語の Conventional Commits のメッセージと body、`git-spice commit create` で作ったこと。PR の有無は後段の lane が bead に残す
- コードを入れないため、自動テスト（rspec）は足さない

## Coverage

| ID | Status | Task / Step |
| --- | --- | --- |
| REQ-001 | covered | Task 1 Step 9（冒頭）、Step 13（`LICENSE` が無い、変更が 1 ファイル） |
| REQ-002 | covered | Task 1 Step 4・5（gem の行、group の引き継ぎ、未インストールの変種、システムライブラリの注記）、Step 9（4 変種を「確かめきれない物」へ）、Step 11・12 |
| REQ-003 | covered | Task 1 Step 4（nokogiri・ffi の同梱 C ライブラリの注記と、引いた元の変種の記載）、Step 11・12 |
| REQ-004 | covered | Task 1 Step 6〜8・10（全件の分類、候補と見つかった物の 1 件ずつの行、submodule の 1 行）、Step 11 |
| REQ-005 | covered | Task 1 Step 9（2 つの報告の節と、「分類の決め方」の規則） |
| REQ-006 | covered | Task 1 Step 2〜15（道具と中間出力を `$WORK` だけに置く）、Step 13・14（関係ファイルが無変更、pre-commit を通す）、Step 15 |
| REQ-007 | covered | Task 1 Step 1・14（worktree・ブランチ・コミットの形）。PR は後段の lane |

## Traceability

| 要件の受け入れの条件 | この計画で確かめる場所 |
| --- | --- |
| 1. 変更が `docs/license-inventory.md` の追加だけ、`LICENSE` が無い | Step 13、Step 14 の `git log -1 --stat`、`check_inventory.rb` の LICENSE の確認 |
| 2. gem の行数とセル | `check_inventory.rb`（行数 = エントリ数 ＋ 1、各セル） |
| 3. nokogiri・ffi・rubocop・rails、未インストールの 4 変種 | `check_inventory.rb`、Step 12 |
| 4. カテゴリの合計、候補の 1 件ずつの行 | `classify_files.rb`（合計 = `git ls-files`、未分類で失敗）、`check_inventory.rb` |
| 5. 2 つの報告の節と根拠 | `check_inventory.rb`（各項目の `- 根拠:` と対応・確かめる方法の行） |
| 6. 道具が残らない、関係ファイルが無変更、pre-commit、相対リンク | Step 13・14・15、`check-docs.sh`、`check_inventory.rb` の相対リンクの確認 |
| 7. ブランチとコミットの形、PR の記録 | Step 1・14。PR の記録は後段の lane |

ワークフローの段（prepare・requirements・plan・plan-review・decompose・implement・summarize-implementation・review・finalize・publish）はこの formula が進める。この計画の実装の Task は Task 1 だけで、push・PR の作成は後段の lane が `push=true`・`open_pr=false` に従って扱う。

## Risks and Assumptions

- 前提（この計画で決めた）: WTFPL は寛容な一覧に入れず、gem は「要確認」、由来のファイルは「確かめきれない」として「確かめきれない物」に入れる（要件の基準は WTFPL を名指ししていない）
- 前提: 1 件ずつ扱うファイルには、要件の候補に加えて、ヘッダーの URL が上流のファイルを指す 7 件（`config/locales/active_record.ja.yml`、`app/views/devise/mailer/` の 4 件、`app/views/devise_token_auth/omniauth_external_window.html.erb`、`app/models/concerns/user_override.rb`）を入れる（REQ-004 の「分類の途中で第三者由来・出所不明と分かった物」）
- 前提: `rails new` の生成物を元にしたファイル（`bin/`・`config/` など）は自作のカテゴリに入れ、備考に Rails（MIT）の生成物を含むと書く
- 前提: 同梱文書が無い gem は、宣言で分類し、根拠に「同梱文書無し」と書く（要件の「確かめきれない物」の条件に当たらない）
- 前提: 文書の中では相対リンクを使わない（受け入れ基準 6 の条件を、リンクを作らないことで満たす）
- リスク: rubygems.org API・GitHub API・raw.githubusercontent.com に届かない、または GitHub API の回数の上限（認証なしで 1 時間 60 回）に当たる。該当の行を「要確認」「確かめきれない」にして止めずに進む
- リスク: 同梱文書の判別は文面の決まり文句の一致にとどまる。食い違い・判別不可は人が読む（Step 5）
- リスク: 実装時までに main が進むと件数が変わる。スクリプトは件数を固定せず、検査は実行時の `Gemfile.lock` と `git ls-files` に照らす。この計画に書いた数（167・323 など）は `c73626cd` のときの値
- リスク: `master`・`main` を指す上流の URL は、取り込んだ時点ではなく今の上流と比べることになる。「出所」の列にその旨を書く
- リスク: 依頼の「PR を出すところまで」とワークフロー変数 `open_pr=false` が食い違う（設計の承認 lane tb-cyd40 が mayor に知らせ済み）

## Handoff

- 実装の lane: Task 1 を Step 1 から順に行う。スクリプトはこの計画の本文から写す（計画の lane が main `c73626cd` に対して動かした版）
- 後段の lane: PR を出さない場合（`open_pr=false`）、依頼の「PR を出すところまで」が満たされていないことを後段の bead に残す（REQ-007）

## Open Questions

- 無し。要件に明記の無い点は「Risks and Assumptions」の前提として決めた
