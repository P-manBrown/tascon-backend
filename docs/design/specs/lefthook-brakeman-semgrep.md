# lefthook-brakeman-semgrep specification

## Approved requirements

## 要件: lefthook に Brakeman（pre-push）と Semgrep（pre-commit）を入れる

- 依頼: tb-13xb6（依頼 gc-wvsr の一部、human-request-part）
- build root: tb-dq5i9（superpowers-build、autonomous）
- この要件を書いた bead: tb-l05hr（requirements.write-requirements-spec、iteration 1、attempt 1）
- 承認済みの設計: /home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/design.md（承認の記録: /home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/design-approval.md、承認レーン tb-4adpe）
- 土台ブランチ: `ci/add-mutant-report`
- `docs/superpowers/specs/` への写し: 置かない。このレーンはコミットせず、本体の作業場所（main のチェックアウト）にはファイルを書かない決まりのため、この要件は作業の成果物の置き場所（上の artifact root）だけに置く。正本はこのファイル

### Problem Statement

tascon-backend では、Brakeman と Semgrep は CI の job（`brakeman`・`semgrep`）でしか走らない。そのため、問題のある変更は push して CI が落ちるまで分からない。人の返事（tb-13xb6 に原文）は、ルール `.claude/rules/lefthook-ci-placement.md` の「lefthookの段」と「lefthookでの直し」に合わせて、Brakeman を pre-push（プロジェクト全体が要る）、Semgrep を pre-commit（変えたファイルだけで確かめられる）で走らせるよう求めている。

ところが、いまの Dev Container には Semgrep を入れる手段（`pip`・`ensurepip`・venv）が無く、`python3` も Dockerfile で明示的に入れた物ではない。ルール `.claude/rules/scripts-authoring.md` は明示的に入れた言語・コマンドだけでスクリプトを書くよう求める。また決定記録 `docs/decisions/test-and-check-tool-selection.md` は、Semgrep の版を hash 付き requirements で、規則を `ci.yml` の `ref:` の SHA で固定し、規則をリポジトリに写さないと決めている。この制約の中で、手元のフックでも CI と同じ版・同じ規則・同じ引数で 2 つを走らせる必要がある。

### W6H

- Who（誰のため）: tascon-backend で Dev Container を使ってコミット・push する開発者（人と AI のエージェント）
- What（何を）: lefthook の pre-commit に Semgrep、pre-push に Brakeman を足す。Semgrep を手元で走らせるため、Dev Container のイメージに `python3`・`python3-venv` を明示的に入れ、Semgrep 本体と規則を用意して走らせるスクリプト `.lefthook/pre-commit/semgrep.sh` を足す
- When（いつ走るか）: Semgrep はコミットのたび（ステージしたファイルが 1 つ以上あるとき）。Brakeman は push のたび。Semgrep 本体と規則の用意は、キャッシュに無いとき（初回、または `semgrep.txt`・規則の SHA・`python3` の版が変わったとき）だけ
- Where（どこで）: 変えるのは `lefthook.yml`・`.lefthook/pre-commit/semgrep.sh`・`Docker/api/Dockerfile`。Semgrep 本体と規則のキャッシュはリポジトリの外の `${XDG_CACHE_HOME:-$HOME/.cache}/tascon-backend/semgrep/`。作業の枝は `ci/add-mutant-report` の上に積む
- Why（なぜ）: 問題を push や CI の前に手元で見つけるため。段の割り当ては人の返事とルール `lefthook-ci-placement` で決まっている
- Which（どの版・規則で）: Semgrep の版は `.github/requirements/semgrep.txt`（`--require-hashes`）、規則は `.github/workflows/ci.yml` の job `semgrep` の `semgrep/semgrep-rules` の `ref:` の SHA の `ruby/rails`。どちらも CI と同じ 1 か所から読む
- How（どう走らせるか）: Semgrep は `semgrep scan --config "<規則>/ruby/rails" --metrics=off --error -- <ステージしたファイル>`、Brakeman は `bin/bundle exec brakeman --no-pager`。どちらも直さず、報告して落とすだけ

### User Stories

- 開発者として、ルール `ruby/rails` に当たるコードをコミットしようとしたとき、コミットの時点で Semgrep に止められたい。push して CI が落ちるのを待たずに直せるように
- 開発者として、Brakeman が警告を出すコードを push しようとしたとき、push の時点で止められたい。CI の job `brakeman` が落ちる前に直せるように
- 開発者として、手元の Semgrep と CI の Semgrep が同じ版・同じ規則で結果が揃っていてほしい。手元で通ったのに CI で落ちる、またはその逆が起きないように
- 開発者として、Semgrep や venv が用意できないときは、理由と直し方を示して止めてほしい。確かめていないのに通ったように見えないように

### Technical Stories

