# tascon-backend のライセンスの洗い出し

tascon-backend にオープンソースのライセンス（MIT が候補）を付けるかを決めるための材料として、依存の gem とリポジトリに入っているファイルのライセンスと権利の状況をまとめる。

- 時点: 2026-11-19 の main（c73626cd）のスナップショット。自動では更新しない。依存の更新（Dependabot の bundler の日次更新）で古くなる
- 範囲: `Gemfile.lock` の全エントリ（platform の変種ごと。`PLATFORMS` の 4 つのうち `arm64-darwin-24` と `arm64-darwin-25` は同じ `arm64-darwin` の変種を使うため、nokogiri と ffi は 3 行ずつ）と `bundler`、`git ls-files` の全件。未追跡のファイル、submodule の中身、Ruby 本体と Docker イメージの OS パッケージは含めない
- 調べ方: システムの一時ディレクトリに置いた Ruby スクリプトで、`Gemfile.lock` を `Bundler::LockfileParser` で読み、group を `Bundler.definition.specs_for` で付けた。ライセンスは、この環境（aarch64-linux）に入っている変種は gemspec の `licenses` と同梱のライセンス文書（gem のディレクトリの全階層から、`spec/`・`test/` の下を除き、名前が `LICEN[CS]E*`・`COPYING*`・`LEGAL*`・`BSDL`・`*-LICENSE*`・`*_LICENSE*` の形のファイル。`ext/`・`vendor/` の下も含む。雛形 `*.tt` と man ページは除く）、入っていない変種は rubygems.org API v2 の `licenses` から取った。追跡ファイルは拡張子・`file --mime-type`・初出コミット・ヘッダーの参照 URL で分類し、第三者由来の候補は上流を GitHub API と上流のファイルとの比較で確かめた。スクリプトはリポジトリに入れていない
- 分類: gem は「問題なし／注記あり／要確認／妨げ候補」、1 件ずつ扱うファイルは「問題なし／表示が必要／確かめきれない／妨げ候補」。基準は各表の前に書く
- これは法的な結論ではない。判断の材料と、確かめが要る事項の一覧である
- `LICENSE` はまだ追加していない

## 妨げになる物

無し

## 確かめきれない物

### ffi 1.17.3 arm64-darwin

- 何が確かめきれないか: この環境に入っていない変種で、同梱文書を読んでいない（宣言は API で取得した BSD-3-Clause）
- 根拠: rubygems.org API v2 の `/api/v2/rubygems/ffi/versions/1.17.3.json?platform=arm64-darwin`。この環境に入っている変種 ffi-1.17.3-aarch64-linux-gnu の同梱文書（`COPYING` に libffi は MIT とある）
- 確かめる方法: システムの一時ディレクトリで `gem fetch ffi -v 1.17.3 --platform arm64-darwin` と `gem unpack ffi-1.17.3-arm64-darwin.gem` をして同梱文書を読む

### ffi 1.17.3 x86_64-linux-gnu

- 何が確かめきれないか: この環境に入っていない変種で、同梱文書を読んでいない（宣言は API で取得した BSD-3-Clause）
- 根拠: rubygems.org API v2 の `/api/v2/rubygems/ffi/versions/1.17.3.json?platform=x86_64-linux-gnu`。この環境に入っている変種 ffi-1.17.3-aarch64-linux-gnu の同梱文書（`COPYING` に libffi は MIT とある）
- 確かめる方法: システムの一時ディレクトリで `gem fetch ffi -v 1.17.3 --platform x86_64-linux-gnu` と `gem unpack ffi-1.17.3-x86_64-linux-gnu.gem` をして同梱文書を読む

### nokogiri 1.19.2 arm64-darwin

- 何が確かめきれないか: この環境に入っていない変種で、同梱文書を読んでいない（宣言は API で取得した MIT）。Darwin 版は libiconv（LGPL）を同梱する（この環境の変種の `LICENSE-DEPENDENCIES.md` に「libiconv は Windows と Darwin の版だけに同梱」とある）ため、LGPL の扱いも確かめが要る
- 根拠: rubygems.org API v2 の `/api/v2/rubygems/nokogiri/versions/1.19.2.json?platform=arm64-darwin`。この環境に入っている変種 nokogiri-1.19.2-aarch64-linux-gnu の `LICENSE-DEPENDENCIES.md` の Native Darwin の節
- 確かめる方法: システムの一時ディレクトリで `gem fetch nokogiri -v 1.19.2 --platform arm64-darwin` と `gem unpack nokogiri-1.19.2-arm64-darwin.gem` をして同梱文書を読む。libiconv の同梱の形（静的か動的か）を確かめ、持ち主が LGPL の条件を判断する

### nokogiri 1.19.2 x86_64-linux-gnu

- 何が確かめきれないか: この環境に入っていない変種で、同梱文書を読んでいない（宣言は API で取得した MIT）
- 根拠: rubygems.org API v2 の `/api/v2/rubygems/nokogiri/versions/1.19.2.json?platform=x86_64-linux-gnu`。この環境に入っている変種 nokogiri-1.19.2-aarch64-linux-gnu の `LICENSE-DEPENDENCIES.md` の Native Linux の節（libxml2・libxslt・libgumbo・zlib）
- 確かめる方法: システムの一時ディレクトリで `gem fetch nokogiri -v 1.19.2 --platform x86_64-linux-gnu` と `gem unpack nokogiri-1.19.2-x86_64-linux-gnu.gem` をして同梱文書を読む

