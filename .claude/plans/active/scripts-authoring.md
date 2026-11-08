# スクリプトで使う言語・コマンドの共通ルールを足す

## Context/Purpose

このリポジトリのhook・Skill付属スクリプト・lefthookのスクリプトには、使ってよい言語・コマンドを決める共通の規約がない。`.claude/rules/hooks-authoring.md`に「hookスクリプトはシェルスクリプトを優先する。追加インタプリタへの依存は避ける」の1行があるだけで、`.lefthook/**`・`lefthook.yml`・`.claude/skills/**/scripts/**`を触るときには何も差し込まれない。環境に明示的に入っていない言語・コマンド（ほかの道具の依存として入っているだけのもの等）にスクリプトが頼ると、別の環境やコンテナの作り直しの後で動かなくなる。

これを、対象の5パス（`.claude/settings.json`、`.claude/hooks/**`、`.claude/skills/**/scripts/**`、`.lefthook/**`、`lefthook.yml`）を触るときだけ差し込まれる共通ルール`.claude/rules/scripts-authoring.md`として定め、`hooks-authoring.md`から重複する1行を消す。既存スクリプトは書き換えない。

ブランチは`docs/add-scripts-authoring-rule`（mainから切る別スタック、`branch.docs/add-scripts-authoring-rule.plan`は`scripts-authoring:1`）。PRは後段のstack-reviewが作る。

## Progress

- [x] Step1: `scripts-authoring.md`を足し、`hooks-authoring.md`のシェル優先の行を消して、`claude-md-maintenance`の比較テストを行う
  - ルール2ファイルとこのplanを作成・変更し、未コミットのまま比較テストを行った（検証結果）
  - ブランチ`docs/add-scripts-authoring-rule`（mainが親、実装前の準備で作成）にコミットした。pushは後段のpublish、PRは後段のstack-reviewが行う

## 検証結果

- Step1の比較テスト（2026-11-08、対象: `scripts-authoring.md`（新規）・`hooks-authoring.md`（1行削除）。ブランチは実装前の準備で先に作られていたが、変更とplanは未コミットのためdetachなし）: 期待する行動を「使う言語・コマンドが4か所のどこで入っているかを確かめ、ほかの道具の依存として入っているだけのものは使わない」とした
  - 場面1（`.lefthook/pre-commit/`を読ませてpre-commitのスクリプトを足す）: 変更前はbashで書き、確かめるのは`lefthook.yml`と既存スクリプト。4か所は挙がらず、差し込まれたルールは`code-comments.md`と`claude-md-maintenance.md`だけ。変更後は`scripts-authoring.md`が差し込まれ、bashで書くことに加え、`devcontainer.json`のfeatures・ベースイメージとDockerfile・`common-utils`・パッケージの管理ファイルで入っているかを確かめ、ほかの道具の依存として入っているだけのものは使わないと答えた
  - 場面2（`.claude/hooks/`を読ませてhookを足す）: 変更前はbashと`jq`で書き、確かめるのは既存hookの書き方・過去の記録・入力JSONで、4か所は挙がらず。差し込まれたのは`hooks-authoring.md`。変更後は`scripts-authoring.md`が差し込まれ、bashと`jq`で書くが、`jq`の入手元を4か所で確かめるべきとし（未確認と明記）、ほかの道具の依存だけで入っているものは使わないと答えた。シェル優先は残った
  - 判定: 場面1・2とも期待する行動が変更前になく変更後にあるため、新ルールを残す。場面2でシェル優先が残ったため`hooks-authoring.md`の1行削除も維持する。再実行（35秒待ち）は不要だった
