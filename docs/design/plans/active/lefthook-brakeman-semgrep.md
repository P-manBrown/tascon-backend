# lefthook に Brakeman（pre-push）と Semgrep（pre-commit）を入れる 実装計画

Spec: docs/design/specs/lefthook-brakeman-semgrep.md

> **For agentic workers:** この計画は workflow `tb-dq5i9`（superpowers-build）の実装の drain が実行する。`### Task 1`〜`### Task 4` の 4 節がそれぞれ 1 つの実装 bead になり、同じ item branch の上で番号の順に 1 つずつ行う（Task 2 は Task 1 が入れた `python3-venv` に、Task 4 は Task 2・3 の変更に頼る）。worktree・item branch・タスクの手順の枠（文脈の読み込み、確かめ、レビュー、結果の記録）は drain が用意し、各タスクのチェックボックスの手順はその中身になる。`executing-plans` と `verification-before-completion` の skill を指針に使い、provider 固有の subagent は使わない。手順はチェックボックス（`- [ ]`）で追う。

**Goal:** lefthook の pre-commit でステージしたファイルに CI と同じ Semgrep（版・規則・引数）を、pre-push で CI と同じ Brakeman を走らせ、Dev Container で実際に動かして確かめる。

**Architecture:** 承認済みの設計の案 A。`Docker/api/Dockerfile` の既存の apt の行に `python3`・`python3-venv` を足して明示的に入れる。新しい bash スクリプト `.lefthook/pre-commit/semgrep.sh` が、`.github/requirements/semgrep.txt`（`--require-hashes`）から venv を、`ci.yml` の job `semgrep` の `ref:` の SHA から規則 `ruby/rails` を、リポジトリの外のキャッシュ（`${XDG_CACHE_HOME:-$HOME/.cache}/tascon-backend/semgrep/`）に一度だけ用意し、CI と同じ `semgrep scan --config <規則> --metrics=off --error` をリポジトリの根で、ステージしたファイルだけに絞って（`--include "/<path>"`）走らせる。Brakeman は `lefthook.yml` の pre-push に CI と同じ `bin/bundle exec brakeman --no-pager` を足すだけ。CI は変えない。

**Tech Stack:** lefthook 1.13.6、bash、git、Ruby 4.0.0（`ruby -ryaml`、Brakeman `~> 8.1`）、Debian 13 の `python3` 3.13.5 と `python3-venv`、Semgrep 1.186.0（pip、hash 付き requirements）、`semgrep/semgrep-rules` の `ruby/rails`（SHA `a5ad1714f00c9f7fde980cab0ea1d6dc6d414fd2`）、git-spice、gc/bd（check bead）。

---

- Workflow root: `tb-dq5i9`（superpowers-build、autonomous）。依頼: `tb-13xb6`（human-request-part、依頼 gc-wvsr の一部）。この計画を書いた step: `tb-c6fkc`（plan、iteration 1、attempt 1）
- 入力（artifact root `/home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/`）: 承認済みの要件 `requirements.md`（REQ-001〜REQ-009）と承認済みの設計 `design.md`（案 A）
- 土台: `ci/add-mutant-report`（`origin/ci/add-mutant-report` = `54063e2c`）。item branch はその上に作る（想定の名前 `chore/lefthook-brakeman-semgrep`。名前は drain が `git-spice-workflow` の skill で決める）
- Status: `approved`（plan-review tb-oea7x が承認。apply-plan-feedback tb-6odm3 で更新）
- リポジトリの中の写し（`docs/superpowers/plans/` 等）: 置かない。要件と同じく、この計画は artifact root だけに置き、ここが正本

## Context/Purpose

- `Docker/api/Dockerfile` の apt の `RUN` で `python3`・`python3-venv` を明示的に入れる（REQ-003）。イメージを作り直した後に ensurepip（`/usr/lib/python3.13/ensurepip/__init__.py`、`python3.13-venv` のファイル）があることを確かめる check bead を登録する（REQ-009）
- `.lefthook/pre-commit/semgrep.sh` を足し、`lefthook.yml` の pre-commit の `commands:` に `semgrep` を足す（REQ-001・REQ-004・REQ-008）
- `lefthook.yml` の pre-push の `commands:` に `brakeman` を足す（REQ-002）
- 決定記録 `docs/decisions/test-and-check-tool-selection.md` に手元の実行を書き足すかを `decisions-maintenance` のルールに照らして決め、要るなら書き足す（要件の「文書の扱い」）
- Dev Container で実際に走らせ、結果を証拠のファイルと bead のメモに残す（REQ-005）。CI・tb-eow1n の項目・ルールの文は変えない（REQ-006・REQ-007）

計画の段で、捨てる worktree（土台 `54063e2c` を detached で取り出した物、確かめた後に消した）とスクラッチのキャッシュで次を実際に確かめた。結果は「Current System」の P1〜P8 に書く。この Dev Container には計画の段で `sudo apt-get install -y --no-install-recommends python3 python3-venv` を実行済みなので、Task 1 の apt は「既に入っている」になる。本物のキャッシュ `~/.cache/tascon-backend/` はまだ無い。

## Current System

土台 `origin/ci/add-mutant-report`（`54063e2c`）の中身と、この Dev Container（Debian 13、aarch64）で確かめた事実。

- `lefthook.yml`（`min_version: 1.10.0`）
  - pre-commit: `parallel: true`。`commands:` に `rubocop`・`htmlbeautifier`・`debride`・`protect-branch`（この順。`protect-branch` が最後で、その直後に `jobs:`）。`jobs:` に `check-docs.sh`・`check-plan-completion.sh`・`.lefthook/pre-commit/tests/run.sh`（glob `.lefthook/pre-commit/**` 等）・plan-completion のテスト
  - pre-push: `commands:` に `check-git-clean` だけ。その `fail_text` の行がファイルの最後の行
- `.lefthook/pre-commit/` には `check-docs.sh`・`check-plan-completion.sh`・`tests/`（`run.sh` が `tests/test-*.sh` を全部走らせる）。スクリプトは `#!/usr/bin/env bash` と `set -uo pipefail` で始まり、エラーは `echo "ERROR: ..."` で書く
- `Docker/api/Dockerfile`: 最初の `RUN`（apt のキャッシュを mount するヒアドキュメント）の最後の行が `		apt-get install -y --no-install-recommends libvips42`（タブ 2 つ）
- `.github/workflows/ci.yml`
  - job `brakeman`: `ruby:4.0.0` のコンテナで `bundle install` の後に `bin/bundle exec brakeman --no-pager`
  - job `semgrep`: `actions/checkout` で `repository: semgrep/semgrep-rules`・`ref: a5ad1714f00c9f7fde980cab0ea1d6dc6d414fd2`・`sparse-checkout: ruby/rails` を取り出して `$RUNNER_TEMP` へ移し、Python 3.13.18 で `python -m pip install --require-hashes -r .github/requirements/semgrep.txt`、`semgrep scan --config "$RUNNER_TEMP/semgrep-rules/ruby/rails" --metrics=off --error`（リポジトリの根で、対象を渡さない）
- `.semgrepignore` は無い（Semgrep の既定の無視と `.gitignore` だけが効く）
- リポジトリの `nosemgrep` は 7 行（`app/controllers/**` の 3 行、`app/views/devise/mailer/*.html.erb` の 2 行、`config/environments/{development,test}.rb` の 2 行）
- `docs/decisions/test-and-check-tool-selection.md`: `Related Files` は `.github/workflows/ci.yml`・`.github/workflows/codeql.yml`・`.github/dependabot.yml`・`.github/requirements/semgrep.in`・`.github/requirements/semgrep.txt`・`Gemfile`・`spec/spec_helper.rb`。Consequences に「Semgrepの規則は…リポジトリに写さず、CIで取り出して使う」（33 行目）
- ルール: `scripts-authoring`（`.lefthook/**`・`lefthook.yml` に当たる。明示的に入れた言語・コマンドだけ）、`code-comments`（`.lefthook/**` のコメントは英語。実行時のメッセージは対象外）、`decisions-maintenance`（`docs/decisions/**`）。`lefthook-ci-placement` は土台にまだ無い（PR #847）
- 道具: `lefthook` 1.13.6（`/usr/local/bundle/bin/lefthook`。`lefthook run <hook> --commands <name>` で 1 項目だけ走らせられる）。`brakeman` は `/usr/local/bundle/bin/brakeman`。`git rev-parse --local-env-vars` は `GIT_DIR`・`GIT_INDEX_FILE` 等 15 個を出す