### devise_token_auth 1.2.6 ruby

- 何が確かめきれないか: ライセンスが WTFPL で、寛容なライセンスの一覧に入れていない（OSI の承認が無い）。MIT のプロジェクトが WTFPL の gem に依存してよいかは、持ち主の判断が要る
- 根拠: gemspec の `licenses` が WTFPL、同梱の `LICENSE` が `DO WHAT THE FUCK YOU WANT TO` の文面
- 確かめる方法: 持ち主が、WTFPL の物を MIT のプロジェクトに含めてよいかを、上流の LICENSE（`https://github.com/lynndylanhurley/devise_token_auth/blob/master/LICENSE`）を読んで決める

### `config/locales/devise_token_auth.ja.yml`

- 何が確かめきれないか: 上流の 2 つの ja.yml（devise_token_auth は WTFPL、devise-i18n は MIT）から抜き出した翻訳と見られ、WTFPL の物を含む
- 根拠: ファイル先頭の `# devise_token_auth: https://tinyurl.com/2ochwp9b`（`https://github.com/lynndylanhurley/devise_token_auth/blob/master/config/locales/ja.yml`）と `# devise: https://tinyurl.com/22favuhh`（`https://github.com/tigrish/devise-i18n/blob/master/rails/locales/ja.yml`）。GitHub API は前者を WTFPL、後者を MIT と返す。リポジトリの版は 30 行、上流は 60 行と 143 行で、行単位で同じ行は 9 行と 10 行
- 確かめる方法: 持ち主が、WTFPL の物を MIT のプロジェクトに含めてよいかを、上流の LICENSE（`https://github.com/lynndylanhurley/devise_token_auth/blob/master/LICENSE`）を読んで決める

### `app/views/devise/mailer/confirmation_instructions.html.erb`

- 何が確かめきれないか: devise_token_auth の同名のビューを上書きした物で、上流は WTFPL
- 根拠: ヘッダーの `https://tinyurl.com/23vzmcv3`（`https://github.com/lynndylanhurley/devise_token_auth/blob/master/app/views/devise/mailer/confirmation_instructions.html.erb`）。上流は 5 行、リポジトリの版は 13 行で、同じ行は無い（文を日本語にし構造を変えた上書き）
- 確かめる方法: 持ち主が、WTFPL の物を MIT のプロジェクトに含めてよいかを、上流の LICENSE（`https://github.com/lynndylanhurley/devise_token_auth/blob/master/LICENSE`）を読んで決める

### `app/views/devise_token_auth/omniauth_external_window.html.erb`

- 何が確かめきれないか: devise_token_auth の同名のビューを上書きした物で、上流は WTFPL
- 根拠: ヘッダーの `https://is.gd/v9evAO`（`https://github.com/lynndylanhurley/devise_token_auth/blob/b7fcfdf98a84a5d2ae22e005eaa372a668cc9c76/app/views/devise_token_auth/omniauth_external_window.html.erb`）。上流の 38 行に対してリポジトリの版は 37 行で、postMessage の処理が書き換わっているが、`requestCredentials` 関数や message イベントの待ち受けなどの構造は上流と同じ
- 確かめる方法: 持ち主が、WTFPL の物を MIT のプロジェクトに含めてよいかを、上流の LICENSE（`https://github.com/lynndylanhurley/devise_token_auth/blob/master/LICENSE`）を読んで決める

### `app/models/concerns/user_override.rb`

- 何が確かめきれないか: devise_token_auth の User concern の一部のメソッドを上書きした物で、上流は WTFPL
- 根拠: ヘッダーの `https://tinyurl.com/2detqylw`（`https://github.com/lynndylanhurley/devise_token_auth/blob/c15c5f0724b5bc181c95d679621a173c949c0cf8/app/models/devise_token_auth/concerns/user.rb`）。上流は 275 行、リポジトリの版は 23 行で、同じ行は 5 行
- 確かめる方法: 持ち主が、WTFPL の物を MIT のプロジェクトに含めてよいかを、上流の LICENSE（`https://github.com/lynndylanhurley/devise_token_auth/blob/master/LICENSE`）を読んで決める

### `.bruno/Collection/480x320.png`

- 何が確かめきれないか: 画像の出所の記録が無い
- 根拠: 追加コミット `0846ed810`（P-manBrown、2025-04-08、`test: introduce Bruno for testing (#322)`）が `.bruno/480x320.png` として追加し、出所は書かれていない。`b48e28cf1`（2025-09-04、`feat!: change error response format with ErrorRendering concern (#421)`）が `.bruno/Collection/480x320.png` へ移動した。参照元は `.bruno/Collection/Auth/Change User Info.bru`（`avatar: @file(480x320.png)`）
- 確かめる方法: 持ち主が出所を確かめるか、自作の画像に差し替える

### `.github/COMMIT_CONVENTION`

- 何が確かめきれないか: 持ち主の別リポジトリ（submodule）で、ライセンスが宣言されていない。中身はこの洗い出しの範囲に含めていない
- 根拠: `.gitmodules` の `https://github.com/P-manBrown/commit-convention.git`。GitHub API の `/repos/P-manBrown/commit-convention/license` は 404 を返す
- 確かめる方法: 持ち主が commit-convention のライセンスを決める

### `Docker/web/nginx/nginx.conf`