- メンテナとして、Semgrep の版（`semgrep.txt`）や規則の SHA（`ci.yml`）を上げたとき、イメージを作り直さずに手元のフックが新しい版・規則を使ってほしい（キャッシュの鍵が変わって作り直す）
- メンテナとして、Semgrep の規則をリポジトリにもイメージにも写したくない（決定記録の配布の制約）
- メンテナとして、lefthook のスクリプトが、Dockerfile 等で明示的に入れた言語・コマンドだけを使っていてほしい（ルール `scripts-authoring`）
- メンテナとして、イメージを作り直した後に `python3-venv` が実際に入っていることを、後から自動で確かめられるようにしたい（check bead）

### Behavior Requirements

#### REQ-001: pre-commit の Semgrep

- `lefthook.yml` の pre-commit の `commands:` に、次の項目 `semgrep` を足す

  ```yaml
      semgrep:
        run: bash .lefthook/pre-commit/semgrep.sh {staged_files}
        fail_text: 'Read the report above.'
  ```

- `glob` を付けない。どのファイルにどの規則を当てるかは、CI と同じく Semgrep が規則の `languages`・`paths` から決める
- `stage_fixed` を付けず、`--autofix` も使わない（直さない）
- ステージしたファイルが無いとき（`{staged_files}` が空）は、lefthook の挙動のとおり項目を飛ばしてよい
- ステージしたファイルがあり、そのどれにも規則が当たらないとき（例: `.md` だけ）は、Semgrep が 0 で終わり、コミットは通る

#### REQ-002: pre-push の Brakeman

- `lefthook.yml` の pre-push の `commands:` に、次の項目 `brakeman` を足す

  ```yaml
      brakeman:
        run: bin/bundle exec brakeman --no-pager
        fail_text: 'Read the report above.'
  ```

- `glob` を付けず、プロジェクト全体で走らせる（CI の job `brakeman` と同じコマンド）
- Brakeman が警告を出したら非 0 で終わり、push を止める

#### REQ-003: Dev Container のイメージ

- `Docker/api/Dockerfile` の既存の apt の `RUN`（いま `libvips42` を入れている `apt-get install -y --no-install-recommends` の行）に `python3`・`python3-venv` を足す
- 新しい `RUN` の層は作らない
- イメージのビルドはこの Dev Container の中で試せない（docker が無い）。代わりにいまの Dev Container で `sudo apt-get install -y --no-install-recommends python3 python3-venv` を実行し、Dockerfile と同じ状態にして確かめる

#### REQ-004: Semgrep を走らせるスクリプト `.lefthook/pre-commit/semgrep.sh`

- bash で書く。使う言語・コマンドは bash、git、python3（venv）、ruby、`sha256sum` だけ
- 規則の SHA: `ruby -ryaml` で `.github/workflows/ci.yml` を読み、job `semgrep` のステップのうち `with.repository == "semgrep/semgrep-rules"` のものの `with.ref` を取る。見つからない、または 40 桁の 16 進でないときは、理由を標準エラー出力に書いて非 0 で終わる
- キャッシュの置き場所: `${XDG_CACHE_HOME:-$HOME/.cache}/tascon-backend/semgrep/`（リポジトリの外）
  - venv: `venv-<鍵>`。鍵は `semgrep.txt` の sha256 と `python3` の版から作る。venv に `python -m pip install --require-hashes -r .github/requirements/semgrep.txt` で入れる
  - 規則: `rules-<SHA>`。`git init` → `git fetch --depth 1 --filter=blob:none origin <SHA>`（`origin` は `https://github.com/semgrep/semgrep-rules`）→ sparse-checkout で `ruby/rails` だけ取り出す
  - どちらも一時ディレクトリで作り、出来上がってから `mv` で置く。`mv` が失敗し、置き場所に既に出来上がった物があるときは、作った物を捨てて置かれた物を使う（2 つの worktree が同時に初回を走らせた場合）
  - キャッシュにあれば作り直さない
- 走らせ方: `"<venv>/bin/semgrep" scan --config "<rules>/ruby/rails" --metrics=off --error -- "$@"`。終了コードはそのまま返す
- 失敗の扱い: 次のどれも、理由と直し方を標準エラー出力に書いて非 0 で終わる（黙ってコミットを通さない）
  - `python3 -m venv` ができない: 「Dev Container を作り直すか、`sudo apt-get install -y python3-venv` を実行する」と書く
  - pip の導入、または規則の取り出しが失敗した: 失敗したコマンドの出力を見せ、作りかけの一時ディレクトリを消す
- 規則をリポジトリにもイメージにも置かない
- 明示的に渡したファイルにも、CI と同じリポジトリ全体の走査と同じ無視（`.semgrepignore`・Semgrep の既定の無視）が効く。効かないことが分かったときは、全体の走査と同じ無視が効く渡し方にスクリプトを直す（REQ-005 の突き合わせで確かめる）

#### REQ-005: Dev Container での実際の確かめ

土台の中身の作業場所で、次を実際に走らせ、結果（コマンド、終了コード、かかった時間、出力の要点）を実装の記録（`gc.build.implementation_summary_path`）に残す。