計画の段の試し（捨てる worktree とスクラッチの `XDG_CACHE_HOME`）:

- P1: `python3 -m venv` の後に `bin/python -m pip install --require-hashes -r .github/requirements/semgrep.txt` が aarch64 で成功し、`semgrep --version` は `1.186.0`（要件の未解決の問い 1 は解決: wheel は hash に含まれる）
- P2: venv を `mv` で動かすと `bin/semgrep` が `bad interpreter`（shebang に作った場所の絶対パスが入る）で動かない。設計の「一時ディレクトリで作って `mv` で置く」は venv には使えない → Task 2 は venv を最後の場所の隣の一意の名前のディレクトリで作り、`ln -s` の symlink で公開する（D1）
- P3: 規則は `git init` → `sparse-checkout set ruby/rails` → `fetch --depth 1 --filter=blob:none origin <SHA>` → `checkout FETCH_HEAD` で取り出せ、`ruby/rails` の下の `.yaml` は 53 個。規則のディレクトリは中に絶対パスを持たないので `mv -T` で置ける
- P4: Semgrep に対象として明示的に渡したファイルには既定の無視が効かない。規則に当たる `.erb` を `vendor/`・`test/`・`tmp/`・`node_modules/` に置いて渡すと、どれも 1 件出る。全体の走査ではどれも出ない（要件の未解決の問い 2 は「効かない」）→ REQ-004 の最後の項のとおり渡し方を変える（D2）
- P5: 対象を渡さずリポジトリの根で走らせ、`--include "/<path>"`（先頭の `/` で根に固定）を足すと、全体の走査と同じ無視が効いた上でそのファイルだけを見る。`app/views/probe_hit.html.erb` → 1 件・終了 1、`vendor/`・`test/`・`tmp/` の同じ中身 → 0 件・終了 0、`/README.md` → 0 件・終了 0、固定しない `probe_hit.html.erb` → 別の場所の同じ名前も拾う。どれも約 3 秒
- P6: 下の Task 2 のスクリプトをスクラッチのキャッシュで走らせた。初回（規則の取り出しと Semgrep の導入）164 秒・終了 0、2 回目 3 秒（導入の表示なし）、`README.md` だけ 3 秒・終了 0、当たる `.erb` で `Ran 10 rules on 1 file: 1 finding.`・終了 1、`vendor/` の同じ中身で終了 0。キャッシュには `rules-<SHA>`、`venv-<鍵16桁>`（symlink）、`venv-<鍵16桁>.XXXXXX`（実体）だけが残った
- P7: 下の Task 2・3 の `lefthook.yml` の項目を足した捨てる worktree で、`lefthook run pre-commit --commands semgrep` が当たる `.erb` をステージして終了 1（`🥊 semgrep: Read the report above.`）、`README.md` だけで終了 0（3.05 秒）。`lefthook run pre-push --commands brakeman` が終了 0（1.28 秒）
- P8: Brakeman は土台の中身で `No warnings found`・終了 0（約 1〜2 秒）。`app/controllers/api/v1/users_controller.rb` の `def show` の直後に `eval(params[:code])` を足すと `Dangerous Eval`（Confidence High）で終了 3
- ensurepip のパス: `dpkg -S /usr/lib/python3.13/ensurepip/__init__.py` は `python3.13-venv`（要件の未解決の問い 3 は解決）。`python3-venv`（3.13.5-1）は `python3.13-venv`（3.13.5-2+deb13u5）に頼る

## Proposed Implementation

### 決めたこと（plan-review で見てほしい点）

- **D1（設計からのずれ）**: venv は `mv` で置かず、`mktemp -d "<cache>/venv-<鍵>.XXXXXX"` で一意のディレクトリに作り、出来上がってから相対の symlink `venv-<鍵>` → `venv-<鍵>.XXXXXX` を `ln -s` で作って公開する。P2 のとおり venv は動かすと壊れるため。`ln -s` は置き場所に既に何かあれば失敗するので、要件の「失敗し、置き場所に既に出来上がった物があるときは、作った物を捨てて置かれた物を使う」はそのまま守れる。規則は要件のとおり一時ディレクトリから `mv -T` で置く（`-T` が無いと、置き場所が既にあるときにその中へ動いてしまう）
- **D2（要件 REQ-004 の最後の項の適用）**: P4 のとおり、ファイルを対象として渡すと既定の無視が効かない。要件は「効かないことが分かったときは、全体の走査と同じ無視が効く渡し方にスクリプトを直す」と決めているので、走らせ方を `semgrep scan --config <rules>/ruby/rails --metrics=off --error --include "/<file>" ...`（対象を渡さず、リポジトリの根で）にする。要件の書いた `-- "$@"` の形は使わない。CI のコマンドに `--include` を足しただけの形になる
- **D3**: venv の鍵は `semgrep.txt` の sha256 と `python3` の `X.Y.Z` を空白でつないだ文字列の sha256 の先頭 16 桁
- **D4**: Semgrep の導入と規則の取り出しの出力は、成功したときは見せない（ログを一時ファイルに取り、失敗したときだけ標準エラー出力に出す）。何をしているかは 1 行（`Fetching the Semgrep rules at <SHA> ...`・`Installing Semgrep from ... ...`）だけ標準エラー出力に出す
- **D5**: 規則を取り出す git は、`git rev-parse --local-env-vars` の変数を消した subshell で走らせる。フックの中では git が `GIT_INDEX_FILE` 等を渡すので、消さないとコミット中の index を別のリポジトリの操作に使ってしまう
- **D6**: 決定記録は書き足すことを推す（Task 4）。`decisions-maintenance` は `Related Files` を「この決定に対応する実装ファイル」とし、決定の固定の仕方（hash 付き requirements と規則の SHA）を手元で実装するのは `semgrep.sh` になるため。また 33 行目の「CIで取り出して使う」は、この変更の後は手元のフックも取り出すので事実と合わなくなる。最終の判断は Task 4 の手順でルールを読んで下し、記録する

### ファイルの構成

- Modify: `Docker/api/Dockerfile`（最初の `RUN` の `apt-get install` の行だけ）— Task 1
- Create: `.lefthook/pre-commit/semgrep.sh` — Task 2。1 つの責務（渡されたファイルに CI と同じ Semgrep を走らせる。そのための venv と規則の用意を含む）
- Modify: `lefthook.yml`（pre-commit の `commands:` の最後に `semgrep`）— Task 2
- Modify: `lefthook.yml`（pre-push の `commands:` の最後に `brakeman`）— Task 3
- Modify（Task 4 で要ると決めたときだけ）: `docs/decisions/test-and-check-tool-selection.md`
- 変えない: `.github/workflows/ci.yml`、`.github/requirements/*`、`.claude/rules/**`、`lefthook.yml` の既存の項目（debride・htmlbeautifier・`check-docs.sh`・試し 2 つ等）、`.lefthook/pre-commit/` の既存のファイル
- 自動のテストは足さない（要件の「テストの期待」）。各タスクは実際の実行で確かめる

### 全タスクに共通の決まり