- 何が確かめきれないか: 出所の記録が無く、上流のファイルを特定できなかった。nginx の公式 Docker イメージの既定の設定を元にした可能性がある
- 根拠: ヘッダーに URL が無い。nginx/nginx と nginx/docker-nginx のリポジトリのライセンスはどちらも BSD-2-Clause（GitHub API）だが、docker-nginx に `nginx.conf` は無い（イメージは nginx のパッケージから取る）ため、比べられなかった。`Docker/web/Dockerfile` が `COPY ./nginx/nginx.conf /etc/nginx/` で使う
- 確かめる方法: 持ち主が、使っている nginx イメージの `/etc/nginx/nginx.conf` と比べて出所を確かめる

## gem の一覧

`Gemfile.lock` の 1 エントリ（platform の変種ごと）と `bundler` を 1 行にした。group は推移的な依存を含めて付けた。この環境に入っていない変種の group は、同じ名前・バージョンでこの環境に入っている変種から引き継ぎ、根拠にそう書いた。「同梱文書で確かめたライセンス」は同梱のライセンス文書の文面からの判別で、判別が宣言と食い違う候補と判別できなかった文書は人が読んで注記に結果を書いた。

分類の基準: 宣言がすべて寛容なライセンス（MIT・BSD・Apache-2.0・ISC・Ruby など）なら「問題なし」、寛容なものと非寛容なものが混ざる・LGPL・MPL・同梱 C ライブラリやシステムライブラリがあるなら「注記あり」、GPL・AGPL だけなら「妨げ候補」、宣言無し・その他の宣言・未インストールの変種・API 取得失敗は「要確認」。gem はリポジトリに同梱されない依存として分類した。