- Semgrep
  - キャッシュが空の状態から `bash .lefthook/pre-commit/semgrep.sh <ruby のファイル>` が venv と規則を用意し、0 で終わる
  - 2 回目はキャッシュを使い、導入をし直さない
  - 規則に当たる一時的な変更（例: `html_safe` を使う `.erb`）をステージして `lefthook run pre-commit` を走らせると、非 0 で落ちて報告が出る。確かめた後に変更を戻す
  - 規則に当たらない変更（例: `.md` だけ）をステージして `lefthook run pre-commit` を走らせると、`semgrep` が 0 で終わる。かかった時間を記録する
  - 同じファイルについて、スクリプトの結果と、CI と同じ全体の走査（リポジトリの根で `semgrep scan --config <規則>/ruby/rails --metrics=off --error`）の結果が一致する。Semgrep が既定で無視する場所のファイルを明示的に渡したとき、全体の走査で出ない報告が出ないことも確かめる
- Brakeman
  - `lefthook run pre-push` で `brakeman` が走り、いまの土台の中身で 0 で終わる。かかった時間を記録する
  - Brakeman が警告を出す一時的な変更（例: コントローラで `params` を `eval` する行）で非 0 で落ちる。確かめた後に変更を戻す
- 既存の項目（rubocop・protect-branch・`check-git-clean` 等）の結果が、変更の前と変わらない

#### REQ-006: CI を変えない

- `.github/workflows/ci.yml` の job `brakeman`・`semgrep` を変えない（ファイル全体も変えない）

#### REQ-007: 範囲の外の物に触らない

- 別の作業 tb-eow1n（ブランチ `chore/lefthook-stage-placement`）が受け持つ項目（debride・`check-docs.sh`・pre-commit の確かめの試し 2 つ・htmlbeautifier）を変えない
- `.claude/rules/` のルールの文を変えない
- この変更は、ルールの PR（#846・#847）と別の PR にする。枝は `ci/add-mutant-report` の上に積む
- `lefthook.yml` に項目を置く位置は、tb-eow1n の変更（pre-commit の htmlbeautifier・debride の行、pre-push の `check-git-clean` の前後）と重なりにくい所にする。積み直しで重なったときは、両方の項目を残して解く

#### REQ-008: スクリプトの言語・コマンドとコメント

- `.lefthook/pre-commit/semgrep.sh` が使う言語・コマンドは、Dockerfile・ベースイメージ・devcontainer の features・パッケージの管理ファイルで明示的に入れた物だけ（`python3` は REQ-003 で明示的に入れる。ruby・git・bash・`sha256sum` はベースイメージ `ruby:4.0.0` の物）
- `.lefthook/**`・`Docker/**` に書くコードコメントは英語（ルール `code-comments`）

#### REQ-009: イメージの作り直しの後の check bead

- 実装の段で、次の check bead を登録する
  - `gc.check.kind`: `path_exists`
  - `gc.check.mode`: `must_hold`
  - `gc.check.scope`: この rig（tascon-backend）
  - `gc.check.args`: `{"path": "<python3-venv が置く ensurepip のパス>"}`。パスは実装の段で `dpkg -L python3.13-venv` の出力から決める（`/` で始まる絶対パス）
- タイトルと説明は日本語で、何を確かめるか（イメージを作り直した後に `python3-venv` が入っていること）と、落ちたときにすること（Dockerfile の apt の行を確かめる）を書く

#### 文書の扱い

- 新しい決定記録は書かない
- 実装の段で、`docs/decisions/test-and-check-tool-selection.md` の Related Files・Consequences に手元の実行を書き足すべきかを、`.claude/rules/decisions-maintenance.md` に照らして決める。ルールが求めるときだけ書き足し、求めないときは書き足さない。どちらにしたかを実装の記録に残す

### Example Mapping

#### 規則 1: Semgrep はステージしたファイルだけを、CI と同じ版・規則・引数で見る（REQ-001・REQ-004）

- 例: `app/views/foo.html.erb` に `html_safe` の行を足してステージ → コミットが非 0 で止まり、Semgrep の報告が出る
- 例: `README.md` だけを変えてステージ → `semgrep` は 0 で終わり、コミットは通る
- 例: 何もステージせずに `git commit --amend --no-edit` → `{staged_files}` が空なので lefthook が `semgrep` を飛ばす
- 例: Semgrep が既定で無視する場所のファイルをステージ → 全体の走査で出ない報告は出ない

#### 規則 2: Semgrep 本体と規則は、無いときだけ用意し、用意できなければ止める（REQ-004）

- 例: キャッシュが空の初回のコミット → venv と規則を用意してから走る（ネットワークが要り、時間がかかる）
- 例: 2 回目のコミット → キャッシュを使い、導入をし直さない
- 例: Dependabot が `semgrep.txt` を上げた後のコミット → 鍵が変わるので新しい venv を作る
- 例: `ci.yml` の規則の `ref:` を手で上げた後のコミット → 新しい `rules-<SHA>` を取り出す
- 例: `python3-venv` が入っていない Dev Container でのコミット → 「Dev Container を作り直すか、`sudo apt-get install -y python3-venv` を実行する」と出して非 0 で止まる
- 例: ネットワークが切れていて初回の導入が失敗 → 失敗したコマンドの出力を見せ、一時ディレクトリを消して非 0 で止まる
- 例: 2 つの worktree が同時に初回のコミット → 後から `mv` した方は自分の作った物を捨て、置かれた物を使う