- 作業は drain が用意した worktree（`$WORK_DIR`、source anchor の `work_dir`）と item branch（`$ITEM_BRANCH`、source anchor の `gc.git_branch`）で行う。main のチェックアウトでは作業しない・ブランチを切り替えない。ほかの worker の worktree を読まない
- コミットは repository の `git-spice-workflow` skill の手順（type の決め方・メッセージの言語）で、`git-spice commit create` を使う。`--no-verify` は使わない（フックの出力が確かめの一部）
- 証拠は `EV=/home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/evidence` に `task<N>-<name>.txt` として残す（worktree は drain の後で消えるため）。各タスクの最後に、要点（コマンド、終了コード、かかった時間、出力の要点）を自分の bead に `bd update <bead> --append-notes` で書く
- 一時的に足した変更（規則に当たるファイル、`eval` の行）は確かめた直後に戻し、`git status --porcelain` が空であることを確かめてから次へ進む
- 秘密の値をメモ・証拠・コマンドの引数に書かない（この作業では使わない）

### Task 1: Dev Container のイメージに python3 と python3-venv を入れ、check bead を登録する

対応: REQ-003、REQ-009、REQ-008（Dockerfile の部分）

**Files:**
- Modify: `Docker/api/Dockerfile`（最初の `RUN` の最後の行）

- [ ] **Step 1: 土台と作業場所を確かめる**

```bash
cd "$WORK_DIR"
EV=/home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/evidence
mkdir -p "$EV"
{
  git branch --show-current
  git merge-base --is-ancestor origin/ci/add-mutant-report HEAD && echo "base is an ancestor"
  git status --porcelain
  grep -n 'apt-get install' Docker/api/Dockerfile
} | tee "$EV/task1-start.txt"
```

Expected: 枝の名前が `$ITEM_BRANCH`、`base is an ancestor`、`git status` は空、`grep` は `		apt-get install -y --no-install-recommends libvips42` の 1 行だけ。

- [ ] **Step 2: apt の行に `python3`・`python3-venv` を足す**

`Docker/api/Dockerfile` の次の行（先頭はタブ 2 つ。そのまま残す）:

```dockerfile
		apt-get install -y --no-install-recommends libvips42
```

を次にする。新しい `RUN` は作らない。

```dockerfile
		apt-get install -y --no-install-recommends libvips42 python3 python3-venv
```

- [ ] **Step 3: 差分を確かめる**

Run: `git diff -- Docker/api/Dockerfile`
Expected: 上の 1 行だけが変わる（行頭のタブが残っている。`git diff | cat -A | grep '^+'` で `^I^Iapt-get` になっている）

- [ ] **Step 4: この Dev Container を Dockerfile と同じ状態にして確かめる**

イメージのビルドはこの Dev Container の中で試せない（docker が無い）。代わりに同じ apt を実行する。計画の段で実行済みなので「already the newest version」になるのが正しい。

```bash
{
  sudo apt-get install -y --no-install-recommends python3 python3-venv
  dpkg -l python3 python3-venv python3.13-venv | tail -3
  dpkg -S /usr/lib/python3.13/ensurepip/__init__.py
  tmp=$(mktemp -d) && python3 -m venv "$tmp/v" && "$tmp/v/bin/python" -m pip --version; echo "venv rc=$?"; rm -rf "$tmp"
} 2>&1 | tee "$EV/task1-apt.txt"
```

Expected: 3 つの包みが `ii`、`dpkg -S` が `python3.13-venv: /usr/lib/python3.13/ensurepip/__init__.py`、`pip ... (python 3.13)` と `venv rc=0`。`dpkg -S` が別のパスや別の包みを示したら、そのパス（`python3.13-venv` の物で `/` で始まる）を Step 5 で使い、メモに書く。

- [ ] **Step 5: check bead を登録する（REQ-009）**

先に同じ物が無いかを確かめる（タスクのやり直しで二重に作らない）:

```bash
gc bd list -l check-later --json | python3 -c '
import json, sys
for b in json.load(sys.stdin):
    if "ensurepip" in json.dumps(b.get("metadata") or {}):
        print(b["id"], b["title"])
'
```

何も出なければ登録する:

```bash
gc bd create "Dev Container のイメージを作り直した後に python3-venv（ensurepip）が入っているかを確かめる" \
  -t task -l check-later \
  --metadata '{"gc.check.scope":"tascon-backend","gc.check.kind":"path_exists","gc.check.args":"{\"path\": \"/usr/lib/python3.13/ensurepip/__init__.py\"}","gc.check.mode":"must_hold"}' \
  -d "lefthook の pre-commit の semgrep（.lefthook/pre-commit/semgrep.sh）は python3 -m venv で Semgrep を入れるため、Docker/api/Dockerfile の apt の行で python3 と python3-venv を入れている。この Dev Container の中ではイメージをビルドできず、今の状態は手で apt-get install したものなので、作り直した後に本当に入っているかを確かめる。落ちたとき: Docker/api/Dockerfile の最初の RUN の apt-get install の行に python3 と python3-venv があるかを確かめる。行があるのに落ちるなら、Debian の Python の版が上がって ensurepip のパス（/usr/lib/python3.<minor>/ensurepip/__init__.py）が変わっていないかを dpkg -L python3-venv で確かめ、この bead の path を直す。通ったとき: 対応は要らない。"
```

Expected: 新しい bead の ID が出る。続けて確かめる:

```bash
gc bd list -l check-later --json | python3 -c '
import json, sys
for b in json.load(sys.stdin):
    m = b.get("metadata") or {}
    if "ensurepip" in json.dumps(m):
        print(b["id"], m.get("gc.check.kind"), m.get("gc.check.mode"), m.get("gc.check.scope"), m.get("gc.check.args"))
' | tee "$EV/task1-check-bead.txt"
```

Expected: `<id> path_exists must_hold tascon-backend {"path": "/usr/lib/python3.13/ensurepip/__init__.py"}` の 1 行。

- [ ] **Step 6: コミットする**

```bash
git add Docker/api/Dockerfile
git-spice commit create -m "build: install python3 and python3-venv in the api image"
```

メッセージの type と言語は `git-spice-workflow` の skill に従って直してよい。Expected: pre-commit のフックが通り（`protect-branch` 等）、コミットが 1 つ増える。`git status --porcelain` が空。

- [ ] **Step 7: bead にメモを書く**

`bd update <この bead> --append-notes '...'` に、Dockerfile の差分の 1 行、Step 4 の結果、check bead の ID と metadata、コミットの SHA を書く。

**受け入れの条件:**
- `Docker/api/Dockerfile` の最初の `RUN` の `apt-get install` の行が `libvips42 python3 python3-venv` を入れ、ほかの行は土台と同じ（REQ-003）
- この Dev Container で `python3 -m venv` が pip 付きの venv を作れる（REQ-003）
- `path_exists`・`must_hold`・scope `tascon-backend`・ensurepip の絶対パスの check bead が 1 つだけある（REQ-009）

### Task 2: pre-commit で Semgrep を走らせる

対応: REQ-001、REQ-004、REQ-005（Semgrep の部分）、REQ-008（スクリプトの部分）。Task 1 の後に行う

**Files:**
- Create: `.lefthook/pre-commit/semgrep.sh`
- Modify: `lefthook.yml`（pre-commit の `commands:` の `protect-branch` の後）

- [ ] **Step 1: 足す前の状態を記録する**

```bash
cd "$WORK_DIR"
{
  lefthook run pre-commit --commands semgrep; echo "rc=$?"
  ls "${XDG_CACHE_HOME:-$HOME/.cache}/tascon-backend/semgrep" 2>&1
} 2>&1 | tee "$EV/task2-before.txt"
```

Expected: `semgrep` という項目が無いので何も走らない。キャッシュは `No such file or directory`（あっても先へ進む。下の確かめは一時の `XDG_CACHE_HOME` を使う）。

