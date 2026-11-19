# 要件: tascon-backend のライセンスの洗い出し

- 依頼 bead: tb-4txu8（HQ 依頼 gc-n91n の部分 1）
- ワークフロー root: tb-nvhlu（superpowers-build）
- 承認済みの設計: `.claude/specs/license-inventory.md`（承認 lane tb-cyd40、autonomous、要約は同じディレクトリの `approval-summary.md`）
- `docs/superpowers/specs/` への写し: 作らない。このリポジトリでは Gas City の build の設計と要件をリポジトリに写さない前例があり（`.claude/plans/active/git-spice-merge-and-ci-gates.md` の「Spec: N/A（設計と要件はGas Cityのbuildの成果物にあり、リポジトリには写していない）」）、この lane は main の作業ツリーにコミットしないため。追跡はこのファイルのパスで行う

## Problem Statement

tascon-backend にオープンソースのライセンス（MIT が候補）を付けるかを決める前に、依存の gem とリポジトリに入っているコード以外の物の、ライセンスと権利の状況が分かっていない。付けるのに妨げになる物と、確かめきれない物を、根拠付きで一覧にする必要がある。`LICENSE` はまだ付けない。

## W6H

- **Who**: 作業者は Gas City の実装 lane。読み手はリポジトリの持ち主（ライセンスを決める人）
- **What**: `docs/license-inventory.md`（日本語、1 ファイル）。gem の一覧、コード以外の物（追跡ファイル）の一覧、「妨げになる物」「確かめきれない物」の 2 つの報告
- **When**: 2026-11-18 の main をスナップショットとして調べる（冒頭に日付と main のコミットを書く）。自動更新はしない
- **Where**: リポジトリの `docs/license-inventory.md`。調べる道具・スクリプト・中間出力はシステムの一時ディレクトリだけに置く
- **Why**: MIT などのライセンスを付けるかの判断の材料にするため（法的結論は出さない）
- **How**: 設計の案 A。一時ディレクトリの Ruby スクリプトが `Gemfile.lock` を `Bundler::LockfileParser` で読み、group を `Bundler.definition.specs_for` で付け、ライセンスを gemspec の `licenses`・同梱のライセンス文書・rubygems.org API v2（この環境に無い platform 変種）から取る。追跡ファイルは `git ls-files` 全件を分類し、第三者由来の候補は上流を人の手で確かめる
- **How much**: `Gemfile.lock` の GEM 節 166 エントリ ＋ `bundler` 1 行、`git ls-files` 323 件（2026-11-18 時点。実装時の main の件数に合わせる）

## User Stories

- リポジトリの持ち主として、MIT を付けるのに妨げになる依存やファイルを根拠付きで知りたい。ライセンスを決める前に対処できるようにするため
- リポジトリの持ち主として、自動では確かめきれなかった物と、その確かめ方を知りたい。自分で確かめる範囲を絞るため
- リポジトリの持ち主として、どの gem がどの group・platform で使われ、どのライセンスかを 1 か所で見たい。配布の形を決めるときに参照するため

## Technical Stories

- gem の一覧は lockfile のエントリ（platform 変種ごと）を起点にし、`ffi 1.17.3` と `nokogiri 1.19.2` の 3 変種（aarch64-linux-gnu / arm64-darwin / x86_64-linux-gnu）をそれぞれ 1 行にする
- group は default・development・test を、推移的な依存を含めて付ける。`Bundler.definition.specs_for` はこの環境（aarch64-linux）の platform の変種にしか group を返さないため、この環境に入っていない platform 変種（`ffi-1.17.3-arm64-darwin`・`ffi-1.17.3-x86_64-linux-gnu`・`nokogiri-1.19.2-arm64-darwin`・`nokogiri-1.19.2-x86_64-linux-gnu`）の行には、同じ名前・バージョンでこの環境に入っている変種の group を付け、根拠にその旨を書く。「どの group からも使われない」は、platform を問わず group から辿れないエントリだけに使う
- ライセンスは、この環境（aarch64-linux）に入っている変種は gemspec の `licenses` と同梱文書（`LICENSE*`・`COPYING*`・`LICENSE-DEPENDENCIES.md` など）の両方、入っていない変種は rubygems.org API v2 の `licenses` から取る。入っていない変種の同梱文書は読まない（「同梱文書で確かめたライセンス」の列には「未インストールのため未確認」と書く）。その変種の同梱 C ライブラリの注記は、同じ名前・バージョンでこの環境に入っている変種の同梱文書から引き、根拠にその旨を書く
- 追跡ファイルは拡張子・`file --mime-type`・初出コミット・ヘッダーの参照 URL で分類し、合計を `git ls-files` の件数に合わせる。分類の途中で第三者由来・出所不明と分かった物は、REQ-004 に挙げた候補でなくても 1 件ずつ扱う
- 調べる道具とスクリプトはリポジトリに入れない。`Gemfile`・`Gemfile.lock`・`.bundle/`・`lefthook.yml`・`.lefthook/` は変えない

## Behavior Requirements