#### 規則 3: Brakeman は push のたびにプロジェクト全体を CI と同じコマンドで見る（REQ-002）

- 例: いまの土台の中身で push → `brakeman` が 0 で終わり、push は進む
- 例: コントローラに `eval(params[:code])` を足してコミットし push → `brakeman` が非 0 で終わり、push が止まる

#### 規則 4: CI と範囲の外の物は変えない（REQ-006・REQ-007）

- 例: 変更の後の `git diff ci/add-mutant-report -- .github/workflows/ci.yml .claude/rules/` → 差が無い
- 例: 変更の後の `lefthook.yml` の debride・htmlbeautifier の項目 → 土台と同じ

### Acceptance Criteria

| ID | 受け入れの条件 | 確かめ方 | Status |
| --- | --- | --- | --- |
| REQ-001 | `lefthook.yml` の pre-commit に `semgrep`（`bash .lefthook/pre-commit/semgrep.sh {staged_files}`）があり、`glob`・`stage_fixed`・`--autofix` が無い | `lefthook.yml` を読む。`lefthook run pre-commit` で当たる変更が落ち、当たらない変更が通る | covered |
| REQ-002 | `lefthook.yml` の pre-push に `brakeman`（`bin/bundle exec brakeman --no-pager`）があり、`glob` が無い | `lefthook.yml` を読む。`lefthook run pre-push` で土台の中身が通り、当たる変更が落ちる | covered |
| REQ-003 | `Docker/api/Dockerfile` の既存の apt の行が `python3`・`python3-venv` を明示的に入れている | Dockerfile を読む。いまの Dev Container に同じ apt を実行して venv が作れる | covered |
| REQ-004 | `semgrep.sh` が `semgrep.txt` を `--require-hashes` で使い、規則の SHA を `ci.yml` から読み、リポジトリの外のキャッシュに置き、CI と同じ `--config`・`--metrics=off`・`--error` で走らせ、用意できないときは理由と直し方を出して非 0 で終わる | スクリプトを読む。REQ-005 の実行の結果 | covered |
| REQ-005 | この Dev Container で、Semgrep と Brakeman がフックから実際に走り、当たる変更で落ち、当たらない変更で通り、Semgrep の結果が CI と同じ全体の走査と一致する。結果が実装の記録に残っている | 実装の記録（`implementation-summary.md`）を読む | covered |
| REQ-006 | `.github/workflows/ci.yml` が土台と同じ | `git diff ci/add-mutant-report -- .github/workflows/ci.yml` が空 | covered |
| REQ-007 | tb-eow1n の項目（debride・`check-docs.sh`・試し 2 つ・htmlbeautifier）とルールの文が土台と同じ。PR がルールの PR（#846・#847）と別で、枝が `ci/add-mutant-report` の上にある | `git diff` で該当の箇所と `.claude/rules/` に差が無い。枝の親を確かめる | covered |
| REQ-008 | スクリプトが使う言語・コマンドがすべて明示的に入れた物で、`.lefthook/**`・`Docker/**` のコメントが英語 | スクリプトと Dockerfile を読む | covered |
| REQ-009 | イメージの作り直しの後に ensurepip のパスがあることを確かめる check bead（`path_exists`、`must_hold`）が登録されている | `gc bd list -l check-later` で bead と metadata を確かめる | covered |

テストの期待: 自動のテストは足さない。スクリプトの中身の大半が外の道具の導入と実行で、既存の `.lefthook/pre-commit/tests/` は tb-eow1n の作業で CI だけに移るため。代わりに REQ-005 の実際の実行と、`lefthook.yml` を変えたときに走る既存の確かめ（`bin/bundle exec rubocop` 等）が通ることで確かめる。

### Out Of Scope

- `.github/workflows/ci.yml`（job `brakeman`・`semgrep` を含む）を変えること
- tb-eow1n が受け持つ項目（debride・`check-docs.sh`・pre-commit の確かめの試し 2 つ・htmlbeautifier）を動かすこと
- `.claude/rules/` のルールの文を変えること
- push する ref と作業ツリーの中身の違いを埋めること（pre-push の Brakeman は作業ツリーを見る。既存の `check-git-clean` が未コミットの変更を止める。HEAD 以外の枝を push する場合は、既存の pre-push の確かめと同じく扱わない）
- 一部だけステージしたファイルの扱いを変えること（既存の rubocop と同じ lefthook の挙動に任せる）
- Zed で `postCreateCommand` が走らない問題（tech-debt `zed-devcontainer-postcreate-not-run.md`）を直すこと
- Semgrep の規則の SHA の置き場所を `ci.yml` から動かすこと
- Semgrep・Brakeman の報告を lefthook で直すこと（`--autofix` 等）
- 新しい決定記録を書くこと

### Open Questions

人に聞く必要のある問いは無い。次は設計の判断ではなく、実装の段で確かめる事実で、それぞれ確かめた後の扱いも決まっている。