- [ ] **Step 2: スクリプトを書く**

`.lefthook/pre-commit/semgrep.sh` を次の中身で作る（計画の段で P6・P7 のとおり動いた物と同じ）。コメントは英語、メッセージは英語。

```bash
#!/usr/bin/env bash
# Run Semgrep on the given files with the same Semgrep version, rules and
# arguments as the CI job `semgrep`.
#
# Usage: bash .lefthook/pre-commit/semgrep.sh FILE...
#
# Semgrep comes from .github/requirements/semgrep.txt (--require-hashes) and
# the rules from the semgrep/semgrep-rules commit pinned in
# .github/workflows/ci.yml. Both are cached outside the repository.
set -uo pipefail

[ "$#" -gt 0 ] || exit 0

die() {
  echo "ERROR: $*" >&2
  exit 1
}

repo_root=$(git rev-parse --show-toplevel) || die "Run this script inside the repository."
cd "$repo_root" || die "Cannot change to $repo_root."

requirements=.github/requirements/semgrep.txt
workflow=.github/workflows/ci.yml
rules_url=https://github.com/semgrep/semgrep-rules
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tascon-backend/semgrep"

[ -f "$requirements" ] || die "$requirements is missing."

rules_sha=$(ruby -ryaml -e '
  steps = YAML.safe_load_file(ARGV[0]).dig("jobs", "semgrep", "steps") || []
  step = steps.find { |s| s.is_a?(Hash) && s.dig("with", "repository") == "semgrep/semgrep-rules" }
  puts step&.dig("with", "ref")
' "$workflow") || die "Could not read $workflow."
[[ "$rules_sha" =~ ^[0-9a-f]{40}$ ]] ||
  die "jobs.semgrep in $workflow must check out semgrep/semgrep-rules at a 40-character commit SHA, got '$rules_sha'."

mkdir -p "$cache_dir" || die "Cannot create $cache_dir."

work_dir=""
cleanup() {
  [ -n "$work_dir" ] && rm -rf "$work_dir"
}
trap cleanup EXIT

# Run git for the rules checkout without the variables that git sets for this
# repository's hooks (GIT_INDEX_FILE and others).
rules_git() {
  (
    # shellcheck disable=SC2046
    unset $(git rev-parse --local-env-vars)
    git -C "$work_dir" "$@"
  )
}

rules_dir="$cache_dir/rules-$rules_sha"
if [ ! -d "$rules_dir/ruby/rails" ]; then
  echo "Fetching the Semgrep rules at $rules_sha ..." >&2
  work_dir=$(mktemp -d "$cache_dir/rules-$rules_sha.tmp.XXXXXX") || die "Cannot create a temporary directory in $cache_dir."
  log="$work_dir.log"
  if ! {
    rules_git init -q &&
      rules_git remote add origin "$rules_url" &&
      rules_git sparse-checkout set ruby/rails &&
      rules_git fetch -q --depth 1 --filter=blob:none origin "$rules_sha" &&
      rules_git checkout -q FETCH_HEAD
  } >"$log" 2>&1; then
    cat "$log" >&2
    rm -f "$log"
    die "Could not fetch the Semgrep rules from $rules_url at $rules_sha. Check the network and commit again."
  fi
  rm -f "$log"
  # mv -T fails instead of moving into the directory when another run placed it first.
  if mv -T "$work_dir" "$rules_dir" 2>/dev/null; then
    work_dir=""
  elif [ -d "$rules_dir/ruby/rails" ]; then
    rm -rf "$work_dir"
    work_dir=""
  else
    die "Could not place the Semgrep rules at $rules_dir."
  fi
fi

python_version=$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])') ||
  die "python3 is not available. Rebuild the Dev Container."
read -r requirements_sha _ < <(sha256sum "$requirements")
read -r venv_key _ < <(printf '%s %s\n' "$requirements_sha" "$python_version" | sha256sum)
venv_link="$cache_dir/venv-${venv_key:0:16}"

# A venv cannot be moved after it is built, because its scripts hold its
# absolute path. Build it in a unique directory and publish it with a symlink.
if [ ! -x "$venv_link/bin/semgrep" ]; then
  echo "Installing Semgrep from $requirements ..." >&2
  work_dir=$(mktemp -d "$venv_link.XXXXXX") || die "Cannot create a temporary directory in $cache_dir."
  log="$work_dir.log"
  if ! python3 -m venv "$work_dir" >"$log" 2>&1; then
    cat "$log" >&2
    rm -f "$log"
    die "python3 -m venv failed. Rebuild the Dev Container, or run: sudo apt-get install -y python3-venv"
  fi
  if ! "$work_dir/bin/python" -m pip install --disable-pip-version-check --require-hashes -r "$requirements" >"$log" 2>&1; then
    cat "$log" >&2
    rm -f "$log"
    die "Could not install Semgrep from $requirements. Check the network and commit again."
  fi
  rm -f "$log"
  if ln -s "$(basename "$work_dir")" "$venv_link" 2>/dev/null; then
    work_dir=""
  elif [ -x "$venv_link/bin/semgrep" ]; then
    rm -rf "$work_dir"
    work_dir=""
  else
    die "Could not place the Semgrep venv at $venv_link."
  fi
fi

# Scan the repository root like CI and limit the scan to the given files with
# anchored --include patterns. Semgrep skips its default ignores for files given
# as targets, so passing the files as targets would report more than CI.
includes=()
for file in "$@"; do
  includes+=(--include "/$file")
done

"$venv_link/bin/semgrep" scan --config "$rules_dir/ruby/rails" --metrics=off --error "${includes[@]}"
```

スクリプトが使う物（REQ-008 の確かめに使う）: bash の組み込み、`git`（ruby の公式イメージに入っている）、`ruby`（ベースイメージ）、`python3`・`python3 -m venv`（Task 1 の Dockerfile）、`sha256sum`・`mktemp`・`mv`・`ln`・`rm`・`mkdir`・`cat`・`basename`（ベースイメージの coreutils）。`git -C`・`sparse-checkout` は git の機能。

- [ ] **Step 3: lefthook.yml の pre-commit に項目を足す**

`lefthook.yml` の次の 3 行（pre-commit の `protect-branch`）:

```yaml
    protect-branch:
      run: git branch --show-current | tee /dev/tty | grep -Eqvx 'main'
      fail_text: "ERROR: Do NOT commit directly to 'main' branch."
```

の直後、`  jobs:` の前に次を足す。`glob`・`stage_fixed` は付けない。

```yaml
    semgrep:
      run: bash .lefthook/pre-commit/semgrep.sh {staged_files}
      fail_text: 'Read the report above.'
```

Run: `git diff -- lefthook.yml`
Expected: 上の 3 行の追加だけ（P7 の差分の前半と同じ）。

- [ ] **Step 4: 初回と 2 回目（キャッシュ）を確かめる**

一時のキャッシュを使い、空の状態から始める:

```bash
export SG_XDG=$(mktemp -d)
{
  s=$SECONDS; XDG_CACHE_HOME="$SG_XDG" bash .lefthook/pre-commit/semgrep.sh app/controllers/application_controller.rb; echo "cold rc=$? $((SECONDS-s))s"
  ls -la "$SG_XDG/tascon-backend/semgrep"
  s=$SECONDS; XDG_CACHE_HOME="$SG_XDG" bash .lefthook/pre-commit/semgrep.sh app/controllers/application_controller.rb; echo "warm rc=$? $((SECONDS-s))s"
} 2>&1 | tee "$EV/task2-cache.txt"
grep -c -E 'Fetching|Installing' "$EV/task2-cache.txt"
```