- **REQ-001**: 変更は `docs/license-inventory.md` の追加 1 つだけ。`LICENSE` を追加せず、README などにライセンスの表記を書かない。冒頭に目的、時点（日付と調べた main のコミット）、調べ方の要約、法的結論ではないこと、`LICENSE` が未追加であることを書く
- **REQ-002**: gem の一覧に、`Gemfile.lock` の全エントリ（platform 変種ごと）と `bundler` が 1 行ずつあり、各行に名前・バージョン・platform・group・宣言ライセンス・同梱文書で確かめたライセンス・根拠・分類（問題なし／注記あり／要確認／妨げ候補）がある。この環境に入っていない platform 変種の行の group は、同じ名前・バージョンでこの環境に入っている変種の group と同じにし、根拠にその旨を書く（Technical Stories の 2 項目目）。この環境に入っていない変種の行の「同梱文書で確かめたライセンス」の列は「未インストールのため未確認」とし、その 4 変種を「確かめきれない物」に入れて、確かめる方法（例: システムの一時ディレクトリで `gem fetch <名前> -v <バージョン> --platform <platform>` と `gem unpack` をして同梱文書を読む）を書く（Technical Stories の 3 項目目）。gem が使うシステムライブラリ（libvips、MySQL クライアントライブラリ）は該当行の注記に書く
- **REQ-003**: platform 変種を持つ gem（nokogiri・ffi）は、同梱の C ライブラリのライセンス（`LICENSE-DEPENDENCIES.md` など）を注記に書く。この環境に入っていない変種の行の注記は、この環境に入っている同じバージョンの変種の同梱文書から引いたことを書く
- **REQ-004**: コード以外の物の一覧で、`git ls-files` の全件がいずれかのカテゴリに入り、カテゴリの件数の合計が `git ls-files` の件数と一致する。自作のコード・文書・設定はカテゴリ単位で件数とパスの範囲を書き、第三者由来の候補・出所不明・バイナリは 1 件ずつパス・参照元・出所・ライセンス・分類を書く。submodule（`.github/COMMIT_CONVENTION`）は参照先のリポジトリ単位で 1 行にする。第三者由来の候補として少なくとも `.claude/skills/gh-stack/`（4 ファイル）、`config/locales/devise_token_auth.ja.yml`、`config/locales/active_storage_validations.ja.yml`、`Docker/web/nginx/nginx.conf`、`.bruno/Collection/480x320.png` を確かめる。この候補の確かめで終えず、分類の途中で第三者由来・出所不明と分かったほかの物も同じく 1 件ずつ書く
- **REQ-005**: 「妨げになる物」と「確かめきれない物」の 2 節があり、各項目に対象・理由・根拠（ファイルパスや URL）がある。「妨げになる物」には考えられる対応（報告だけで、実施しない）、「確かめきれない物」には確かめる方法を書く。該当が無ければ「無し」と書く。判定は設計の「前提」4・5 の基準に従う（同梱される物は、第三者の権利がありライセンスが不明・再配布不可・MIT と両立しない条件なら妨げ候補、MIT 等で表示の保持が要る物は「表示が必要」。gem は GPL・AGPL や宣言無し・独自・不明なら妨げ候補か要確認、LGPL・MPL は注記付き、寛容なライセンスは問題なし。宣言と同梱文書の食い違い・宣言無し・出所の記録無し・上流をこの環境から確かめられない物は「確かめきれない物」。同梱文書を読んでいない未インストールの platform 変種は、上流をこの環境から確かめられない物に当たる）
- **REQ-006**: 調べる道具・スクリプト・中間出力がリポジトリに残らない（システムの一時ディレクトリに置く）。`lefthook.yml`・`.lefthook/`・`Gemfile`・`Gemfile.lock`・`.bundle/` は変わらない。コミット時の lefthook の pre-commit は飛ばさず、落ちたら内容を直す
- **REQ-007**: 作業ブランチとコミットは `git-spice-workflow` Skill に従い、worktree で作る。PR を出すかは後段の lane の設定に従う（このワークフローは `open_pr=false`、`push=true`）。後段で PR が作られない場合は、依頼の「PR を出すところまで」が満たされないことを後段の bead に残す

## Example Mapping

- **規則: platform 変種は変種ごとに 1 行**
  - 例: `nokogiri 1.19.2` は aarch64-linux-gnu・arm64-darwin・x86_64-linux-gnu の 3 行になり、arm64-darwin の行のライセンスは rubygems.org API v2 の `licenses`（`["MIT"]`）を根拠にする。同じ行の「同梱文書で確かめたライセンス」の列は「未インストールのため未確認」、C ライブラリの注記は aarch64-linux-gnu の変種の `LICENSE-DEPENDENCIES.md` から引いたと書き、この行を「確かめきれない物」に入れる
- **規則: group は推移的な依存を含めて全部付ける**
  - 例: `rubocop` の行の group は development だけ。`rails` の行は default（ほかの group からも使われるならそれも）
  - 例: `nokogiri 1.19.2` の arm64-darwin・x86_64-linux-gnu の行は、`specs_for` が group を返さなくても、この環境に入っている aarch64-linux-gnu の変種と同じ group（default を含む）を付け、根拠に「この環境の変種の group を引き継いだ」と書く。`ffi 1.17.3` も同じ