- `semgrep==1.186.0` とその依存の aarch64 の wheel が `semgrep.txt` の hash に含まれ、この Dev Container の venv に入るか。入らないときは、実装の段を blocked にして理由を bead に書く（`semgrep.txt` は CI と共有のため、この作業の中で勝手に変えない）
- 明示的に渡したファイルに、全体の走査と同じ無視が効くか。効かないときは REQ-004 のとおり渡し方を直す
- `python3-venv` が置く ensurepip の正確なパス。`dpkg -L python3.13-venv` で決め、REQ-009 の check bead の対象にする
- CI の Python（3.13.18）と Dev Container の `python3`（3.13.5）のパッチ版の違いで結果がずれないか。REQ-005 の全体の走査との突き合わせで確かめる

## Adopted design

## 設計候補: lefthook に Brakeman（pre-push）と Semgrep（pre-commit）を入れる

- 依頼: tb-13xb6（依頼 gc-wvsr の一部、human-request-part）
- build root: tb-dq5i9（superpowers-build、autonomous）
- この設計を書いた bead: tb-f2idt（requirements.brainstorm-design、iteration 1、attempt 1）
- 土台ブランチ: `ci/add-mutant-report`（未マージのスタックの最上段）
- 承認の状態: **承認済み**（tb-4adpe、autonomous）。autonomous の承認根拠は末尾の「承認の状態」に記す

### Superpowers のチェックリスト（1〜5）の記録

1. プロジェクトの文脈の確認: 済（下の「確かめた事実」）
2. 画面で見せる問いがあるか: 無い。設定とスクリプトの変更で、見た目の選択が無いため Visual Companion は申し出ていない
3. 確かめの問い: 人に聞く問いは無い。依頼の本文（人の返事の原文）と、リポジトリのルール・決定記録・土台ブランチの中身で答えが決まった。決めた前提は「決めた前提」に記す
4. 2〜3の案と長所・短所・推し: 済（「案の比較」）
5. 推しの設計を節に分けて示す: 済（「設計」）

### 求める結果

- tascon-backend の lefthook で、Brakeman を pre-push、Semgrep を pre-commit（コミットする、変えたファイルだけ）で走らせる
- 手元（Dev Container）で、この 2 つが実際に走る
- CI の job `brakeman`・`semgrep` はそのまま残す

### 制約

- ルール `.claude/rules/lefthook-ci-placement.md`（PR #847。土台にはまだ無い）の「lefthookの段」と「lefthookでの直し」に合わせる
  - pre-commit: 変えたファイルだけで確かめられる物 → Semgrep
  - pre-push: プロジェクト全体は要るが、ビルド・サーバー・ブラウザ・DB は要らない物 → Brakeman
  - lefthook で直すのは意味を変えないと保証された直しだけ → Semgrep の `--autofix` は使わない。どちらも報告して落とすだけ
  - 「lefthookかCIのどちらかを変えたら、同じPRでもう一方にも要るかを確かめる」→ CI 側は変えない（CI は既にリポジトリ全体で両方を走らせている）
- ルールの文は変えない
- `.claude/rules/scripts-authoring.md`: lefthook のスクリプトは、Dockerfile・ベースイメージ・devcontainer の features・パッケージの管理ファイルで明示的に入れた言語・コマンドだけで書く。ほかの道具の依存として入っているだけのものは使わない
- `.claude/rules/code-comments.md`: `.lefthook/**`・`.devcontainer/**` のコードコメントは英語
- 決定記録 `docs/decisions/test-and-check-tool-selection.md`
  - 外から持ち込む物は不変の ID で固定する（Python の道具は `.github/requirements/` の hash 付き requirements、取り出す規則は `ci.yml` の `ref:` の SHA）
  - Semgrep の規則は、ライセンスが配布を許さないと読めるため、リポジトリに写さない
  - 規則の SHA は `ci.yml` の job `semgrep` の `ref:` にあり、手で更新する
- 別の作業（tb-eow1n、ブランチ `chore/lefthook-stage-placement`、base main）の項目には触らない: debride・`check-docs.sh`・pre-commit の確かめの試し 2 つ・htmlbeautifier
- lefthook の設定の直しは、ルールの PR（#846・#847）と別の PR にする

### 非目標

- CI のワークフロー（`.github/workflows/ci.yml`）を変えること
- tb-eow1n が受け持つ項目（debride・`check-docs.sh`・試し 2 つ・htmlbeautifier）を動かすこと
- push する ref と作業ツリーの中身の違いを埋めること（pre-push の Brakeman は作業ツリーを見る。既存の `check-git-clean` が未コミットの変更を止めるので、作業ツリーは HEAD と同じになる。HEAD 以外の枝を push する場合の違いは、既存の pre-push の確かめと同じく扱わない）
- 一部だけステージしたファイルの扱いを変えること（既存の rubocop と同じ lefthook の挙動に任せる）
- Zed で `postCreateCommand` が走らない問題（tech-debt `zed-devcontainer-postcreate-not-run.md`）を直すこと。この設計はその経路に頼らない
- Semgrep の規則の SHA の置き場所を `ci.yml` から動かすこと