Expected: 初回は `Fetching the Semgrep rules at a5ad1714… ...` と `Installing Semgrep from ... ...` の後に `Ran … rules on 1 file: 0 findings.` と `cold rc=0`（計画の段で 164 秒）。キャッシュには `rules-a5ad1714f00c9f7fde980cab0ea1d6dc6d414fd2`、`venv-<16桁>`（symlink）、`venv-<16桁>.XXXXXX` だけがあり、`*.tmp.*`・`*.log` は無い。2 回目は導入の行が無く `warm rc=0`（約 3 秒）。`grep -c` は `2`（初回の 2 行だけ）。

- [ ] **Step 5: 失敗の扱いを確かめる**

(a) venv が作れないとき。`-m venv` だけを失敗させる偽の `python3` を一時の場所に置く:

```bash
stub=$(mktemp -d)
cat >"$stub/python3" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-m" ] && [ "${2:-}" = "venv" ]; then
  echo "The virtual environment was not created successfully because ensurepip is not available." >&2
  exit 1
fi
exec /usr/bin/python3 "$@"
EOF
chmod +x "$stub/python3"
x=$(mktemp -d)
{ PATH="$stub:$PATH" XDG_CACHE_HOME="$x" bash .lefthook/pre-commit/semgrep.sh README.md; echo "rc=$?"; ls "$x/tascon-backend/semgrep"; } 2>&1 | tee "$EV/task2-fail-venv.txt"
rm -rf "$stub" "$x"
```

Expected: `ensurepip is not available` と `ERROR: python3 -m venv failed. Rebuild the Dev Container, or run: sudo apt-get install -y python3-venv`、`rc=1`。キャッシュには `rules-<SHA>` だけがあり、`venv-*` は無い（作りかけを消した）。

(b) 取り出しができないとき（ネットワークを、届かない proxy で塞ぐ）:

```bash
x=$(mktemp -d)
{ https_proxy=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9 XDG_CACHE_HOME="$x" bash .lefthook/pre-commit/semgrep.sh README.md; echo "rc=$?"; ls -A "$x/tascon-backend/semgrep"; } 2>&1 | tee "$EV/task2-fail-fetch.txt"
rm -rf "$x"
```

Expected: git の失敗の出力（proxy に繋がらない旨）と `ERROR: Could not fetch the Semgrep rules from https://github.com/semgrep/semgrep-rules at a5ad1714…. Check the network and commit again.`、`rc=1`。`ls -A` は空（一時ディレクトリとログが残っていない）。proxy の変数が効かず取り出しが成功したときは、(b) を飛ばした理由をメモに書く（この Dev Container の proxy の設定による。スクリプトは変えない）。

(c) 規則の SHA が読めないとき:

```bash
x=$(mktemp -d)
sed -i 's/ref: a5ad1714f00c9f7fde980cab0ea1d6dc6d414fd2/ref: main/' .github/workflows/ci.yml
{ XDG_CACHE_HOME="$x" bash .lefthook/pre-commit/semgrep.sh README.md; echo "rc=$?"; ls -A "$x/tascon-backend/semgrep" 2>&1; } 2>&1 | tee "$EV/task2-fail-sha.txt"
git checkout -q -- .github/workflows/ci.yml
git diff --quiet -- .github/workflows/ci.yml && echo "ci.yml restored"
rm -rf "$x"
```

Expected: `ERROR: jobs.semgrep in .github/workflows/ci.yml must check out semgrep/semgrep-rules at a 40-character commit SHA, got 'main'.`、`rc=1`、`ls -A` は `No such file or directory`（SHA を確かめる前にはキャッシュを作らない）、`ci.yml restored`。

- [ ] **Step 6: 2 つの初回が同時に走ったときを確かめる**

```bash
x=$(mktemp -d)
{
  XDG_CACHE_HOME="$x" bash .lefthook/pre-commit/semgrep.sh README.md >/dev/null 2>"$EV/task2-race-a.err" & a=$!
  XDG_CACHE_HOME="$x" bash .lefthook/pre-commit/semgrep.sh README.md >/dev/null 2>"$EV/task2-race-b.err" & b=$!
  wait $a; echo "a rc=$?"; wait $b; echo "b rc=$?"
  ls -la "$x/tascon-backend/semgrep"
} 2>&1 | tee "$EV/task2-race.txt"
rm -rf "$x"
```

Expected: `a rc=0`・`b rc=0`。キャッシュには `rules-<SHA>` が 1 つ、`venv-<16桁>` の symlink が 1 つ、その実体が 1 つだけあり、`*.tmp.*`・`*.log`・負けた方の実体は無い。

- [ ] **Step 7: フックから、当たる変更と当たらない変更を確かめる**

本物のキャッシュ（`~/.cache/tascon-backend/semgrep`）を温めるため、ここからは `XDG_CACHE_HOME` を付けない（初回は Step 4 と同じくらいかかる）。

当たる変更（devise のメールの `nosemgrep` を外した写し）:

```bash
grep -v nosemgrep app/views/devise/mailer/confirmation_instructions.html.erb > app/views/semgrep_probe.html.erb
git add app/views/semgrep_probe.html.erb
{ lefthook run pre-commit --commands semgrep; echo "hit rc=$?"; } 2>&1 | tee "$EV/task2-hook-hit.txt"
git reset -q app/views/semgrep_probe.html.erb && rm app/views/semgrep_probe.html.erb
git status --porcelain
```

Expected: Semgrep の報告に `ruby.rails.security.audit.xss.templates.dangerous-link-to` と `1 finding`、lefthook の `🥊 semgrep: Read the report above.`、`hit rc=1`。最後の `git status` は空。

当たらない変更（`.md` だけ）:

```bash
echo "semgrep probe" >> README.md
git add README.md
{ s=$SECONDS; lefthook run pre-commit --commands semgrep; echo "md rc=$? $((SECONDS-s))s"; } 2>&1 | tee "$EV/task2-hook-md.txt"
git reset -q README.md && git checkout -q -- README.md
git status --porcelain
```

Expected: `✔️ semgrep (… seconds)`、`md rc=0`、かかった時間（計画の段で約 3 秒）。最後の `git status` は空。

- [ ] **Step 8: CI と同じ全体の走査と突き合わせる**

同じ中身を、走査に入る場所（`app/views/`）と既定で無視される場所（`vendor/`、`test/`）に置き、全体の走査（CI と同じコマンド、リポジトリの根）とスクリプトの結果を比べる。

```bash
SG="$HOME/.cache/tascon-backend/semgrep"
SEMGREP=$(find "$SG" -maxdepth 1 -type l -name 'venv-*' | head -1)/bin/semgrep
RULES=$(find "$SG" -maxdepth 1 -type d -name 'rules-*' ! -name '*.tmp.*' | head -1)/ruby/rails
mkdir -p test
for f in app/views/semgrep_probe.html.erb vendor/semgrep_probe.html.erb test/semgrep_probe.html.erb; do
  grep -v nosemgrep app/views/devise/mailer/confirmation_instructions.html.erb > "$f"
done
{
  echo "== full scan (CI)"
  "$SEMGREP" scan --config "$RULES" --metrics=off --error --json -q 2>/dev/null |
    python3 -c 'import json,sys; print(sorted({r["path"] for r in json.load(sys.stdin)["results"]}))'
  for f in app/views/semgrep_probe.html.erb vendor/semgrep_probe.html.erb test/semgrep_probe.html.erb app/controllers/application_controller.rb; do
    bash .lefthook/pre-commit/semgrep.sh "$f" >/dev/null 2>&1; echo "script $f rc=$?"
  done
} 2>&1 | tee "$EV/task2-compare.txt"
rm -f app/views/semgrep_probe.html.erb vendor/semgrep_probe.html.erb test/semgrep_probe.html.erb
rmdir test
git status --porcelain
```

`SEMGREP` は symlink の `venv-<16桁>` の `bin/semgrep`、`RULES` は Step 7 で温めた規則。`echo "$SEMGREP" "$RULES"` が空のパスを示すときは `ls -la "$SG"` を見てパスを直接書く。