- PR作成前の判定（2026-11-08、ブランチ`docs/add-scripts-authoring-rule`をcheckoutして`Validation and Acceptance`の6項目を判定。全項目を満たした）
  - `scripts-authoring.md`の`paths`は5つ（`.claude/settings.json`、`.claude/hooks/**`、`.claude/skills/**/scripts/**`、`.lefthook/**`、`lefthook.yml`）のみ: 満たす（ファイルを読んで確認）
  - 本文は4指示（明示的に入れたものだけを使う／基本はbashで込み入るときは入れてある言語／使う前に4か所を確かめる／依存として入っているだけのものは使わない）のみ: 満たす（ファイルを読んで確認）
  - `grep -nE 'Gas City|bead|\bgc\b|mayor|Python|jq|例:'`は何も返さない: 満たす（再実行、終了コード1）
  - `git diff main -- .claude/rules/hooks-authoring.md`は該当1行の削除のみ: 満たす（再実行）
  - 比較テストの記録（場面・変更前後の違い・取り下げなし）: 満たす（上の比較テストの記録を根拠にした）
  - mainが親で差分は3ファイルのみ: 満たす（`git merge-base main HEAD`がmainの先端と一致、`git diff --name-only main...HEAD`が`scripts-authoring.md`・`hooks-authoring.md`・このplanの3つ）

## Decision Log

- 2026-11-08: 言語・コマンドの方針は、`.claude/rules/scripts-authoring.md`として5パスに差し込む共通ルールにする。特定のパスを触るときだけ必要な規約は`claude-md-maintenance`の置き場所判断でrulesに置く。`AGENTS.md`/`CLAUDE.md`に常時の方針として書く案は、常時の文脈を増やすため採らなかった
- 2026-11-08: 本文には道具・言語の名前の具体例、このリポジトリ固有の事情、外部の仕組みの言葉を書かない。ほかのリポジトリへそのまま持っていける共通ルールにするため。指示の中身である「シェル（bash）」と、確かめる場所として挙げる`.devcontainer/devcontainer.json`・`common-utils`・Dockerfileは残す
- 2026-11-08: 確かめる場所は、`.devcontainer/devcontainer.json`のfeatures、ベースイメージ・Dockerfile、Feature `common-utils`、パッケージの管理ファイルの4か所にする。ここで明示的に入れたものだけが、別の環境でも入っていると言えるため。ほかの道具の依存として入っているだけのものは、その道具の構成が変わると消えるので使わない
- 2026-11-08: `hooks-authoring.md`の「hookスクリプトはシェルスクリプトを優先する。追加インタプリタへの依存は避ける」は、新ルールへの移設として削除する。新ルールの「明示的に入れてある言語・コマンドだけ」「基本はシェル（bash）」「依存として入っているだけのものは使わない」が同じ方針を含み、2つのルールに重複して書かないため
- 2026-11-08: ブランチは未マージのスタックの最上段ではなくmainから切る。依頼が、ほかの作業と混ざらない独立したスタックのPRとしてレビュー・承認することを求めているため（`git-spice-workflow`の「最上段に積む」の例外）
- 2026-11-08: `docs/decisions/`への記録はこのブランチでは作らない。理由はこのDecision Logに書き、横断的な決定として移すかは完了処理で決める

## Validation and Acceptance

- `.claude/rules/scripts-authoring.md`があり、`paths`がちょうど`.claude/settings.json`、`.claude/hooks/**`、`.claude/skills/**/scripts/**`、`.lefthook/**`、`lefthook.yml`の5つである
- `scripts-authoring.md`の本文が、明示的に入れてある言語・コマンドだけを使う、基本はシェル（bash）で込み入るときは明示的に入れてある言語でよい、使う前に4か所を確かめる、ほかの道具の依存として入っているだけのものは使わない、の4指示だけを含む
- `grep -nE 'Gas City|bead|\bgc\b|mayor|Python|jq|例:' .claude/rules/scripts-authoring.md`が何も返さない
- `git diff main -- .claude/rules/hooks-authoring.md`が、「- hookスクリプトはシェルスクリプトを優先する。追加インタプリタへの依存は避ける」の削除1行だけを示す
- `claude-md-maintenance`ルールの比較テストを行い、比べた場面・変更前後の答えの違い・取り下げ（あれば理由）を検証結果に記録している。差が出なかった変更は取り消している
- このplanのブランチがmainを親とし、差分がこのplanの変更（`scripts-authoring.md`、`hooks-authoring.md`、このplanファイル）だけである