### 確かめた事実（2026-11-20、この Dev Container と `origin/ci/add-mutant-report` で確認）

- 土台の `lefthook.yml` に `brakeman`・`semgrep` の項目は無い。pre-commit は `parallel: true` で `commands:`（rubocop・htmlbeautifier・debride・protect-branch）と `jobs:` を持つ。pre-push は `commands:` の `check-git-clean` だけ
- CI（`ci.yml`）
  - job `brakeman`: コンテナ `ruby:4.0.0`、`bundle install` の後に `bin/bundle exec brakeman --no-pager`
  - job `semgrep`: `semgrep/semgrep-rules` を `ref: a5ad1714f00c9f7fde980cab0ea1d6dc6d414fd2`、`sparse-checkout: ruby/rails` で取り出し、作業場所の外（`$RUNNER_TEMP/semgrep-rules`）へ移す。Python 3.13.18 で `python -m pip install --require-hashes -r .github/requirements/semgrep.txt`（`semgrep==1.186.0`）。`semgrep scan --config "$RUNNER_TEMP/semgrep-rules/ruby/rails" --metrics=off --error`
- Brakeman は `Gemfile` の development group の gem（`~> 8.1`）。この Dev Container には `/usr/local/bundle/bin/brakeman` がある。main の `Gemfile` には無いので、main の作業ツリーでは `bin/bundle exec brakeman` が落ちる（土台の中身で走らせる必要がある）
- Dev Container は `compose.yml` の service `api`（`Docker/api/Dockerfile`、`FROM ruby:4.0.0`、Debian 13.3、aarch64）。`python3` は 3.13.5 があるが、Dockerfile では明示的に入れていない（apt で入れているのは `libvips42` だけ）。`pip`・`ensurepip` が無く、`semgrep` も無い。apt の `python3-venv` は候補 3.13.5-1 がある
- この Dev Container の中に docker は無い（イメージのビルドを中で試せない）。`sudo` は使える。GitHub へのネットワークは通る（`git ls-remote https://github.com/semgrep/semgrep-rules` が成功）
- `Docker/api/Dockerfile` は compose の開発用の service だけが使う（ほかの参照は `.github/dependabot.yml` の `directory: "/Docker/api"`）
- 固定の SHA の `ruby/rails` の規則（53 ファイル）が対象にする言語は、ruby（大半）、generic（`paths.include: '*.erb'`）、yaml（`'*secrets.*.yml'`・`'*secrets.*.yaml'`）
- `.claude/rules/hooks-authoring.md` は `.claude/settings.json`・`.claude/hooks/**` だけが対象で、この変更には当たらない

### 案の比較

#### 案 A（推し）: Dockerfile で Python と venv を明示的に入れ、Semgrep 本体と規則は初回の実行時に手元のキャッシュへ用意する

- Dockerfile の apt の行に `python3`・`python3-venv` を足す（明示的に入れる）
- Semgrep を走らせるスクリプトが、初回に venv を作って `.github/requirements/semgrep.txt` から `--require-hashes` で入れ、規則を `ci.yml` の `ref:` の SHA で取り出して、どちらもリポジトリの外のキャッシュに置く。2 回目からはキャッシュを使う
- 長所
  - Semgrep の版と規則の SHA を CI と同じ 1 か所から読む。Dependabot が `semgrep.txt` を上げても、手で SHA を上げても、イメージを作り直さずに手元が追いつく（キャッシュの鍵が変わって作り直す）
  - 規則をリポジトリにもイメージにも写さない（決定記録の配布の制約に合う）
  - いまの Dev Container でも、`sudo apt-get install python3-venv` で Dockerfile と同じ状態にして、実際に走ることを確かめられる
  - Zed で走らない `postCreateCommand` に頼らない
- 短所
  - 初回のコミットでネットワークが要り、Semgrep の導入に時間がかかる
  - Dockerfile の変更は、この Dev Container の中ではビルドして確かめられない（後で確かめる bead を登録する）
  - フックが道具の導入をする

#### 案 B: Semgrep 本体と規則をイメージのビルドで入れる

- Dockerfile で venv を作り `semgrep.txt` から入れ、規則も SHA で取り出しておく
- 長所: 初回のコミットが速い。コミットの時にネットワークが要らない
- 短所
  - `semgrep.txt` の更新や規則の SHA の更新のたびにイメージを作り直す必要があり、作り直すまで手元と CI の版がずれる
  - 規則の SHA を Dockerfile にも書くか、ビルドで `ci.yml` を読む仕組みが要る
  - この Dev Container の中で確かめられない（docker が無い）ので、「手元で実際に走る」をこの作業の中で示せない

#### 案 C: `postCreateCommand` か devcontainer の Python feature で入れる

- `postCreateCommand.sh` で pip と Semgrep を入れる、または `ghcr.io/devcontainers/features/python` を足す
- 長所: Dockerfile を変えない
- 短所
  - `postCreateCommand` は Zed で走らない（既存の tech-debt）。入れ忘れが起きる
  - Python feature は Python 一式と付随する道具を入れ、要る物（venv）より大きい。Semgrep 本体と規則の置き方は案 A と同じ問題が残る