Expected: 全体の走査は `['app/views/semgrep_probe.html.erb']` だけ（`nosemgrep` の付いた既存の 7 行は出ない）。スクリプトは `app/views/…` が `rc=1`、`vendor/…`・`test/…`・`application_controller.rb` が `rc=0`。つまり、どのファイルについても「全体の走査で報告がある ⇔ スクリプトが 1」になる。最後の `git status` は空。合わないときは、走らせ方を直さずに止め、bead を blocked にして差を書く（P5 と違う挙動のため、要件の判断が要る）。

- [ ] **Step 9: 既存の項目が変わらないことを確かめてコミットする**

```bash
git add .lefthook/pre-commit/semgrep.sh lefthook.yml
git-spice commit create -m "chore: run semgrep on staged files in pre-commit" 2>&1 | tee "$EV/task2-commit.txt"
git status --porcelain
```

メッセージの type と言語は `git-spice-workflow` の skill に従って直してよい。Expected: フックの出力で、`semgrep`（`semgrep.sh` と `lefthook.yml` に当たる規則は無いので通る）、`protect-branch`、`.lefthook/pre-commit/**` の glob に当たる `tests/run.sh`（`0 test file(s) failed`）、`check-plan-completion.sh` が通り、`rubocop`・`htmlbeautifier`・`debride`・`check-docs.sh` は glob に当たらず飛ばされる。コミットが 1 つ増え、`git status` が空。

- [ ] **Step 10: bead にメモを書く**

Step 4〜9 のコマンド、終了コード、かかった時間、出力の要点、コミットの SHA を `--append-notes` で書く。D1・D2 を実装に使ったことも書く。

**受け入れの条件:**
- `lefthook.yml` の pre-commit に `semgrep`（`bash .lefthook/pre-commit/semgrep.sh {staged_files}`、`fail_text: 'Read the report above.'`）があり、`glob`・`stage_fixed`・`--autofix` が無い（REQ-001）
- `semgrep.sh` が `semgrep.txt` を `--require-hashes` で使い、規則の SHA を `ci.yml` から読み、リポジトリの外のキャッシュに置き、CI と同じ `--config`・`--metrics=off`・`--error` で走らせ、用意できないときは理由と直し方を出して非 0 で終わる（REQ-004）
- Step 4〜8 の結果がすべて Expected のとおりで、証拠が `$EV` にある（REQ-005 の Semgrep の部分）
- スクリプトは明示的に入れた言語・コマンドだけを使い、コメントが英語（REQ-008）

### Task 3: pre-push で Brakeman を走らせる

対応: REQ-002、REQ-005（Brakeman の部分）

**Files:**
- Modify: `lefthook.yml`（pre-push の `commands:` の `check-git-clean` の後。ファイルの最後）

- [ ] **Step 1: 足す前の状態を記録する**

```bash
cd "$WORK_DIR"
{ s=$SECONDS; bin/bundle exec brakeman --no-pager -q; echo "brakeman rc=$? $((SECONDS-s))s"; } 2>&1 | tail -5 | tee "$EV/task3-before.txt"
```

Expected: `No warnings found`、`brakeman rc=0`（計画の段で 1〜2 秒）。

- [ ] **Step 2: lefthook.yml の pre-push に項目を足す**

`lefthook.yml` の最後の 3 行:

```yaml
    check-git-clean:
      run: test -z "$(git status --porcelain | tee /dev/tty)"
      fail_text: 'ERROR: Commit or stash changes before pushing.'
```

の後に次を足す。`glob` は付けない。

```yaml
    brakeman:
      run: bin/bundle exec brakeman --no-pager
      fail_text: 'Read the report above.'
```

Run: `git diff -- lefthook.yml`
Expected: 上の 3 行の追加だけ。

- [ ] **Step 3: 土台の中身で通ることを確かめる**

```bash
{ s=$SECONDS; lefthook run pre-push --commands brakeman; echo "clean rc=$? $((SECONDS-s))s"; } 2>&1 | tee "$EV/task3-clean.txt"
```

Expected: `✔️ brakeman (… seconds)`、`clean rc=0`、かかった時間（計画の段で 1.28 秒）。`--commands brakeman` なので `check-git-clean` は走らない（作業ツリーに `lefthook.yml` の変更があっても構わない）。

- [ ] **Step 4: 当たる変更で落ちることを確かめる**

`app/controllers/api/v1/users_controller.rb` の `      def show` の行の直後に一時的に `        eval(params[:code])` を足す:

```bash
sed -i '/^      def show$/a\        eval(params[:code])' app/controllers/api/v1/users_controller.rb
sed -n '4,6p' app/controllers/api/v1/users_controller.rb
{ lefthook run pre-push --commands brakeman; echo "eval rc=$?"; } 2>&1 | tee "$EV/task3-eval.txt"
git checkout -q -- app/controllers/api/v1/users_controller.rb
git status --porcelain
```

Expected: `sed -n` が `def show` の次に `eval(params[:code])` を示す。報告に `Dangerous Eval`・`Parameter value evaluated as code`、lefthook の `🥊 brakeman: Read the report above.`、`eval rc=1`。`git status` は `M lefthook.yml` だけ（コントローラは戻っている）。

- [ ] **Step 5: コミットする**

```bash
git add lefthook.yml
git-spice commit create -m "chore: run brakeman in pre-push" 2>&1 | tee "$EV/task3-commit.txt"
git status --porcelain
{ lefthook run pre-push; echo "pre-push rc=$?"; } 2>&1 | tee "$EV/task3-pre-push.txt"
```

メッセージの type と言語は `git-spice-workflow` の skill に従って直してよい。Expected: コミットが通り（`semgrep` は `lefthook.yml` で何も見つけない）、`git status` が空。`lefthook run pre-push` は `check-git-clean` と `brakeman` の両方が `✔️` で `pre-push rc=0`。

- [ ] **Step 6: bead にメモを書く**

Step 1〜5 のコマンド、終了コード、かかった時間、出力の要点、コミットの SHA を `--append-notes` で書く。

**受け入れの条件:**
- `lefthook.yml` の pre-push に `brakeman`（`bin/bundle exec brakeman --no-pager`、`fail_text: 'Read the report above.'`）があり、`glob` が無い（REQ-002）
- 土台の中身で通り、`params` を `eval` する変更で非 0 で落ち、時間と結果が `$EV` にある（REQ-005 の Brakeman の部分）

### Task 4: 決定記録を合わせ、範囲の外を変えていないことを確かめる

対応: 要件の「文書の扱い」、REQ-006、REQ-007、REQ-005（既存の項目）。Task 2・3 の後に行う

**Files:**
- Modify（Step 2 で要ると決めたときだけ）: `docs/decisions/test-and-check-tool-selection.md`

- [ ] **Step 1: ルールと決定記録を読む**

`.claude/rules/decisions-maintenance.md` の全文と、`docs/decisions/test-and-check-tool-selection.md` の全文を読む（`Related Files` の行と Consequences の 33 行目「Semgrepの規則は…リポジトリに写さず、CIで取り出して使う」）。

- [ ] **Step 2: 書き足すかを決める**

ルールの `Related Files` の定義（「この決定に対応する実装ファイル」「`Verification Status` の検証時に照合する実装ファイル」）に照らす。計画の推し（D6）は書き足すこと。決めた結果と理由を bead のメモに書く。

- [ ] **Step 3: 書き足す（Step 2 で書き足すと決めたときだけ）**

`Related Files` の行の最後に `` , `lefthook.yml`, `.lefthook/pre-commit/semgrep.sh` `` を足す。つまり次の行:

```markdown
- **Related Files:** `.github/workflows/ci.yml`, `.github/workflows/codeql.yml`, `.github/dependabot.yml`, `.github/requirements/semgrep.in`, `.github/requirements/semgrep.txt`, `Gemfile`, `spec/spec_helper.rb`
```