- **規則: 宣言と同梱文書が食い違えば確かめきれない物**
  - 例: gemspec の `licenses` が `MIT` で同梱の `LICENSE` が別のライセンスの文なら、行に両方を書き、「確かめきれない物」に入れる
- **規則: 出所の記録が無いバイナリは確かめきれない物**
  - 例: `.bruno/Collection/480x320.png`（参照元 `.bruno/Collection/Auth/Change User Info.bru`、追加コミット `b48e28cf1`）は出所の記載が無いため、「確かめきれない物」に入れ、git の履歴から分かることを書く
- **規則: API に届かない変種は止めずに要確認**
  - 例: rubygems.org API が応答しない変種の行は「要確認（API 取得失敗）」にして「確かめきれない物」に入れ、作業を続ける

## Acceptance Criteria

1. `git status`・`git diff --stat`（main との差分）で、変更が `docs/license-inventory.md` の追加だけ。`LICENSE` が無い（REQ-001、REQ-006）
2. gem の一覧の行数が、`Gemfile.lock` の GEM 節のエントリ数 ＋ 1（`bundler`）と一致し、各行に group・宣言ライセンス・根拠・分類がある（REQ-002）
3. `nokogiri` と `ffi` がそれぞれ 3 行あり、同梱の C ライブラリのライセンスの注記がある。`nokogiri`・`ffi` の 3 変種の行がどれも group に default を含む。この環境に入っていない 4 変種の行の「同梱文書で確かめたライセンス」の列が「未インストールのため未確認」で、その 4 変種が「確かめきれない物」に確かめる方法付きで入っている。`rubocop` の group が development だけ、`rails` の group に default がある（REQ-002、REQ-003）
4. コード以外の物の一覧のカテゴリの件数の合計が `git ls-files | wc -l` と一致し、REQ-004 に挙げた第三者由来の候補とバイナリが 1 件ずつ参照元と出所付きで書かれている（REQ-004）
5. 「妨げになる物」「確かめきれない物」の 2 節があり、各項目に根拠がある（無ければ「無し」）（REQ-005）
6. リポジトリに調べる道具・スクリプト・中間出力が無く、`lefthook.yml`・`.lefthook/`・`Gemfile`・`Gemfile.lock` に差分が無い。コミットは lefthook の pre-commit を通っている。`check-docs.sh`（pre-commit と CI の `checks` ジョブ）は `docs/` の下の Markdown の相対リンクを、リンク元のディレクトリを基準に通常ファイルの存在（`-f`）で確かめるため、`docs/license-inventory.md` の中の相対リンクはすべて実在する通常ファイルを指す。ディレクトリ（例: `.claude/skills/gh-stack/`）・submodule（`.github/COMMIT_CONVENTION`）・空白を含むパス（例: `.bruno/Collection/Auth/Change User Info.bru`）はリンクにせずコード表記で書く（REQ-006）
7. ブランチとコミットが `git-spice-workflow` Skill の形に従っている。PR の有無が後段の bead に記録されている（REQ-007）

### Coverage

| ID | Status |
| --- | --- |
| REQ-001 | covered |
| REQ-002 | covered |
| REQ-003 | covered |
| REQ-004 | covered |
| REQ-005 | covered |
| REQ-006 | covered |
| REQ-007 | covered |

### Testing Expectations

コードを入れないため自動テストは足さない。確かめは上の受け入れの条件の件数の照合・抜き取り・差分の範囲の確認と、コミット時の lefthook の pre-commit で行う。

### Risks

- rubygems.org API や上流のリポジトリに届かないと、一部の行が「要確認」になる（作業は止めない）
- 同梱文書の自動の照合は単純な一致にとどまるため、食い違いの判断は人が読む必要がある
- 一覧はスナップショットのため、依存の更新（Dependabot の bundler の日次更新）で古くなる。冒頭の時点の記載で読み手に分かるようにする
- 依頼の「PR を出すところまで」とワークフロー変数 `open_pr=false` が食い違う。設計の承認 lane（tb-cyd40）が mayor に知らせ済み

## Out Of Scope

- `LICENSE` の追加とライセンスの決定
- 調べる道具（LicenseFinder など）やスクリプトのリポジトリへの追加、CI への組み込み
- gem の入れ替え・削除・バージョンの変更、ファイルの差し替え（妨げの解消は報告まで）
- 未追跡のファイル（例: `_bmad/`）と submodule の中身の全ファイルの調査
- Ruby 本体・OS パッケージ（Docker イメージの中身）の全件の調査
- 依頼のほかの部分（CI に入れる道具、PR 本文の確かめ）

## Open Questions

- 無し。設計の承認時に、PR の扱い（後段の lane の設定に従う。PR が出ないなら後段の bead に残す）と計画の要否（planning lane が `.claude/rules/plans-maintenance.md` に従って決める）は決まっている