#### 推しの理由

案 A を推す。CI と同じ固定（hash 付き requirements と規則の SHA）を 1 か所から読むので版がずれず、規則を写さず、いまの Dev Container で実際に走ることを示せる。初回の待ち時間は 1 回だけで、キャッシュは worktree の間で共有される。

### 設計（案 A）

#### 1. Dev Container のイメージ（`Docker/api/Dockerfile`）

- 既存の apt の `RUN` の `apt-get install -y --no-install-recommends libvips42` に `python3 python3-venv` を足す
- これで `python3` を明示的に入れたことになり、`scripts-authoring` のルールに合う
- イメージのビルドはこの Dev Container の中で試せないため、実装の段で check bead を登録する（`kind: path_exists`、`mode: must_hold`、対象は `python3-venv` が置く ensurepip のパス。正確なパスは実装の段で `dpkg -L python3.13-venv` で確かめて決める）
- 実装の段では、いまの Dev Container に `sudo apt-get install -y --no-install-recommends python3 python3-venv` を実行し、Dockerfile と同じ状態にして確かめる

#### 2. Semgrep を走らせるスクリプト（`.lefthook/pre-commit/semgrep.sh`、bash）

役割: 渡されたファイルに、CI と同じ版の Semgrep と同じ規則を、CI と同じ引数で走らせる。

- 入力: 引数のファイルのパス（lefthook の `{staged_files}`）
- 使う言語・コマンド: bash、git、python3（venv）、ruby（`ci.yml` を YAML として読む）、`sha256sum`。どれも明示的に入っているか、この変更で明示的に入れる
- 規則の SHA の読み方: `ruby -ryaml` で `.github/workflows/ci.yml` を読み、job `semgrep` のステップのうち `with.repository == "semgrep/semgrep-rules"` のものの `with.ref` を取る。見つからない・40 桁の 16 進でないときは、理由を標準エラー出力に書いて非 0 で終わる（黙って飛ばさない）
- キャッシュの場所: `${XDG_CACHE_HOME:-$HOME/.cache}/tascon-backend/semgrep/`
  - venv: `venv-<鍵>`。鍵は `semgrep.txt` の sha256 と `python3` の版から作る（Python が上がったときに古い venv を使わない）
  - 規則: `rules-<SHA>`。`git init` → `git fetch --depth 1 --filter=blob:none origin <SHA>` → sparse-checkout で `ruby/rails` だけ取り出す
  - どちらも一時ディレクトリで作り、出来上がってから `mv` で置く。同時に 2 つの worktree が初回を走らせても、片方の `mv` が失敗したら作った物を捨てて置かれた物を使う
  - リポジトリの外に置くので、Semgrep が規則のファイル自体を走査することは無く、規則をリポジトリに写すことも無い
- 走らせ方: `"<venv>/bin/semgrep" scan --config "<rules>/ruby/rails" --metrics=off --error -- "$@"`（CI と同じ引数に、対象のファイルを足す）。終了コードはそのまま返す
- 失敗の扱い（どれも理由と直し方を標準エラー出力に書き、非 0 で終わる。コミットを黙って通さない）
  - `python3 -m venv` ができない: 「Dev Container を作り直すか、`sudo apt-get install -y python3-venv` を実行する」と書く
  - pip の導入や規則の取り出しが失敗（ネットワーク等）: 失敗したコマンドの出力を見せ、作りかけの一時ディレクトリを消す
- メッセージは英語でも日本語でもよいが、コメントは英語（`code-comments`）

#### 3. `lefthook.yml`

pre-commit の `commands:` に足す:

```yaml
    semgrep:
      run: bash .lefthook/pre-commit/semgrep.sh {staged_files}
      fail_text: 'Read the report above.'
```

- `glob` は付けない。どのファイルにどの規則を当てるかは、CI と同じく Semgrep が規則の `languages`・`paths` から決める（規則の SHA を上げても glob を直す必要が無い）。対象の型のファイルが無いコミットでは、Semgrep が何も見ずに 0 で終わる
- `stage_fixed` は付けない（直さない）

pre-push の `commands:` に足す:

```yaml
    brakeman:
      run: bin/bundle exec brakeman --no-pager
      fail_text: 'Read the report above.'
```

- `glob` は付けない。Brakeman は `Gemfile.lock` や `config/` も見て判定するため、プロジェクト全体で走らせる（CI と同じコマンド）
- 置く位置は、tb-eow1n の変更（pre-commit の htmlbeautifier・debride の行、pre-push の `check-git-clean` の直前の debride と直後の `jobs:`）と重なりにくい所を選ぶ。積み直しで重なったら、両方の項目を残して解く

#### 4. 文書

- 新しい決定記録は書かない。CI と手元で同じ固定を使う、という既存の決定記録の方針の中に収まる
- 実装の段で、`docs/decisions/test-and-check-tool-selection.md` の Related Files や Consequences に手元の実行を書き足すべきかを、`decisions-maintenance` のルールに照らして確かめる（ルールが求めるときだけ書き足す）