を次にする:

```markdown
- **Related Files:** `.github/workflows/ci.yml`, `.github/workflows/codeql.yml`, `.github/dependabot.yml`, `.github/requirements/semgrep.in`, `.github/requirements/semgrep.txt`, `Gemfile`, `spec/spec_helper.rb`, `lefthook.yml`, `.lefthook/pre-commit/semgrep.sh`
```

Consequences の次の行:

```markdown
- Semgrepの規則は`semgrep/semgrep-rules`のライセンス（Semgrep Rules License v1.0）が規則の配布を許さないと読めるため、リポジトリに写さず、CIで取り出して使う
```

を次にする:

```markdown
- Semgrepの規則は`semgrep/semgrep-rules`のライセンス（Semgrep Rules License v1.0）が規則の配布を許さないと読めるため、リポジトリに写さず、CIで取り出して使う。lefthookのpre-commit（`.lefthook/pre-commit/semgrep.sh`）も、同じ`semgrep.txt`と`ci.yml`の`ref:`のSHAで、Semgrepと規則をリポジトリの外のキャッシュに取り出して使う
```

`Status`・`Verification Status`・`Date` はルールが求めるときだけ変える（求めないなら変えない）。どうしたかをメモに書く。

```bash
git add docs/decisions/test-and-check-tool-selection.md
git-spice commit create -m "docs: record the local semgrep run in the tool selection decision" 2>&1 | tee "$EV/task4-commit.txt"
git status --porcelain
```

Expected: `check-docs.sh` を含むフックが通り、`git status` が空。

- [ ] **Step 4: 範囲の外を変えていないことを確かめる**

```bash
B=origin/ci/add-mutant-report
{
  echo "== changed files"; git diff --name-status "$B" HEAD
  echo "== ci.yml / rules / requirements"; git diff --stat "$B" HEAD -- .github/ .claude/rules/; echo "(empty above = unchanged)"
  echo "== lefthook.yml diff"; git diff "$B" HEAD -- lefthook.yml
  echo "== ancestry"; git merge-base --is-ancestor "$B" HEAD && echo "base is an ancestor"
  echo "== commits"; git log --oneline "$B"..HEAD
} 2>&1 | tee "$EV/task4-scope.txt"
```

Expected:
- `changed files` は `M Docker/api/Dockerfile`、`A .lefthook/pre-commit/semgrep.sh`、`M lefthook.yml`、（Step 3 を行ったときだけ）`M docs/decisions/test-and-check-tool-selection.md` だけ
- `.github/`・`.claude/rules/` の差は空（REQ-006・REQ-007）
- `lefthook.yml` の差は `semgrep` と `brakeman` の 3 行ずつの追加だけで、`rubocop`・`htmlbeautifier`・`debride`・`protect-branch`・`jobs:`（`check-docs.sh`・試し 2 つ）・`check-git-clean` の行は変わらない（REQ-007）
- `base is an ancestor`、コミットは Task 1〜4 の 3〜4 個

- [ ] **Step 5: 既存の項目の結果が変わらないことを確かめる**

`lefthook run pre-commit --all-files` は使わない（`rubocop --autocorrect`・`htmlbeautifier` が関係の無いファイルを書き換える）。Task 1〜4 のコミットのフックの出力（`$EV/task*-commit.txt`）で、既存の項目が通った・glob で飛ばされたことを確かめ、さらに次を走らせる:

```bash
{
  lefthook run pre-push; echo "pre-push rc=$?"
  bin/bundle exec rubocop; echo "rubocop rc=$?"
} 2>&1 | tail -15 | tee "$EV/task4-existing.txt"
git status --porcelain
```

Expected: `check-git-clean`・`brakeman` が `✔️` で `pre-push rc=0`。`rubocop` は `no offenses detected` で `rubocop rc=0`（土台と同じ）。`git status` は空。

- [ ] **Step 6: bead にメモを書く**

Step 2 の判断と理由、Step 4・5 の結果、コミットの SHA を `--append-notes` で書く。

**受け入れの条件:**
- 決定記録を書き足すかを `decisions-maintenance` に照らして決め、その判断が bead のメモに残り、書き足したときは `check-docs.sh` が通っている（文書の扱い）
- `.github/workflows/ci.yml` が土台と同じ（REQ-006）
- tb-eow1n の項目とルールの文が土台と同じで、item branch が `ci/add-mutant-report` の上にある（REQ-007）
- 既存の項目の結果が変わらない（REQ-005 の最後の項）

## Non-Goals

- `.github/workflows/ci.yml`（job `brakeman`・`semgrep` を含む）と `.github/requirements/*` を変えること
- tb-eow1n が受け持つ項目（debride・`check-docs.sh`・pre-commit の確かめの試し 2 つ・htmlbeautifier）を動かすこと。`.claude/rules/` の文を変えること
- push する ref と作業ツリーの中身の違いを埋めること。一部だけステージしたファイルの扱いを変えること（rubocop と同じく lefthook の挙動に任せる。Semgrep は作業ツリーの中身を見る）
- Zed で `postCreateCommand` が走らない問題を直すこと。Semgrep の規則の SHA の置き場所を動かすこと
- Semgrep・Brakeman の報告を lefthook で直すこと（`--autofix`・`stage_fixed`）
- 新しい決定記録を書くこと。自動のテストを足すこと
- キャッシュの古い版（`semgrep.txt` や SHA を上げた後に残る `venv-*`・`rules-*`）を消す仕組み（R2）
- superpowers-build の lifecycle の段（plan-review、decompose、実装の drain の worktree と item branch の用意と片付け、summarize-implementation、review、finalize、publish）。これらは formula の段で、実装のタスクではない（「Handoff」）

## Validation and Acceptance

各タスクの手順の中で確かめ、出力を `$EV`（`/home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/evidence/`）に残す。後の段は、item branch を取り出さずに、main のチェックアウトから `git diff origin/ci/add-mutant-report "$ITEM_BRANCH"` 等で git の確かめを繰り返せる。

1. **Dockerfile（REQ-003）**: `git diff origin/ci/add-mutant-report "$ITEM_BRANCH" -- Docker/api/Dockerfile` が apt の 1 行の変更だけ。この Dev Container で `python3 -m venv` が pip 付きで作れる（`task1-apt.txt`）
2. **check bead（REQ-009）**: `gc bd list -l check-later --json` に `path_exists`・`must_hold`・`tascon-backend`・`{"path": "/usr/lib/python3.13/ensurepip/__init__.py"}` の bead が 1 つ（`task1-check-bead.txt`）
3. **lefthook の項目（REQ-001・REQ-002）**: `lefthook.yml` の pre-commit の `semgrep` と pre-push の `brakeman` が、要件の YAML のとおりで、`glob`・`stage_fixed` が無い（`task4-scope.txt`）
4. **Semgrep の用意（REQ-004）**: 空のキャッシュからの初回が 0 で終わり、2 回目は導入しない（`task2-cache.txt`）。venv・取り出し・SHA の失敗がそれぞれ理由と直し方を出して 1 で終わり、作りかけを残さない（`task2-fail-*.txt`）。同時の初回が両方 0 で、キャッシュに 1 組だけ残る（`task2-race.txt`）
5. **Semgrep のフック（REQ-001・REQ-005）**: 当たる `.erb` で `hit rc=1`、`.md` だけで `md rc=0` と時間（`task2-hook-*.txt`）
6. **CI との一致（REQ-004・REQ-005）**: 全体の走査で報告のあるファイルとスクリプトが 1 で終わるファイルが一致し、`vendor/`・`test/` のファイルで報告が出ない（`task2-compare.txt`）
7. **Brakeman（REQ-002・REQ-005）**: 土台の中身で `clean rc=0` と時間、`eval` の変更で `eval rc=1`（`task3-*.txt`）
8. **範囲（REQ-006・REQ-007）**: 変わったファイルが 3〜4 個だけで、`.github/`・`.claude/rules/` の差が空、`lefthook.yml` の既存の行が同じ、土台が祖先（`task4-scope.txt`）
9. **既存の項目（REQ-005）**: 各コミットのフックの出力と、`lefthook run pre-push`・`bin/bundle exec rubocop` が 0（`task*-commit.txt`、`task4-existing.txt`）
10. **言語・コメント（REQ-008）**: `semgrep.sh` が Task 2 Step 2 の一覧の物だけを使い、`#` のコメントがすべて英語。`grep -nP '[^\x00-\x7F]' .lefthook/pre-commit/semgrep.sh Docker/api/Dockerfile` が何も出さない