| 名前 | バージョン | platform | group | 宣言ライセンス | 同梱文書で確かめたライセンス | 根拠 | 分類 | 注記 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| action_text-trix | 2.1.17 | ruby | default | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| actioncable | 8.1.3 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| actionmailbox | 8.1.3 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| actionmailer | 8.1.3 | ruby | default, development | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| actionpack | 8.1.3 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| actiontext | 8.1.3 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| actionview | 8.1.3 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| active_storage_validations | 3.0.4 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| activejob | 8.1.3 | ruby | default, development | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| activemodel | 8.1.3 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| activerecord | 8.1.3 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| activestorage | 8.1.3 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| activesupport | 8.1.3 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| addressable | 2.8.9 | ruby | development | Apache-2.0 | LICENSE.txt: Apache-2.0 | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| alba | 3.10.0 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| ast | 2.4.3 | ruby | development | MIT | LICENSE.MIT: MIT | gemspec の licenses; 同梱文書 LICENSE.MIT | 問題なし | - |
| base64 | 0.3.0 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; LEGAL: Ruby, MIT, BSD-3-Clause; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, LEGAL, BSDL | 問題なし | LEGAL: Ruby ライセンスまたはパブリックドメイン。例外として MIT License と旧式の BSD License（3 項は無効と明記）の全文を載せるが、対象ファイルは LEGAL に書かれていない |
| bcrypt | 3.1.20 | ruby | default | MIT | COPYING: MIT | gemspec の licenses; 同梱文書 COPYING | 問題なし | - |
| benchmark | 0.5.0 | ruby | default | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| bigdecimal | 4.0.1 | ruby | default, development, test | Ruby, BSD-2-Clause | LICENSE: Ruby | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| bootsnap | 1.23.0 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| builder | 3.3.0 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| bullet | 8.1.0 | ruby | development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| bundler | 2.6.9 | ruby | default, development, test | MIT | LICENSE.md: MIT; lib/bundler/vendor/ の下: connection_pool LICENSE（MIT）・fileutils COPYING（Ruby, BSD-2-Clause）・net-http-persistent README.rdoc の LICENSE 節（MIT）・pub_grub LICENSE.txt（MIT）・securerandom COPYING（Ruby, BSD-2-Clause）・thor LICENSE.md（MIT）・tsort LICENSE.txt（BSD-2-Clause）・uri COPYING（Ruby, BSD-2-Clause） | gemspec の licenses; 同梱文書 LICENSE.md, lib/bundler/vendor/*/ の文書（net-http-persistent は README.rdoc の LICENSE 節） | 問題なし | 同梱（vendor）の Ruby コード: connection_pool・fileutils・net-http-persistent・pub_grub・securerandom・thor・tsort・uri。いずれも寛容なライセンス |
| childprocess | 5.0.0 | ruby | development | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| coderay | 1.1.3 | ruby | development | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| concurrent-ruby | 1.3.6 | ruby | default, development, test | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| connection_pool | 3.0.2 | ruby | default, development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| crass | 1.0.6 | ruby | default, development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| date | 3.5.1 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| debride | 1.15.1 | ruby | development | MIT | 同梱文書無し | gemspec の licenses; 同梱文書無し | 問題なし | - |
| debug | 1.11.1 | ruby | development, test | Ruby, BSD-2-Clause | LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| devise | 4.9.4 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| devise-i18n | 1.15.0 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| devise_token_auth | 1.2.6 | ruby | default | WTFPL | LICENSE: WTFPL | gemspec の licenses; 同梱文書 LICENSE | 要確認 | - |
| diff-lcs | 1.6.2 | ruby | development, test | MIT, Artistic-1.0-Perl, GPL-2.0-or-later | LICENCE.md: GPL, MIT; docs/COPYING.txt: GPL-2.0（全文） | gemspec の licenses; 同梱文書 LICENCE.md, docs/COPYING.txt | 注記あり | LICENCE.md に GPL-2.0-or-later・Artistic-1.0-Perl・MIT の 3 つのライセンスのいずれかで使えるとある（MIT を選べる）。docs/COPYING.txt は LICENCE.md が参照する GPL の全文 |
| dotenv | 3.2.0 | ruby | development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| dotenv-rails | 3.2.0 | ruby | development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| drb | 2.2.3 | ruby | default, development, test | Ruby, BSD-2-Clause | LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| erb | 6.0.2 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; LICENSE.txt: Ruby, BSD-2-Clause; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, LICENSE.txt, BSDL | 問題なし | - |
| erubi | 1.13.1 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| factory_bot | 6.5.5 | ruby | development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| factory_bot_rails | 6.5.1 | ruby | development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| faker | 3.6.1 | ruby | development, test | MIT | License.txt: MIT | gemspec の licenses; 同梱文書 License.txt | 問題なし | - |
| faraday | 2.14.1 | ruby | default | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| faraday-net_http | 3.4.2 | ruby | default | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| ffi | 1.17.3 | aarch64-linux-gnu | default, development | BSD-3-Clause | COPYING: MIT, BSD-3-Clause; LICENSE: BSD-3-Clause; LICENSE.SPECS: MIT | gemspec の licenses; 同梱文書 COPYING, LICENSE, LICENSE.SPECS | 注記あり | 同梱 C ライブラリ: libffi（MIT）。根拠 COPYING の libffi の記載 |
| ffi | 1.17.3 | arm64-darwin | default, development | BSD-3-Clause | 未インストールのため未確認 | group はこの環境の変種（aarch64-linux-gnu）から引き継いだ; rubygems.org API v2 の licenses（/api/v2/rubygems/ffi/versions/1.17.3.json?platform=arm64-darwin） | 要確認 | 同梱 C ライブラリ: libffi（MIT）。根拠 COPYING の libffi の記載（この環境に入っている変種 ffi-1.17.3-aarch64-linux-gnu の同梱文書から引いた） |
| ffi | 1.17.3 | x86_64-linux-gnu | default, development | BSD-3-Clause | 未インストールのため未確認 | group はこの環境の変種（aarch64-linux-gnu）から引き継いだ; rubygems.org API v2 の licenses（/api/v2/rubygems/ffi/versions/1.17.3.json?platform=x86_64-linux-gnu） | 要確認 | 同梱 C ライブラリ: libffi（MIT）。根拠 COPYING の libffi の記載（この環境に入っている変種 ffi-1.17.3-aarch64-linux-gnu の同梱文書から引いた） |
| formatador | 1.2.3 | ruby | development | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| globalid | 1.3.0 | ruby | default, development | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| guard | 2.20.1 | ruby | development | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| guard-compat | 1.2.1 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| guard-rspec | 4.7.3 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| hashie | 5.1.0 | ruby | default | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| htmlbeautifier | 1.4.3 | ruby | development | MIT | 同梱文書無し | gemspec の licenses; 同梱文書無し | 問題なし | - |
| i18n | 1.14.8 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| image_processing | 1.14.0 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 注記あり | ruby-vips 経由でシステムの libvips を使う（ruby-vips の行を参照） |
| io-console | 0.8.2 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| irb | 1.17.0 | ruby | default, development, test | Ruby, BSD-2-Clause | LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| json | 2.19.3 | ruby | default, development, test | Ruby | COPYING: Ruby; LEGAL: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, LEGAL, BSDL | 注記あり | LEGAL: Ruby ライセンスまたはパブリックドメイン。例外 ext/json/ext/vendor/fpconv.h（BSL-1.0）・jeaiii-ltoa.h（MIT）・ryu.h（Apache-2.0 または BSL-1.0） |
| jwt | 3.1.2 | ruby | default | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| language_server-protocol | 3.17.0.5 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| launchy | 3.0.1 | ruby | development | ISC | LICENSE.txt: ISC | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| lefthook | 1.13.6 | ruby | development | MIT | 同梱文書無し | gemspec の licenses; 同梱文書無し | 問題なし | - |
| letter_opener | 1.10.0 | ruby | development | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| letter_opener_web | 3.0.0 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| lint_roller | 1.1.0 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| listen | 3.10.0 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| logger | 1.7.0 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| loofah | 2.25.1 | ruby | default, development, test | MIT | MIT-LICENSE.txt: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE.txt | 問題なし | - |
| lumberjack | 1.4.2 | ruby | development | MIT | MIT_LICENSE.txt: MIT | gemspec の licenses; 同梱文書 MIT_LICENSE.txt | 問題なし | - |
| mail | 2.9.0 | ruby | default, development | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| marcel | 1.1.0 | ruby | default | MIT, Apache-2.0 | MIT-LICENSE: MIT; APACHE-LICENSE: Apache-2.0 | gemspec の licenses; 同梱文書 MIT-LICENSE, APACHE-LICENSE | 問題なし | magic signature data は Apache Tika 由来（Apache-2.0）。根拠 README と APACHE-LICENSE |
| method_source | 1.1.0 | ruby | development | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| mini_magick | 5.1.2 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| mini_mime | 1.1.5 | ruby | default, development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| minitest | 6.0.2 | ruby | default, development, test | MIT | 同梱文書無し | gemspec の licenses; 同梱文書無し | 問題なし | - |
| msgpack | 1.8.0 | ruby | default | Apache-2.0 | LICENSE: Apache-2.0 | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| multi_xml | 0.8.1 | ruby | default | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| mysql2 | 0.5.7 | ruby | default | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 注記あり | システムの MySQL クライアントライブラリ（libmysqlclient または libmariadb）にリンクする。gem には同梱されない |
| nenv | 0.3.0 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| net-http | 0.9.1 | ruby | default | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| net-imap | 0.6.3 | ruby | default, development | Ruby, BSD-2-Clause | COPYING: Ruby; LICENSE.txt: Ruby, BSD-2-Clause; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, LICENSE.txt, BSDL | 問題なし | - |
| net-pop | 0.1.2 | ruby | default, development | Ruby, BSD-2-Clause | LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| net-protocol | 0.2.2 | ruby | default, development | Ruby, BSD-2-Clause | LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| net-smtp | 0.5.1 | ruby | default, development | Ruby, BSD-2-Clause | LICENSE.txt: Ruby, BSD-2-Clause | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| nio4r | 2.7.5 | ruby | default | MIT, BSD-2-Clause | license.md: MIT; ext/libev/LICENSE: BSD-2-Clause または GPL-2.0-or-later | gemspec の licenses; 同梱文書 license.md, ext/libev/LICENSE | 注記あり | 同梱 C ライブラリ: libev（BSD-2-Clause または GPL-2.0-or-later の選択。BSD-2-Clause を選べる）。根拠 ext/libev/LICENSE |
| nokogiri | 1.19.2 | aarch64-linux-gnu | default, development, test | MIT | LICENSE-DEPENDENCIES.md: 同梱 C ライブラリの文書（注記を参照）; LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE-DEPENDENCIES.md, LICENSE.md | 注記あり | 同梱 C ライブラリ: libxml2（MIT）, libxslt（MIT）, libgumbo（Apache 2.0）, zlib（zlib license）。根拠 LICENSE-DEPENDENCIES.md の Native Linux の節 |
| nokogiri | 1.19.2 | arm64-darwin | default, development, test | MIT | 未インストールのため未確認 | group はこの環境の変種（aarch64-linux-gnu）から引き継いだ; rubygems.org API v2 の licenses（/api/v2/rubygems/nokogiri/versions/1.19.2.json?platform=arm64-darwin） | 要確認 | 同梱 C ライブラリ: libxml2（MIT）, libxslt（MIT）, libgumbo（Apache 2.0）, zlib（zlib license）, libiconv（LGPL）。根拠 LICENSE-DEPENDENCIES.md の Native Darwin の節（この環境に入っている変種 nokogiri-1.19.2-aarch64-linux-gnu の同梱文書から引いた） |
| nokogiri | 1.19.2 | x86_64-linux-gnu | default, development, test | MIT | 未インストールのため未確認 | group はこの環境の変種（aarch64-linux-gnu）から引き継いだ; rubygems.org API v2 の licenses（/api/v2/rubygems/nokogiri/versions/1.19.2.json?platform=x86_64-linux-gnu） | 要確認 | 同梱 C ライブラリ: libxml2（MIT）, libxslt（MIT）, libgumbo（Apache 2.0）, zlib（zlib license）。根拠 LICENSE-DEPENDENCIES.md の Native Linux の節（この環境に入っている変種 nokogiri-1.19.2-aarch64-linux-gnu の同梱文書から引いた） |
| notiffany | 0.1.3 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| oauth | 1.1.0 | ruby | default | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| oauth-tty | 1.0.5 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| oauth2 | 2.0.18 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| omniauth | 2.1.4 | ruby | default | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| omniauth-google-oauth2 | 1.2.2 | ruby | default | MIT | 同梱文書無し | gemspec の licenses; 同梱文書無し | 問題なし | - |
| omniauth-oauth | 1.2.0 | ruby | default | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| omniauth-oauth2 | 1.9.0 | ruby | default | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| omniauth-twitter | 1.4.0 | ruby | default | MIT | 同梱文書無し | gemspec の licenses; 同梱文書無し | 問題なし | - |
| orm_adapter | 0.5.0 | ruby | default | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| pagy | 9.4.0 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| parallel | 2.0.1 | ruby | development | MIT | MIT-LICENSE.txt: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE.txt | 問題なし | - |
| parser | 3.3.11.1 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| path_expander | 2.0.1 | ruby | development | MIT | 同梱文書無し | gemspec の licenses; 同梱文書無し | 問題なし | - |
| pp | 0.6.3 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| prettyprint | 0.2.0 | ruby | default, development, test | Ruby, BSD-2-Clause | LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| prism | 1.9.0 | ruby | default, development, test | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| pry | 0.16.0 | ruby | development | MIT | LICENSE: MIT; lib/pry/slop/LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE, lib/pry/slop/LICENSE | 問題なし | 同梱の slop（MIT）。根拠 lib/pry/slop/LICENSE |
| psych | 5.3.1 | ruby | default, development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| public_suffix | 7.0.5 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| puma | 7.2.0 | ruby | default | BSD-3-Clause | LICENSE: BSD-3-Clause | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| racc | 1.8.1 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| rack | 3.2.5 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| rack-cors | 3.0.0 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| rack-protection | 4.2.1 | ruby | default | MIT | License: MIT | gemspec の licenses; 同梱文書 License | 問題なし | - |
| rack-session | 2.1.1 | ruby | default, development, test | MIT | license.md: MIT | gemspec の licenses; 同梱文書 license.md | 問題なし | - |
| rack-test | 2.2.0 | ruby | default, development, test | MIT | MIT-LICENSE.txt: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE.txt | 問題なし | - |
| rackup | 2.3.1 | ruby | default, development, test | MIT | license.md: MIT | gemspec の licenses; 同梱文書 license.md | 問題なし | - |
| rails | 8.1.3 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| rails-dom-testing | 2.3.0 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| rails-html-sanitizer | 1.7.0 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| rails-i18n | 8.1.0 | ruby | default | MIT | MIT-LICENSE.txt: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE.txt | 問題なし | - |
| railties | 8.1.3 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| rainbow | 3.1.1 | ruby | development | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| rake | 13.3.1 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| rb-fsevent | 0.11.2 | ruby | development | MIT | LICENSE.txt: MIT; ext/LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE.txt, ext/LICENSE | 注記あり | 同梱の fsevent_watch（MIT）。根拠 ext/LICENSE |
| rb-inotify | 0.11.1 | ruby | development | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| rdoc | 7.2.0 | ruby | default, development, test | Ruby | LEGAL.rdoc: Ruby; LICENSE.rdoc: Ruby | gemspec の licenses; 同梱文書 LEGAL.rdoc, LICENSE.rdoc | 問題なし | LEGAL.rdoc: Ruby ライセンス。例外 Aliki（MIT）・Darkfish（BSD-3-Clause、Silk Icons を含む）・SDoc の一部（MIT）・peg-markdown 由来の Markdown 対応（MIT）・MarkdownTest 1.0.3（Perl と同じ条件、test 用）・フォント Source Code Pro と Lato（SIL OFL 1.1） |
| regexp_parser | 2.12.0 | ruby | development | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| reline | 0.6.3 | ruby | default, development, test | Ruby | COPYING: Ruby; license_of_rb-readline: BSD-3-Clause; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, license_of_rb-readline, BSDL | 問題なし | - |
| responders | 3.1.1 | ruby | default | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |
| rexml | 3.3.6 | ruby | development | BSD-2-Clause | LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| rspec | 3.13.0 | ruby | development | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| rspec-core | 3.13.6 | ruby | development, test | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| rspec-expectations | 3.13.5 | ruby | development, test | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| rspec-mocks | 3.13.8 | ruby | development, test | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| rspec-rails | 8.0.4 | ruby | development, test | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| rspec-support | 3.13.7 | ruby | development, test | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| rubocop | 1.86.1 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| rubocop-ast | 1.49.1 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| rubocop-factory_bot | 2.28.0 | ruby | development | MIT | MIT-LICENSE.md: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE.md | 問題なし | - |
| rubocop-performance | 1.26.1 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| rubocop-rails | 2.34.3 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| rubocop-rspec | 3.9.0 | ruby | development | MIT | MIT-LICENSE.md: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE.md | 問題なし | - |
| ruby-progressbar | 1.13.0 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| ruby-vips | 2.2.3 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 注記あり | システムの libvips（LGPL-2.1-or-later）を実行時に読み込む。Docker/api/Dockerfile で libvips42 を入れる。gem には同梱されない |
| securerandom | 0.4.1 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| sexp_processor | 4.17.5 | ruby | development | MIT | 同梱文書無し | gemspec の licenses; 同梱文書無し | 問題なし | - |
| shellany | 0.0.1 | ruby | development | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| snaky_hash | 2.0.3 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| stringio | 3.2.0 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, LICENSE.txt | 問題なし | - |
| strscan | 3.1.0 | ruby | development | Ruby, BSD-2-Clause | COPYING: Ruby; LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, LICENSE.txt | 問題なし | - |
| thor | 1.5.0 | ruby | default, development, test | MIT | LICENSE.md: MIT | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| timeout | 0.6.1 | ruby | default, development | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| tsort | 0.2.0 | ruby | default, development, test | Ruby, BSD-2-Clause | LICENSE.txt: BSD-2-Clause | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| tzinfo | 2.0.6 | ruby | default, development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| unicode-display_width | 3.2.0 | ruby | development | MIT | MIT-LICENSE.txt: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE.txt | 問題なし | - |
| unicode-emoji | 4.2.0 | ruby | development | MIT | MIT-LICENSE.txt: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE.txt | 問題なし | - |
| uniform_notifier | 1.18.0 | ruby | development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| uri | 1.1.1 | ruby | default, development, test | Ruby, BSD-2-Clause | COPYING: Ruby; BSDL: BSD-2-Clause | gemspec の licenses; 同梱文書 COPYING, BSDL | 問題なし | - |
| useragent | 0.16.11 | ruby | default, development, test | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| version_gem | 1.1.9 | ruby | default | MIT | LICENSE.txt: MIT | gemspec の licenses; 同梱文書 LICENSE.txt | 問題なし | - |
| warden | 1.2.9 | ruby | default | MIT | LICENSE: MIT | gemspec の licenses; 同梱文書 LICENSE | 問題なし | - |
| websocket-driver | 0.8.0 | ruby | default | Apache-2.0 | LICENSE.md: Apache-2.0 | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| websocket-extensions | 0.1.5 | ruby | default | Apache-2.0 | LICENSE.md: Apache-2.0 | gemspec の licenses; 同梱文書 LICENSE.md | 問題なし | - |
| zeitwerk | 2.7.5 | ruby | default, development, test | MIT | MIT-LICENSE: MIT | gemspec の licenses; 同梱文書 MIT-LICENSE | 問題なし | - |

## コード以外の物（追跡ファイル）

`git ls-files` の 323 件を、次のカテゴリに分けた（合計 323）。自作のコード・文書・設定はカテゴリ単位で書き、第三者由来の候補・出所不明・バイナリ・submodule は下の表で 1 件ずつ書いた。

分類の基準: 自作は「問題なし」。第三者由来で寛容なライセンス（著作権表示の保持が要る物）は「表示が必要」（妨げではない）。出所の記録が無い・上流をこの環境から確かめられない・WTFPL は「確かめきれない」。ライセンスが不明・再配布不可・MIT と両立しない条件は「妨げ候補」。

### カテゴリ別の件数

| カテゴリ | 件数 | パスの範囲 | 備考 |
| --- | --- | --- | --- |
| アプリのコード | 42 | `app/`・`lib/` | 自作。上流の issue・文書への参照だけ（写しが無いことを読んで確かめた）: `app/controllers/api/v1/auth/omniauth_callbacks_controller.rb`・`passwords_controller.rb`・`registrations_controller.rb`（devise_token_auth の issue へのコメント）。1 件ずつ扱う 6 件（`app/models/concerns/user_override.rb` とビュー 5 件）は別に数えた |
| DB のマイグレーションとスキーマ | 24 | `db/` | 自作 |
| テスト | 13 | `spec/` | 自作 |
| Rails・Ruby の設定と起動スクリプト | 35 | `config/`・`bin/`・`public/`・`Gemfile`・`Gemfile.lock`・`Rakefile`・`config.ru`・`Guardfile`・`.rspec`・`.rubocop.yml`・`.ruby-version`・`debride-whitelist.txt` | `rails new` の生成物を元にしたファイルを含む（Rails は MIT）。`config/initializers/pagy.rb`（pagy の生成物）・`Guardfile`（guard の生成物）・`config/initializers/cors.rb`・`public/robots.txt` は上流のドキュメントへの参照だけで、写しが無いことを読んで確かめた。1 件ずつ扱う 3 件（`config/locales/` の yml）は別に数えた |
| コンテナと開発環境の設定 | 19 | `Docker/`・`.devcontainer/`・`.vscode/`・`compose.yml`・`.dockerignore`・`.editorconfig`・`.env`・`.worktreeinclude` | 自作。1 件ずつ扱う `Docker/web/nginx/nginx.conf` は別に数えた |
| Git と GitHub の設定 | 11 | `.github/`・`.gitignore`・`.gitattributes`・`.gitmodules` | 自作。`.gitignore`・`.gitattributes` は上流のドキュメントへの参照だけ（写しが無いことを読んで確かめた）。submodule の `.github/COMMIT_CONVENTION` は別に数えた |
| lefthook（コミット時の確かめ） | 9 | `lefthook.yml`・`.lefthook/` | 自作 |
| API の手動確認用の Bruno コレクション | 57 | `.bruno/` | 自作。`.bruno/Collection/.env` はシンボリックリンクで、リンク先はリポジトリの `.env`。バイナリの `.bruno/Collection/480x320.png` は別に数えた |
| Claude Code の設定・ルール・Skill・計画・技術的負債 | 71 | `.claude/` | 自作。第三者由来の `.claude/skills/gh-stack/` の 4 ファイルは別に数えた |
| 文書 | 20 | `docs/`・`README.md`・`ARCHITECTURE.md`・`AGENTS.md` | 自作。作業記録の中の参考 URL は上流の写しではない |
| 空ディレクトリを保つための空ファイル | 6 | `log/`・`tmp/`・`storage/`・`vendor/` | 内容が無い |
| 個別（バイナリ） | 1 | 下の表 | 1 件ずつ書いた |
| 個別（submodule） | 1 | 下の表 | 1 件ずつ書いた |
| 個別（第三者由来の候補） | 14 | 下の表 | 1 件ずつ書いた |

### 1 件ずつ扱う物

| パス | 参照元 | 出所 | ライセンス | 分類 |
| --- | --- | --- | --- | --- |
| `.bruno/Collection/480x320.png` | `.bruno/Collection/Auth/Change User Info.bru`（`avatar: @file(480x320.png)`） | 出所の記載無し。追加コミット `0846ed810`（2025-04-08、P-manBrown、`.bruno/480x320.png` として追加。`b48e28cf1` で `.bruno/Collection/` へ移動） | 不明 | 確かめきれない |
| `.github/COMMIT_CONVENTION` | `.gitmodules`、`.claude/skills/git-spice-workflow/SKILL.md` | submodule。`https://github.com/P-manBrown/commit-convention.git`（このリポジトリの持ち主の別リポジトリ）。追加コミット `dc08bc862`（2023-03-11） | 宣言無し（GitHub API は 404） | 確かめきれない |
| `.claude/skills/gh-stack/SKILL.md` | Claude Code が `.claude/skills/` の Skill として読み込む | `https://github.com/github/gh-stack`（`refs/tags/v0.3.0` の `skills/gh-stack/SKILL.md`）。ヘッダーの metadata の順序と書き方だけが上流と違い、本文は同じ。追加コミット `f612671f1`（2026-08-20） | MIT（GitHub API）。上流の著作権表示がリポジトリに無い | 表示が必要 |
| `.claude/skills/gh-stack/references/commands.md` | Claude Code が `.claude/skills/` の Skill として読み込む（SKILL.md から参照） | `https://github.com/github/gh-stack`（`refs/tags/v0.3.0` の `skills/gh-stack/references/commands.md`）。上流と同じ内容（差分無し）。追加コミット `6c75ae3de`（2026-10-08） | MIT（GitHub API）。上流の著作権表示がリポジトリに無い | 表示が必要 |
| `.claude/skills/gh-stack/references/stack-design.md` | Claude Code が `.claude/skills/` の Skill として読み込む（SKILL.md から参照） | `https://github.com/github/gh-stack`（`refs/tags/v0.3.0` の `skills/gh-stack/references/stack-design.md`）。上流と同じ内容（差分無し）。追加コミット `6c75ae3de`（2026-10-08） | MIT（GitHub API）。上流の著作権表示がリポジトリに無い | 表示が必要 |
| `.claude/skills/gh-stack/references/troubleshooting.md` | Claude Code が `.claude/skills/` の Skill として読み込む（SKILL.md から参照） | `https://github.com/github/gh-stack`（`refs/tags/v0.3.0` の `skills/gh-stack/references/troubleshooting.md`）。上流と同じ内容（差分無し）。追加コミット `6c75ae3de`（2026-10-08） | MIT（GitHub API）。上流の著作権表示がリポジトリに無い | 表示が必要 |
| `Docker/web/nginx/nginx.conf` | `Docker/web/Dockerfile`（`COPY ./nginx/nginx.conf /etc/nginx/`） | 出所の記載無し。nginx の公式 Docker イメージの既定の設定を元にした可能性（未確認）。追加コミット `dc08bc862`（2023-03-11） | 不明（nginx/nginx と nginx/docker-nginx のリポジトリは BSD-2-Clause。同名の上流のファイルは特定できなかった） | 確かめきれない |
| `app/models/concerns/user_override.rb` | `app/models/user.rb`（`include UserOverride`） | `https://tinyurl.com/2detqylw`（devise_token_auth の `app/models/devise_token_auth/concerns/user.rb`、`c15c5f0724b5bc181c95d679621a173c949c0cf8`）を元に上書き。追加コミット `791a815db`（2024-07-09） | WTFPL（GitHub API） | 確かめきれない |
| `app/views/devise/mailer/confirmation_instructions.html.erb` | devise のメール送信が同名のビューを使う | `https://tinyurl.com/23vzmcv3`（devise_token_auth の同名ファイル。`master` を指すため、取り込んだ時点ではなく今の上流と比べた）を元に日本語化・変更。追加コミット `d6d3d8625`（2023-03-27） | WTFPL（GitHub API） | 確かめきれない |
| `app/views/devise/mailer/email_changed.html.erb` | devise のメール送信が同名のビューを使う | `https://tinyurl.com/2y44ysbj`（devise の同名ファイル、`a259ff3c28912a27329727f4a3c2623d3f5cb6f2`）を元に日本語化・変更（上流との差分あり）。追加コミット `791a815db`（2024-07-09） | MIT（GitHub API）。上流の著作権表示がリポジトリに無い | 表示が必要 |
| `app/views/devise/mailer/password_change.html.erb` | devise のメール送信が同名のビューを使う | `https://tinyurl.com/257jo5go`（devise の同名ファイル。`main` を指すため、取り込んだ時点ではなく今の上流と比べた）を元に日本語化・変更（上流との差分あり）。追加コミット `791a815db`（2024-07-09） | MIT（GitHub API）。上流の著作権表示がリポジトリに無い | 表示が必要 |
| `app/views/devise/mailer/reset_password_instructions.html.erb` | devise のメール送信が同名のビューを使う | `https://tinyurl.com/2ysv8kyb`（devise の同名ファイル、`a259ff3c28912a27329727f4a3c2623d3f5cb6f2`）を元に日本語化・変更（上流との差分あり）。追加コミット `d6d3d8625`（2023-03-27） | MIT（GitHub API）。上流の著作権表示がリポジトリに無い | 表示が必要 |
| `app/views/devise_token_auth/omniauth_external_window.html.erb` | devise_token_auth の OmniAuth のコールバックが同名のビューを使う | `https://is.gd/v9evAO`（devise_token_auth の同名ファイル、`b7fcfdf98a84a5d2ae22e005eaa372a668cc9c76`）を元に上書き（上流との差分あり）。追加コミット `ede58efb3`（2024-11-26） | WTFPL（GitHub API） | 確かめきれない |
| `config/locales/active_record.ja.yml` | Rails の i18n が `config/locales/` の下を読み込む | `https://tinyurl.com/aczke9k`（rails-i18n の `rails/locale/ja.yml`。`master` を指すため、取り込んだ時点ではなく今の上流と比べた）から抜き出した翻訳。追加コミット `791a815db`（2024-07-09） | MIT（GitHub API）。上流の著作権表示がリポジトリに無い | 表示が必要 |
| `config/locales/active_storage_validations.ja.yml` | Rails の i18n が `config/locales/` の下を読み込む | `https://tinyurl.com/yw8trctz`（active_storage_validations の `config/locales/ja.yml`。`master` を指すため、取り込んだ時点ではなく今の上流と比べた）から抜き出した翻訳。追加コミット `791a815db`（2024-07-09） | MIT（GitHub API）。上流の著作権表示がリポジトリに無い | 表示が必要 |
| `config/locales/devise_token_auth.ja.yml` | Rails の i18n が `config/locales/` の下を読み込む | `https://tinyurl.com/2ochwp9b`（devise_token_auth の `config/locales/ja.yml`）と `https://tinyurl.com/22favuhh`（devise-i18n の `rails/locales/ja.yml`）から抜き出した翻訳（どちらも `master` を指すため、今の上流と比べた）。追加コミット `d6d3d8625`（2023-03-27） | WTFPL と MIT（GitHub API） | 確かめきれない |