#### 5. 確かめ方（テスト）

自動のテストは足さない（スクリプトの中身の大半が外の道具の導入と実行で、既存の `.lefthook/pre-commit/tests/` は tb-eow1n の作業で CI だけに移る）。代わりに、土台ブランチの中身の作業場所で、実際に次を走らせて結果を残す。

- Semgrep
  - キャッシュが空の状態から `bash .lefthook/pre-commit/semgrep.sh <ruby のファイル>` が venv と規則を用意し、0 で終わる
  - 2 回目はキャッシュを使う（導入をし直さない）
  - 規則に当たる行を持つ一時的なファイル（例: `html_safe` を使う `.erb`、または `nosemgrep` を外した既存の行）をステージして `lefthook run pre-commit` を走らせ、非 0 で落ちて報告が出る。確かめた後に戻す
  - 当たらない変更（例: `.md` だけ）のコミットで 0 で終わり、かかった時間を記録する
  - 同じファイルに対し、手元の結果と CI と同じ全体の走査（`semgrep scan --config ... --metrics=off --error` をリポジトリの根で）の結果が、そのファイルについて一致する。特に、Semgrep が既定で無視する場所のファイルを明示的に渡したときに、全体の走査で出ない報告が出ないことを確かめる。出る場合は、全体の走査と同じ無視が効く渡し方に直す
- Brakeman
  - `lefthook run pre-push`（または `git push` の dry run に当たる実行）で `brakeman` が走り、いまの土台の中身で 0 で終わる。かかった時間を記録する
  - 当たる一時的な変更（例: コントローラで `params` を `eval` する行）で非 0 で落ちることを確かめ、戻す
- 既存の項目（rubocop・protect-branch・`check-git-clean` 等）の結果が変わらない
- `bin/bundle exec rubocop` 等、lefthook.yml を変えたときに走る既存の確かめが通る

### 受け入れの条件

1. 土台 `ci/add-mutant-report` の上の枝で、`lefthook.yml` の pre-commit に `semgrep`（`{staged_files}`、直さない）、pre-push に `brakeman`（`bin/bundle exec brakeman --no-pager`）がある
2. `Docker/api/Dockerfile` が `python3`・`python3-venv` を apt で明示的に入れている
3. `.lefthook/pre-commit/semgrep.sh` が、`semgrep.txt` を `--require-hashes` で使い、規則の SHA を `ci.yml` から読み、CI と同じ `--config`・`--metrics=off`・`--error` で走らせる。規則をリポジトリにもイメージにも置かない
4. この Dev Container で、Semgrep と Brakeman がフックから実際に走り、当たる変更で落ち、当たらない変更で通る（「確かめ方」の結果を実装の記録に残す）
5. `.github/workflows/ci.yml` の job `brakeman`・`semgrep` は変わっていない
6. tb-eow1n の項目（debride・`check-docs.sh`・試し 2 つ・htmlbeautifier）とルールの文を変えていない
7. スクリプトが使う言語・コマンドはすべて明示的に入れた物で、コメントは英語
8. イメージの作り直しの後に `python3-venv` が入っていることを確かめる check bead が登録されている

### 決めた前提（autonomous で決めたこと）

- Dockerfile の変更はこの依頼の範囲に入るとした。依頼は「手元（Dev Container）でこの 2 つが実際に走ること」を求め、いまの Dev Container には Semgrep を入れる手段（pip・venv）が無く、`scripts-authoring` のルールは明示的に入れた言語だけを使うよう求めるため
- Semgrep に `glob` を付けないとした。ルールは段を速さでなく要る物で決めるとしており、glob を付けると規則の更新に合わせて直す必要が生まれるため。`.md` だけのコミットでも Semgrep の起動の時間はかかる（実装の段で計って記録する）
- Semgrep や venv が用意できないときは、飛ばさずに落とすとした。黙って通すと、確かめていないのに通ったように見えるため

### 未解決の問い

- 人に聞く必要のある問いは無い
- 実装の段で確かめること（設計の判断ではなく事実の確認）
  - `semgrep==1.186.0` とその依存の aarch64 の wheel が `semgrep.txt` の hash に含まれ、この Dev Container の venv に入るか
  - Semgrep に明示的に渡したファイルに、全体の走査と同じ無視（`.semgrepignore`・既定の無視）が効くか
  - `python3-venv` が置く ensurepip の正確なパス（check bead の対象）

### 承認の状態

- 状態: **承認済み**（2026-11-20、承認レーン tb-4adpe、autonomous、`design_review.verdict=done`）。承認の記録: /home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/design-approval.md
- autonomous の承認の根拠: 求める結果（段の割り当て）は人の返事の原文で決まっている。残る選択（Semgrep の入れ方・規則の置き方・glob の有無・失敗の扱い）は、リポジトリのルール（`lefthook-ci-placement`・`scripts-authoring`）、決定記録（固定の仕方と規則の配布の制約）、確かめた事実（Dev Container に pip・venv・docker が無い、Zed で `postCreateCommand` が走らない）から決まる。人の答えを作り出した箇所は無い