## Coverage

| ID | Requirement | Status |
|---|---|---|
| REQ-001 | pre-commit の Semgrep | covered |
| REQ-002 | pre-push の Brakeman | covered |
| REQ-003 | Dev Container のイメージ | covered |
| REQ-004 | Semgrep を走らせるスクリプト | covered |
| REQ-005 | Dev Container での実際の確かめ | covered |
| REQ-006 | CI を変えない | covered |
| REQ-007 | tb-eow1n の項目・ルール・枝の親 | covered |
| REQ-008 | 明示的に入れた言語・英語のコメント | covered |
| REQ-009 | イメージの作り直しの後の check bead | covered |

## Traceability

| Requirement | Where the plan does it | Evidence for review |
|---|---|---|
| REQ-001 | Task 2 Step 3・7・9 | `task2-hook-*.txt`、`task4-scope.txt` |
| REQ-002 | Task 3 Step 2〜5 | `task3-*.txt`、`task4-scope.txt` |
| REQ-003 | Task 1 Step 2〜4 | `task1-apt.txt`、Dockerfile の差分 |
| REQ-004 | Task 2 Step 2・4〜6・8（D1・D2・D3・D5） | `task2-cache.txt`、`task2-fail-*.txt`、`task2-race.txt`、`task2-compare.txt` |
| REQ-005 | Task 2 Step 4〜9、Task 3 Step 1〜5、Task 4 Step 5 | `$EV` の全ファイルと各 bead のメモ |
| REQ-006 | Task 4 Step 4 | `task4-scope.txt` |
| REQ-007 | Task 4 Step 4、全タスクの共通の決まり | `task4-scope.txt`、`task1-start.txt` |
| REQ-008 | Task 1 Step 2、Task 2 Step 2、Verification 10 | スクリプトと Dockerfile、`grep -nP` の結果 |
| REQ-009 | Task 1 Step 5 | `task1-check-bead.txt` |

要件の「文書の扱い」は Task 4 Step 1〜3 が受け持つ。

## Risks and Assumptions

- **R1（初回の待ち）**: キャッシュが空の最初のコミットは、規則の取り出しと Semgrep の導入でネットワークが要り、計画の段で 164 秒かかった。2 回目からは約 3 秒。キャッシュは worktree の間で共有される
- **R2（キャッシュの増加）**: `semgrep.txt`・規則の SHA・`python3` の版を上げると、新しい `venv-*`・`rules-*` が作られ、古い物は残る（1 つの venv は数百 MB）。消す仕組みは入れない（YAGNI）。困ったら `~/.cache/tascon-backend/semgrep` を消せば次のコミットで作り直す
- **R3（glob の文字）**: `--include` の値は glob として読まれる。`[`・`*`・`?`・`\` を含むパスは、別のファイルにも当たりうる。土台の `git ls-files` にそういうパスは 0 個なので、手当てはしない
- **R4（部分的なステージ）**: Semgrep は作業ツリーの中身を見るので、一部だけステージしたファイルではステージしていない行も見る。既存の rubocop と同じ扱い（要件の範囲外）
- **R5（proxy での確かめ）**: Task 2 Step 5 (b) は `https_proxy` で取り出しを塞ぐ。この Dev Container の git の設定が proxy の変数を上書きするときは塞げないので、飛ばした理由を残す
- **R6（tb-eow1n との重なり）**: tb-eow1n（`chore/lefthook-stage-placement`、base main）も `lefthook.yml` を変える。この計画は `protect-branch` の後と `check-git-clean` の後にだけ足すので、積み直しで重なったら両方の項目を残して解く（設計の決め方）
- **R7（python の版）**: CI は Python 3.13.18、Dev Container は 3.13.5。Task 2 Step 8 の突き合わせは同じ Dev Container の Semgrep で行うので、版の違いによるずれは確かめられない。計画の段の結果（P5・P6）と規則の対象（ruby・generic・yaml）から、ずれは出ないと見込む
- **A1（計画の段の apt）**: この Dev Container には計画の段で `python3-venv` を入れた。Task 1 Step 4 の apt は「既に入っている」になる。コンテナを作り直した後の状態は check bead が確かめる
- **A2（item branch の名前）**: 想定は `chore/lefthook-brakeman-semgrep`。drain が別の名前にしたら、記録された名前を使う
- **A3（計画の段の読み取り）**: 計画の段で、pip の導入の最初の試し（P1）に、誤って別の worker の worktree（`.claude/worktrees/gc-tb-34jte`、`ci/add-mutant-report` を取り出している）の `semgrep.txt` を pip に読ませた。その後の試し（P3〜P8）は `git show origin/ci/add-mutant-report:...` と捨てる worktree の中の `semgrep.txt` だけで行い、P6 の初回の導入も成功した。この計画の内容には影響しない

## Handoff

superpowers-build の formula がこのタスクの周りの lifecycle を回す。どれも実装のタスクではない。

- **Plan review**: この draft を要件と照らす。特に D1（venv を symlink で公開）と D2（`--include` での絞り込み）は要件の書いた形からのずれなので、要件の意図（作りかけを置かない・同時の初回で壊れない、全体の走査と同じ無視）に合うかを見る。承認したら `status: approved` にする
- **Decompose**: `### Task 1`〜`### Task 4` から実装の bead を 4 つ作り、番号の順に依存をつける（2 は 1 に、4 は 2 と 3 に。3 は 1 の後でよい）。bead の中身は範囲だけ（題、item branch の名前の希望、ファイル、振る舞い、受け入れの条件、要件とこの計画へのリンク）
- **実装の drain**: 同じ item branch（土台 `ci/add-mutant-report`）と worktree の上で、4 つを順に行う
- **Implementation summary**: `implementation-summary.md`（root の `gc.build.implementation_summary_path`）に、REQ-005 が求める結果（コマンド、終了コード、かかった時間、出力の要点）を `$EV` と各 bead のメモから写す。D1・D2 を使ったこと、決定記録の判断（Task 4）、check bead の ID も書く
- **Review**: item branch の差分（`origin/ci/add-mutant-report`..item branch）を、要件と `scripts-authoring`・`code-comments`・`decisions-maintenance` のルールに照らす
- **Finalize・Publish**: `gc.var.push=true`・`gc.var.open_pr=false`。push のときに新しい pre-push の `brakeman` が走る

## Open Questions

人の答えが要る問いは無い。要件の未解決の問いのうち、wheel の有無（P1）、明示的に渡したファイルの無視（P4・P5、D2 で対応）、ensurepip のパス（Current System の最後の項）は計画の段で確かめた。Python のパッチ版の違い（R7）は、この Dev Container では確かめられないまま残る。D1・D2 は要件の書いた形からのずれで、plan-review が見る。

## Decision Log

- 2026-11-20: plan-review で計画を承認。正式な plan/spec を保存する方針を採用。保存しない旨の旧記述はこの決定で変更。出典: /home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/requirements.md, /home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/design.md, /home/ruby/tascon-backend/.gc-artifacts/lefthook-brakeman-semgrep/implementation-plan.md。
