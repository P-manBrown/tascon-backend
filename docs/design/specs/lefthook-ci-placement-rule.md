# lefthook-ci-placement-rule specification

## Approved requirements

## 要件: lefthook と CI の振り分けの基準のルール（tascon-backend）

- build: `lefthook-ci-placement-rule`（workflow root `tb-z3r00`、依頼の部分 `tb-x5qt6`、依頼 `gc-wvsr` の 2 ＋ `gc-tmf1` の 3）
- 承認済みの設計: `/home/ruby/tascon-backend/.gc-artifacts/lefthook-ci-placement-rule/brainstorming/design.md`（承認の記録: 同じ folder の `design-approval.md`、approval lane `tb-tpqhg`、autonomous）
- 要件の出典: `tb-x5qt6` の説明（依頼の原文）と、`tb-x5qt6`・`tb-z3r00` の notes にある追加（「必須にする確かめは1つのワークフローに置き、まとめ役のジョブ checks だけを必須のチェックにする」）
- spec のループの記録: iteration 1 の review（`brainstorming/spec-review-iteration-1-attempt-1.md`）の必須の指摘は、apply（`brainstorming/spec-feedback-iteration-1-attempt-1.md`）で BR-8・AC-4 に反映済み。この版はそれを保ったまま、review の advisory 2 件（BR-2 の初稿の言い回し、BR-7 の判定の材料）を BR-2・BR-7 で揃えた。iteration 2 の review（`brainstorming/spec-review-iteration-2-attempt-2.md`）の必須の指摘（設計の後に main に入った `0f60f4ad` で分かれた `check-links.sh` の抜け）は、照らす表・BR-10・AC-7 に反映済み。iteration 3 の版はそれを保ち、照らす表の backend の行を今の main（`0f60f4ad`）の `lefthook.yml`・`.github/workflows/ci.yml` と照らし直して、ほかに抜けが無いことを確かめた
- 設計との優先: BR-8 は、承認済みの設計の「4. 失敗と止め方」の 3 点目（文ごとにノイズとして取り消し、5 点を全部取り消す場合だけ残す）に代わる。設計と食い違う所は BR-8 に従う。計画を書く人は、BR-8 と `claude-md-maintenance` の手順 6 の食い違いを、計画の Decision Log に最初から書いておく
- front matter の `status`: formula が決めた producer の形に合わせて `approved` とする。spec の承認の状態は、承認の lane が workflow root の metadata（`gc.build.requirements_status`・`gc.build.spec_gate_status`）に持つ
- 設計の写し（`docs/superpowers/specs/`）: 作らない。この lane はメインの checkout で動いており、そこへ未追跡のファイルを残せないため。設計の記録は上の build の成果物のパスで追う

### Problem Statement

tascon-backend には、確かめ（lint・テスト・文書の検査など）を lefthook のどの段に置くか、CI に置くかの基準が書かれていない。今ある `.claude/rules/hooks-authoring.md` は Claude Code のフック用で、lefthook・GitHub Actions の設定を変えるときには差し込まれない。そのため、AI が `lefthook.yml`・`.lefthook/**`・`.github/workflows/**` を変えるとき、置き場所を速さなどで決めてしまい、人が決めた基準（何を要るかで決める、必須の確かめは CI のまとめ役 `checks` に集める等）から外れうる。

この build では、その基準を新しいルールのファイルにし、`claude-md-maintenance` の比較テストで、ルールを入れる前と後で振り分けの行動が基準どおりに変わることを確かめる。backend と frontend の今の道具と入れる予定の道具を、ルールだけで振り分けさせ、今決まっている置き場所と照らす。

### W6H

- Who（誰が使うか）: tascon-backend（後に dev-workflow-shared 経由で frontend も）で `lefthook.yml`・`.lefthook/**`・`.github/workflows/**` を変える AI エージェント。比較の結果を読むのは人（リポジトリの持ち主）
- What（何を作るか）: `.claude/rules/lefthook-ci-placement.md`（基準の文 5 点）と、比較テストの記録、知らせる物（debride・Brakeman・Semgrep の分かれ方、今の設定とルールの食い違い）
- When（いつ効くか）: `paths` に合うファイル（`lefthook.yml`・`.lefthook/**`・`.github/workflows/**`）を読んだとき・変えるとき
- Where（どこに置くか）: tascon-backend の `.claude/rules/`。記録は `docs/design/plans/` の計画の Decision Log と PR の Testing・Notes、bead の notes
- Why（なぜ）: 確かめの置き場所を、人の決めた基準で一貫させるため（理由はルールには書かず、計画の Decision Log に書く）
- How（どう作るか）: 依頼の 5 点を、具体例・道具の名前・理由なしの基準の文にする。比較テストは承認済みの設計の案 A（中立な場面で全部の道具を振り分けさせる）で行う
- How much（どこまで）: backend の変更を作り、build の後段の決まりに従って PR に進めるところまで（`open_pr=false` の build のため、PR を開く判断は build の後段）。dev-workflow-shared から配る段は範囲外

### User Stories

- US-1: リポジトリの持ち主として、AI が lefthook・CI の設定を変えるときに、確かめの置き場所が私の決めた基準で選ばれてほしい。毎回説明しなくてよくするため
- US-2: リポジトリの持ち主として、置き場所が決まっていない debride・Brakeman・Semgrep が、新しいルールだとどこに分かれるかを知りたい。置き場所を決める材料にするため
- US-3: リポジトリの持ち主として、今の設定がルールと食い違っている所を、直されずに一覧で知りたい。直すかどうかを自分で決めるため
- US-4: リポジトリの持ち主として、ルールを frontend にもそのまま配れる形にしてほしい。dev-workflow-shared から配るため

### Technical Stories

- TS-1: `.claude/rules/lefthook-ci-placement.md` を足す。frontmatter の `paths` はちょうど `"lefthook.yml"`・`".lefthook/**"`・`".github/workflows/**"` の 3 つ。見出しは 1 つ、本文は箇条書き（節を分けてよい）
- TS-2: 本文の初稿は承認済みの設計の「1. ルールのファイル」の文とする（下の Behavior Requirements の BR-1〜BR-5）。比較テストの結果で、依頼の意味を変えない範囲でだけ文を直す
- TS-3: 比較テストは `claude-md-maintenance` の「CLAUDE.md・AGENTS.md・rules・skillsの作成・変更時の必須手順」に従う。Gas City の取り決めにより、変更前と変更後の `rule-tester` は、自分の worktree で起動した headless Claude（`claude -p "..." --allowedTools "Agent Skill Read Grep Glob" --output-format stream-json --verbose`）の中で使い、git の操作（stash・detach・戻し）は自分のセッションで worktree に対して行う。stash は一意の名前で積み、その名前で戻す。メインの checkout の枝は切り替えない
- TS-4: 比較テストの場面は案 A: `.github/workflows/semantic-pull-request.yml` を読ませてルールを差し込ませ、そのうえで道具の一覧（リポジトリ・道具の名前・走らせるコマンドだけ。今の置き場所・ルールの名前・基準の言葉は書かない）を振り分けさせる。各道具に「段（pre-commit・pre-push・CI だけ・手元だけ）」「CI に入れるか・必須にするか」「lefthook で直してよいか」と根拠を答えさせる。変更前と変更後で同じプロンプトを使う
- TS-5: 比較テストの前の状態には、テスト対象の変更とその意図の記録（計画・Decision Log）を混ぜない（`docs/decisions/rule-and-hook-change-tests.md`）。計画のコミットは detach の基準より後に置くか、テスト対象と同じ最初のコミットに含めて detach の基準にする
- TS-6: `rule-tester` の定義・ガードが今の版で動いていることを、手順どおり引用で確かめる。ずれたら `touch` して 35 秒以上おいて確かめ直す
- TS-7: `claude-md-maintenance` の「変更時の確認」に従い、新しいルールの用語と重なる記述（`hooks-authoring.md`・`scripts-authoring.md`・`AGENTS.md`・skill）を `grep` で洗い出し、食い違いを知らせる

### Behavior Requirements

ルールの文として持つ基準（BR-1〜BR-5）と、作業の振る舞い（BR-6〜BR-12）。ルールの文の言い回しは比較テストで直してよいが、意味は下のとおりに保つ。

- BR-1（REQ-002）: 中身を確かめる物（コードや文書が決まりに合っているか、テストが通るか）は CI に入れ、リポジトリ全体を対象にして必須のチェックにする。CI では直さずに落とす
- BR-2（REQ-003）: 中身を確かめる必須のチェックは 1 つのワークフローに置き、そのワークフローのまとめ役のジョブ `checks` だけを必須のチェックにする。初稿はこの文（承認済みの設計の初稿と同じ）。依頼の原文「必須にする確かめは1つのワークフローに置き」を、仮定 2 のとおり中身を確かめる物に絞って書いている
- BR-3（REQ-004）: lefthook のどの段に置くかは、速さでなく、その確かめが何を要るかで決める
  - pre-commit: 変えたファイルだけで確かめられる物
  - pre-push: プロジェクト全体は要るが、ビルド・サーバー・ブラウザ・DB は要らない物
  - CI だけ: ビルド・サーバー・ブラウザ・DB が要る物、またはテストを何度も走らせる物
  - 手元だけ: 手元の状態を見る物
- BR-4（REQ-005）: lefthook で直すのは、意味を変えないと保証された直しだけにする
- BR-5（REQ-006）: lefthook か CI のどちらかを変えたら、同じ PR でもう一方にも要るかを確かめる
- BR-6（REQ-007）: ルールは日本語で、道具の名前・具体例・理由・経緯・強調語（`IMPORTANT` 等）・backend だけのパスやジョブの中身を含まない。`claude-md-maintenance` の「代表例を添える」例外は使わない（人の依頼が具体例を書かないと明示しているため）
- BR-7（REQ-008）: 比較テストの期待する行動は「道具の置き場所を、速さでなく確かめに要る物（変えたファイルだけ／プロジェクト全体／ビルド・サーバー・ブラウザ・DB・テストの繰り返し／手元の状態）で決め、決まっている道具では照らす表の段と一致させる」こと。判定は、期待する行動が変更前に無く変更後にあるか。判定の材料は、段の一致だけでなく、答えの根拠が置き場所を何で決めているか（速さ・重さか、確かめに要る物か）に置く。変更前でも段が一致した道具はそのことを記録し、その道具はその根拠で判定する
- BR-8（REQ-009）: 比較テストの判定は、文ごとではなく、ルールのファイル全体について BR-7 の 1 つの期待する行動で行う。変更後の答えの段が照らす表と食い違った所は、例を足さずに基準の文を直し、同じプロンプトで変更後のテストをやり直す。依頼の 5 点の意味を変えない範囲で直らない食い違いは、直さずに残し、bead の notes と PR の Notes で知らせる。判定がノイズになったとき（変更後にも期待する行動が出ない場合も、変更前にも期待する行動が出ている場合も）は、`claude-md-maintenance` の手順 6 の「取り消す」を適用せず、依頼の 5 点の文をどれも取り消さずに残す。そのときは、その判定と、依頼（5 点を書いたルールを作る）とリポジトリのルール（ノイズは取り消す）の食い違いを、計画の Decision Log・PR の Testing・bead の notes に書いて人に知らせる
- BR-9（REQ-010）: debride・Brakeman・Semgrep は一致を見ず、ルールでどう分かれたか（段・CI に入れるか・必須にするか・lefthook で直すか）を記録し、bead の notes と PR で知らせる
- BR-10（REQ-011）: 今の設定とルールの食い違い（例: backend の `check-links.sh` と、frontend の markdownlint・check-logger-trace・`check-docs.sh` が CI に無い、CodeQL が別のワークフロー、htmlbeautifier の直しが「意味を変えないと保証された直し」に当たるかの判断）は、ルールの文を直す対象にせず、設定も変えずに知らせる物として記録する
- BR-11（REQ-012）: 理由・比較テストの記録（プロンプト、変更前と変更後の答え、照らした結果、直した文と理由）は `docs/design/plans/` の計画の Decision Log と PR の Testing に書き、ルールには書かない
- BR-12（REQ-014）: 変更時の確認（TS-7）で見つけた食い違う記述は、このbuildでは直さず知らせる

#### 照らす表（今決まっている置き場所）

比較テストの答え合わせだけに使う（ルールには書かない）。一致を見るのは「段」。「CI」は CI に入るか。「決まっていない」は一致を見ず、分かれ方を記録する。

backend（今）

- rubocop: pre-commit（安全な直しの `--autocorrect`）＋ CI
- htmlbeautifier: pre-commit（直す）＋ CI（`--lint-only`）
- debride: 決まっていない（今は pre-commit で変えたファイルだけ。案は `app config` を渡す。CI は全体）
- protect-branch: 手元だけ（pre-commit）
- `check-docs.sh`: pre-commit ＋ CI
- `check-plan-completion.sh`: pre-commit ＋ CI
- `check-links.sh`: pre-commit（CI に無い）
- `.lefthook/pre-commit/tests/run.sh`・plan-completion のスクリプトのテスト: pre-commit ＋ CI
- check-git-clean: 手元だけ（pre-push）
- rspec: CI だけ（DB）
- semantic-pull-request（Validate PR title）・Related Documents の確かめ: CI だけ（PR のタイトル・本文を見る）

backend（入れる予定）

- SimpleCov: CI だけ（rspec の中で率を書くだけ。合否を返さない）
- Brakeman: 決まっていない（#836 では CI の job）
- Semgrep: 決まっていない（#837 では CI の job）
- CodeQL（`Analyze (ruby)`）: CI だけ（別のワークフロー `codeql.yml`）
- Dependency Review: CI だけ（PR の依存の差分を GitHub で見る）
- code-review-graph: CI だけ（報告だけ。合否を返さない）
- PR の言語の確かめ: CI だけ（PR のタイトル・本文を見る）

frontend（今。#955 の形を決まった置き場所とする）

- biome: pre-commit（safe な直しの `--write`）＋ CI
- markuplint: pre-commit（直さない）＋ CI
- markdownlint: pre-commit（直さない）
- check-logger-trace: pre-commit
- protect-branch: 手元だけ（pre-commit）
- `check-docs.sh`: pre-commit
- knip: pre-push ＋ CI
- `next typegen && tsc --noEmit`: pre-push ＋ CI
- `next build`: CI だけ（ビルド）
- check-git-clean: 手元だけ（pre-push）
- semantic-pull-request: CI だけ

frontend（入れる予定）

- Vitest の全部のテスト: CI だけ。pre-push は関係するテストだけ（`vitest related`）。依頼の原文が明示した決まった置き場所
- Playwright: CI だけ（ブラウザ・サーバー）
- Stryker: CI だけ（テストを何度も走らせる）

### Example Mapping

ルール: BR-3（段は何を要るかで決める）

- 例: 変えたファイルだけを読む書式の検査 → pre-commit（＋ BR-1 で CI）
- 例: プロジェクト全体の未使用コードの検出で、ビルド・DB は要らない → pre-push（＋ CI）
- 例: DB を使うテスト → CI だけ
- 例: 手元の枝やワークツリーの状態を見る検査 → 手元だけ
- 問い（比較テストで確かめる）: Vitest の全部のテストはビルド・サーバー・ブラウザ・DB を要らないが、決まった置き場所は CI だけ（pre-push は関係するテストだけ）。初稿で pre-push に振り分けられたら、意味を変えない範囲で文を直して試し直す
- 問い（比較テストで確かめる）: backend の pre-commit のテストの実行（`.lefthook/pre-commit/tests/run.sh` 等）は「変えたファイルだけ」に当たらず pre-push に振り分けられうる

ルール: BR-1・BR-2（中身の確かめは CI の必須、まとめ役 `checks` だけを必須）

- 例: lint・テストは CI のまとめ役 `checks` が待つジョブに入り、CI では直さずに落とす
- 例: 合否を返さない報告（SimpleCov・code-review-graph）は必須の確かめに当たらず、CI だけの報告として照らす
- 問い（比較テストで確かめる）: PR のタイトル・本文を見る確かめ・Dependency Review は「CI だけ」の条件（ビルド・サーバー・ブラウザ・DB・テストの繰り返し）に当たらない。食い違えば文を直して試し直す
- 問い（知らせる物）: CodeQL は別のワークフローにあり、BR-2 と合わない。ルールの文ではなく今の設定の側の話として知らせる（BR-10）

ルール: BR-4（lefthook で直すのは意味を変えないと保証された直しだけ）

- 例: 安全な直しだけの自動修正（rubocop の `--autocorrect`、biome の `--write`）→ lefthook で直してよい
- 問い（知らせる物）: htmlbeautifier の直しが当たるかは、ルールでどう判断されたかを知らせる（設定は変えない）

ルール: BR-5（片方を変えたらもう一方を確かめる）

- 例: lefthook に確かめを足す PR では、同じ PR で CI にも要るかを確かめる

### Acceptance Criteria

- AC-1（REQ-001）: `.claude/rules/lefthook-ci-placement.md` があり、frontmatter の `paths` がちょうど `lefthook.yml`・`.lefthook/**`・`.github/workflows/**` の 3 つ。`.claude/rules/hooks-authoring.md` は変わっていない
- AC-2（REQ-002〜REQ-006）: 本文が BR-1〜BR-5 の 5 点を基準の文として持つ（言い回しは比較テストで直してよいが、意味は保つ）
- AC-3（REQ-007）: 本文が道具の名前・具体例・理由・強調語・backend だけのパスやジョブの中身を含まない
- AC-4（REQ-008）: 比較テストを `claude-md-maintenance` の手順（TS-3 の Gas City の読み替えを含む）で行い、ファイル全体について期待する行動が変更前に無く変更後にあるかを判定している。ノイズと判定された場合は、依頼の 5 点の文がどれも取り消されずに残り、その判定と食い違いが計画の Decision Log・PR の Testing・bead の notes に書かれている（BR-8）。`rule-tester` の定義・ガードの確認の引用がある
- AC-5（REQ-009）: 決まっている道具で、変更後の答えの段が照らす表と一致する。一致しない物は、文を直して試し直した記録と、残った理由がある
- AC-6（REQ-010）: debride・Brakeman・Semgrep がルールでどう分かれたか（段・CI・直すか）が、bead の notes と PR に書かれている
- AC-7（REQ-011）: 今の設定とルールの食い違い（CI に無い確かめ（backend の `check-links.sh`・frontend の markdownlint 等）、CodeQL の別ワークフロー、htmlbeautifier の直しの判断 等）が、直されずに知らせとして書かれている
- AC-8（REQ-012）: 理由・比較テストの記録が `docs/design/plans/` の計画の Decision Log と PR の Testing にあり、ルールには無い
- AC-9（REQ-013）: `lefthook.yml`・`.lefthook/**`・`.github/workflows/**` の中身が変わっていない。変更は backend のリポジトリだけ
- AC-10（REQ-014）: 変更時の確認の `grep` の結果と、食い違う記述があればその知らせが、計画か PR に書かれている

### Out Of Scope

- `lefthook.yml`・`.lefthook/**`・`.github/workflows/**` の中身の変更（今の置き場所がルールと食い違っても、このbuildでは直さず知らせる）
- `ci.yml` を「ジョブに分けて `checks` をまとめ役にする」形へ組み替えること（人が別に行う）
- 必須チェックの登録（人が GitHub の設定で行う）
- dev-workflow-shared から配る段（backend の main に入った後、別の部分として流す）
- frontend のリポジトリの変更
- `hooks-authoring.md`・`scripts-authoring.md` の変更（`paths` の重なりはそのままにする）
- 比較テストで直らない食い違いについて、基準を変えるか置き場所を変えるかを決めること（人が決める）

### Open Questions

人の答えが要る問いは無い。曖昧な所は次の仮定で進める（承認済みの設計の「仮定」と同じ。bead `tb-57x31` の notes にもある）。

- 仮定 1: frontend の「今決まっている置き場所」は、開いている #955 の形（markuplint は直さない、pre-push に `next typegen && tsc --noEmit`）とする。#955 は決定の記録を Accepted で持つため
- 仮定 2: BR-2 の「必須にする確かめ」は中身を確かめる物に限る。人の mail が Validate PR title も必須に登録すると書いており、PR のタイトルの確かめは別のワークフローのままでよいため
- 仮定 3: 「入れる予定の道具」は、backend の開いている PR・枝（#836・#837・#839・#840・`ci/check-pr-language`・`build/debride-full-scope`）と、frontend の #947 の試しに出た Vitest・Playwright・Stryker とする。他の作業者の worktree の中身は使わない
- 仮定 4: SimpleCov・code-review-graph は合否を返さない報告のため、「必須にする確かめ」ではなく CI だけの報告として照らす

build の中で決めず残す物: 比較テストで依頼の 5 点の意味を変えない範囲で直らない食い違いが残った場合の扱い（基準を変えるか、置き場所を変えるか）。build の中では残して知らせる（BR-8）。比較テストの判定がノイズになった場合に、依頼の 5 点を残すか取り消すかも build の中では決めず、5 点を残して知らせる（BR-8）。

### Traceability

| ID | Status | 要件 | 根拠 |
| --- | --- | --- | --- |
| REQ-001 | covered | 新しいルールのファイルと `paths` の 3 つ、`hooks-authoring.md` と別にする | TS-1、AC-1 |
| REQ-002 | covered | 中身の確かめは CI で全体を必須にし、直さずに落とす | BR-1、AC-2 |
| REQ-003 | covered | 必須の確かめは 1 つのワークフロー、まとめ役 `checks` だけを必須 | BR-2、AC-2 |
| REQ-004 | covered | 段は何を要るかで決める（4 つの段） | BR-3、AC-2 |
| REQ-005 | covered | lefthook の直しは意味を変えないと保証された物だけ | BR-4、AC-2 |
| REQ-006 | covered | 片方を変えたら同じ PR でもう一方を確かめる | BR-5、AC-2 |
| REQ-007 | covered | 書き方の制約（具体例・道具の名前・理由・強調語なし、frontend でも読める） | BR-6、AC-3 |
| REQ-008 | covered | 変更前と変更後の比較テスト（案 A、worktree の headless Claude） | TS-3〜TS-6、BR-7、AC-4 |
| REQ-009 | covered | 照らす表との照合、食い違いは文を直して試し直す。ノイズの判定でも 5 点は残して知らせる | BR-8、AC-5 |
| REQ-010 | covered | debride・Brakeman・Semgrep の分かれ方を知らせる | BR-9、AC-6 |
| REQ-011 | covered | 今の設定とルールの食い違いを直さずに知らせる | BR-10、AC-7 |
| REQ-012 | covered | 理由・テストの記録は計画の Decision Log と PR に置く | BR-11、AC-8 |
| REQ-013 | covered | lefthook・CI の設定を変えない、backend だけ | Out Of Scope、AC-9 |
| REQ-014 | covered | 変更時の確認で重なる記述を洗い出して知らせる | TS-7、BR-12、AC-10 |

### Spec Self-Review

- 置き換え待ちの記述: 無い（置き換え待ちの印・空の節を探して無いことを確かめた）
- 内部の一貫性: BR-1〜BR-5 は設計の文の初稿と同じ文（BR-2 も設計の初稿の文に揃え、TS-2 の「初稿は設計の文」と食い違わない）。照らす表は設計の「2. 照らす表」に、設計の後に main に入った `check-links.sh` の行を足した物で、backend の行は今の main の `lefthook.yml`・`ci.yml` と一致する。BR-8 と設計の「4. 失敗と止め方」の 3 点目の食い違いは、冒頭の「設計との優先」で BR-8 に従うと決めた。範囲外と AC-9 が一致する。PR は「build の後段の決まりに従う」で、W6H と Out Of Scope で食い違わない
- 範囲: ルール 1 つと、その比較テスト・知らせる物だけで、1 つの実装計画に収まる
- 曖昧さ: 「必須にする確かめ」の範囲（仮定 2）、frontend の決まった置き場所（仮定 1）、入れる予定の道具の範囲（仮定 3）、報告だけの道具の扱い（仮定 4）を明示した。直らない食い違いの扱いと、比較テストの判定がノイズになったときの扱い（判定はファイル全体で行い、5 点を残して知らせる）は BR-8 で決めた

## Adopted design

## 設計候補: lefthook と CI の振り分けの基準のルール（tascon-backend）

- build: `lefthook-ci-placement-rule`（root bead `tb-z3r00`、依頼 bead `tb-x5qt6`、依頼 `gc-wvsr` の 2 ＋ `gc-tmf1` の 3）
- brainstorming lane bead: `tb-57x31`（attempt 1, iteration 1）
- approval mode: autonomous
- 承認の状態: **承認済み（autonomous、approval lane `tb-tpqhg`、2026-11-19）**。根拠は下の「自律で進める根拠」と `design-approval.md`

### Superpowers チェックリスト 1〜5 の記録

1. プロジェクトの文脈の確認: 済み（確かめた物は「確かめた文脈」）
2. Visual Companion: 出さない。見た目の問いがない（ルールの文と振り分けの表だけ）
3. 問い: 人の答えが要る問いはない。曖昧な所は「仮定」に書いて進める（autonomous のため人に聞かない）
4. 方式: 3 案を比べ、案 A を勧める（「方式の比較」）
5. 設計: 下の節に分けて示す

### 求められた結果

`.claude/rules/` に新しいルールを 1 つ足し、lefthook と CI への確かめの振り分けの基準を書く。

- `paths`: `lefthook.yml`・`.lefthook/**`・`.github/workflows/**`
- 今の `hooks-authoring.md`（Claude Code のフック用）とは別のファイルにする
- 中身（依頼の原文の 4 点 ＋ 追加の 1 点。具体例は書かない）
  1. 中身を確かめる物（コードや文書が決まりに合っているか、テストが通るか）は CI に入れ、リポジトリ全体を見て必須のチェックにする。CI では直さずに落とす
  2. lefthook への振り分けは、速さでなく、その確かめが何を要るかで決める。pre-commit は変えたファイルだけで確かめられる物。pre-push はプロジェクト全体は要るが、ビルド・サーバー・ブラウザ・DB は要らない物。CI だけは、ビルド・サーバー・ブラウザ・DB が要る物か、テストを何度も走らせる物。手元だけは、手元の状態を見る物
  3. lefthook で直すのは、意味を変えないと保証された直しだけにする
  4. lefthook か CI のどちらかを変えたら、同じ PR でもう一方にも要るかを確かめる
  5. （追加）必須にする確かめは 1 つのワークフローに置き、まとめ役のジョブ `checks` だけを必須のチェックにする
- テスト: `claude-md-maintenance` ルールの比較テストを、入れる前と後で行う。backend と frontend の今の lefthook と CI の道具を全部（入れる予定の道具も含む）、ルールだけを読ませて振り分けさせ、今決まっている置き場所と照らす。食い違った所は、例を足さずに基準の文を直して試し直す
- 知らせる物: debride・Brakeman・Semgrep がルールでどう分かれたか（置き場所が決まっていない）
- 今夜の範囲は backend の PR を出すところまで（open_pr=false の build のため、PR は build の後段の決まりに従う）

### 制約

- ルールの書き方は `claude-md-maintenance` の「SKILL.md/rules執筆時の原則」に従う: 日本語、理由・経緯は書かない（書く場所は `docs/design/plans/` の Decision Log）、一般原則だけ
- 具体例は書かない。人の依頼が明示しているため、比較テストで行動が変わらなくても `claude-md-maintenance` の「代表例を添える」例外は使わない（基準の文を直して試し直す）
- 強調語（`IMPORTANT` 等）は使わない
- dev-workflow-shared から後で配るので、backend だけの道具名・パス・ジョブの中身をルールに書かない（frontend でもそのまま読める文にする）
- 比較テストは、Gas City の取り決めに従い、作業ツリー（worktree）で起動した headless Claude の中で `rule-tester` を使う。メインの checkout の枝は切り替えない。stash は一意の名前で積み、名前で探して戻す
- 比較テストの前の状態には、テスト対象の変更とその意図の記録（plan・Decision Log）を混ぜない（`docs/decisions/rule-and-hook-change-tests.md`）

### 範囲外（non-goals）

- `lefthook.yml`・`.lefthook/**`・`.github/workflows/**` の中身の変更（今の置き場所がルールと食い違っても、このbuildでは直さず知らせる）
- `ci.yml` を「ジョブに分けて `checks` をまとめ役にする」形へ組み替えること（人の mail で別に行うと書かれている）
- 必須チェックの登録（人が GitHub の設定で行う）
- dev-workflow-shared から配る段（backend の main に入った後に別の部分として流す）
- frontend のリポジトリの変更
- `hooks-authoring.md`・`scripts-authoring.md` の変更（`paths` の重なりはそのままにする）

### 確かめた文脈

- `.claude/rules/`: `hooks-authoring.md`（`paths`: `.claude/settings.json`・`.claude/hooks/**`。Claude Code のフック用）、`scripts-authoring.md`（`paths` に `lefthook.yml`・`.lefthook/**` を含む。スクリプトの言語の決まり）、`claude-md-maintenance.md`（比較テストの手順と執筆の原則）
- `.claude/agents/rule-tester.md` と `.claude/hooks/rule-tester-guard.sh`: `.claude/rules`・`skills`・`plans`・`memory` は読めない。ルールは `paths` に合うファイルを読んだときの差し込みでだけ使う。`lefthook.yml`・`.github/workflows/**` は読める
- `docs/decisions/rule-and-hook-change-tests.md`: 比較テストの条件
- backend の `lefthook.yml`・`.github/workflows/ci.yml`（job `rspec`・`checks`）・`semantic-pull-request.yml`・`related-documents.yml`
- backend の入れる予定の道具（共有の git の枝と開いている PR から。他の作業者の worktree の中身は使わない）: #836 `ci/add-simplecov-and-brakeman`（SimpleCov、job `brakeman`）、#837 `ci/add-codeql-and-semgrep`（`codeql.yml` の `Analyze (ruby)`、job `semgrep`）、#839 `ci/add-dependency-review`（job `dependency-review`）、#840 `ci/add-code-review-graph-report`（報告だけの `code-review-graph.yml`）、枝 `ci/check-pr-language`（`pr-title-and-body.yml` の PR の言語の確かめ）、`docs/design/plans/active/lefthook-debride-scope-change.md` と枝 `build/debride-full-scope`（debride に `app config` を渡す案）
- backend の `docs/design/plans/active/git-spice-merge-and-ci-gates.md` の Decision Log: 「lefthook は手元の速い知らせと自動の直しのために今のまま残し、関門にはしない」。新しいルールの 1 点目（CI を関門にする）と食い違わない
- frontend（`P-manBrown/tascon-frontend` を `gh api` で読んだ）: `lefthook.yml`（pre-commit: biome・markuplint・markdownlint・check-logger-trace・protect-branch・check-docs.sh、pre-push: knip・check-git-clean）、`.github/workflows/static-checks.yml`（`tsc --noEmit`・biome・knip・markuplint・`next build`）、`semantic-pull-request.yml`
- frontend の開いている PR: #955（markuplint の `--fix` を外す、pre-push に `next typegen && tsc --noEmit`、決定の記録 `docs/decisions/local-hooks-vs-ci-checks.md`）、#947・#953（Vitest・Playwright・Stryker を入れる前の試し）

### 方式の比較

#### 案 A（勧める）: 新しいルール 1 つ ＋ 中立な場面での 1 つのプロンプトで全部の道具を振り分けさせる比較テスト

- ルールは依頼の 5 点をそのまま基準の文にする
- 比較テストの場面は、`.github/workflows/semantic-pull-request.yml`（置き場所の答えを含まない `paths` の対象のファイル）を読ませてルールを差し込ませ、そのうえで道具の一覧（名前と走らせるコマンドだけ。置き場所は書かない）を振り分けさせる
- 長所: 置き場所を答えに含むファイル（`lefthook.yml`・`ci.yml`）を読ませないので、今の設定の写しではなくルールでの判断が出る。1 回のプロンプトで全部を照らせ、変更前と変更後を同じ条件で比べられる
- 短所: 道具の性質（何を要るか）は `rule-tester` のモデルの知識に頼る。frontend の道具は手元にないため、コマンドの文だけで判断させる

#### 案 B: 場面を `lefthook.yml`・`ci.yml` の編集にする

- 長所: 本番の場面（設定ファイルを触る）にいちばん近い
- 短所: backend の今の置き場所がファイルに書いてあり、変更前でも写すだけで一致し、ルールの効き目が測れない。frontend の道具は場面に現れない

#### 案 C: 道具ごと・リポジトリごとにプロンプトを分ける

- 長所: 1 件ずつの判断が細かく見える
- 短所: 起動の回数が増え、条件を揃える手間（退避・detach・定義の確認）が回数分かかる。依頼は「全部を振り分けさせる」で、まとめて照らせば足りる

勧め: 案 A。依頼が「ルールだけを読ませて振り分けさせる」ことを求めており、案 B は今の設定を見せてしまう。

### 設計

#### 1. ルールのファイル

- パス: `.claude/rules/lefthook-ci-placement.md`
- frontmatter の `paths`: `"lefthook.yml"`・`".lefthook/**"`・`".github/workflows/**"`
- 見出しは 1 つ（例: `# lefthook と CI への確かめの振り分け`）、本文は箇条書き。節は「CI」「lefthook の段」「lefthook での直し」「変えるとき」程度に分けてよい
- 文の初稿（依頼の文を基準の文として整えるだけ。比較テストの結果で直す）
  - 中身を確かめる物（コードや文書が決まりに合っているか、テストが通るか）は CI に入れ、リポジトリ全体を対象にして必須のチェックにする。CI では直さずに落とす
  - 中身を確かめる必須のチェックは 1 つのワークフローに置き、そのワークフローのまとめ役のジョブ `checks` だけを必須のチェックにする
  - lefthook のどの段に置くかは、速さでなく、その確かめが何を要るかで決める
    - pre-commit: 変えたファイルだけで確かめられる物
    - pre-push: プロジェクト全体は要るが、ビルド・サーバー・ブラウザ・DB は要らない物
    - CI だけ: ビルド・サーバー・ブラウザ・DB が要る物、テストを何度も走らせる物
    - 手元だけ: 手元の状態を見る物
  - lefthook で直すのは、意味を変えないと保証された直しだけにする
  - lefthook か CI のどちらかを変えたら、同じ PR でもう一方にも要るかを確かめる
- 書かない物: 道具の名前、具体例、理由、backend のジョブの中身

#### 2. 照らす表（今決まっている置き場所）

比較テストの答え合わせに使う。ルールの文には書かない。「段」は lefthook の置き場所、「CI」は CI に入るか。

backend（今）

- rubocop: pre-commit（安全な直しの `--autocorrect`）＋ CI
- htmlbeautifier: pre-commit（直す）＋ CI（`--lint-only`）
- debride: **決まっていない**（今は pre-commit で変えたファイルだけ、案は `app config` を渡す。CI は全体）→ ルールでの分かれ方を知らせる
- protect-branch: 手元だけ（pre-commit）
- `check-docs.sh`: pre-commit ＋ CI
- `check-plan-completion.sh`: pre-commit ＋ CI
- `.lefthook/pre-commit/tests/run.sh`・plan-completion のスクリプトのテスト: pre-commit ＋ CI
- check-git-clean: 手元だけ（pre-push）
- rspec: CI だけ（DB）
- semantic-pull-request（Validate PR title）・Related Documents の確かめ: CI だけ（PR のタイトル・本文を見る）

backend（入れる予定）

- SimpleCov: CI だけ（rspec の中で率を書くだけ。合否を返さない）
- Brakeman: **決まっていない**（#836 では CI の job）→ ルールでの分かれ方を知らせる
- Semgrep: **決まっていない**（#837 では CI の job）→ ルールでの分かれ方を知らせる
- CodeQL（`Analyze (ruby)`）: CI だけ（別のワークフロー `codeql.yml`）
- Dependency Review: CI だけ（PR の依存の差分を GitHub で見る）
- code-review-graph: CI だけ（報告だけ。合否を返さない）
- PR の言語の確かめ: CI だけ（PR のタイトル・本文を見る）

frontend（今。#955 の形を決まった置き場所とする）

- biome: pre-commit（safe な直しの `--write`）＋ CI
- markuplint: pre-commit（直さない）＋ CI
- markdownlint: pre-commit（直さない）
- check-logger-trace: pre-commit
- protect-branch: 手元だけ（pre-commit）
- `check-docs.sh`: pre-commit
- knip: pre-push ＋ CI
- `next typegen && tsc --noEmit`: pre-push ＋ CI
- `next build`: CI だけ（ビルド）
- check-git-clean: 手元だけ（pre-push）
- semantic-pull-request: CI だけ

frontend（入れる予定）

- Vitest の全部のテスト: CI だけ。pre-push は関係するテストだけ（`vitest related`）
- Playwright: CI だけ（ブラウザ・サーバー）
- Stryker: CI だけ（テストを何度も走らせる）

照らし方

- 一致を見るのは「段」（pre-commit・pre-push・CI だけ・手元だけ）
- 「CI にも入るか」が決まった形と違う所（例: frontend の markdownlint・check-logger-trace・`check-docs.sh` は CI に無い）は、ルールの 1 点目に照らすと今の設定の側が足りない。ルールの文を直す対象にせず、知らせる物として記録する
- 「lefthook で直すか」の判断（rubocop・htmlbeautifier・biome）は段とは別に記録する。htmlbeautifier の直しが「意味を変えないと保証された」に当たるかは、ルールでどう判断されたかを知らせる（設定は変えない）
- 「決まっていない」道具（debride・Brakeman・Semgrep）は一致を見ず、ルールでどう分かれたかを記録する

#### 3. 比較テスト

- 期待する行動（1 点）: 道具の置き場所を、速さでなく確かめに要る物（変えたファイルだけ／プロジェクト全体／ビルド・サーバー・ブラウザ・DB・テストの繰り返し／手元の状態）で決め、決まっている道具では照らす表の「段」と一致させる
- 場面（案 A）: `.github/workflows/semantic-pull-request.yml` を読んでから、CI と lefthook の置き場所を見直す作業の依頼として、道具の一覧を振り分けさせる。道具の一覧は、リポジトリ（backend・frontend）、道具の名前、走らせるコマンドだけを書き、今の置き場所・ルールの名前・基準の言葉は書かない。各道具に「段」「CI に入れるか・必須にするか」「lefthook で直してよいか」と、根拠を答えさせる
- 手順: `claude-md-maintenance` の「CLAUDE.md・AGENTS.md・rules・skillsの作成・変更時の必須手順」に従う。ただし Gas City の取り決めにより、変更前と変更後の `rule-tester` の起動は、自分の worktree で起動した headless Claude（`claude -p ... --allowedTools "Agent Skill Read Grep Glob"`）の中で行い、git の操作（stash・detach・戻し）は自分のセッションで worktree に対して行う
- 判定: 期待する行動が変更前になく変更後にあるか。変更前でも一致した道具は、そのことを記録する
- 食い違った所: 例を足さずに、基準の文を直して試し直す。直すたびに変更後のテストを同じプロンプトでやり直す。基準の文の直しは依頼の 5 点の意味を変えない範囲に限る。その範囲で直らない食い違いは、直さずに残して知らせる（bead の notes と PR の Notes）
- 予想される食い違いの候補（実際に試して確かめる。ここでは文を先に直さない）
  - Vitest の全部のテスト: ビルド・サーバー・ブラウザ・DB が要らないため、初稿では pre-push に振り分けられうる（決まった形は CI だけ、pre-push は関係するテストだけ）
  - backend の pre-commit のテストの実行（`.lefthook/pre-commit/tests/run.sh` 等）: 「変えたファイルだけ」に当たらず pre-push に振り分けられうる
  - PR のタイトル・本文を見る確かめ・Dependency Review: 初稿の「CI だけ」の条件（ビルド・サーバー・ブラウザ・DB・テストの繰り返し）に当たらない
  - CodeQL: 別のワークフローにあり、5 点目（必須の確かめは 1 つのワークフロー）と合わない。ルールの文ではなく今の設定の側の話として知らせる
- 記録: プロンプト、変更前と変更後の答え、照らした結果、直した文と理由は、`docs/design/plans/` の計画の Decision Log と PR の Testing に書く（ルールには書かない）。比較テストの前の状態に混ざらないよう、計画のコミットはテストの detach の基準より後に置くか、テスト対象と同じ最初のコミットに含めて detach の基準にする

#### 4. 失敗と止め方

- `rule-tester` の定義・ガードが今の版で動いていることを、手順どおり引用で確かめる。ずれたら `touch` して 35 秒以上おいて確かめ直す
- ルールが差し込まれなかった（答えの根拠に基準が現れない）ときは、場面のファイルの読み方を見直す。差し込みの有無そのものは `rule-tester` では確かめられない（`docs/decisions/rule-and-hook-change-tests.md`）ので、答えの内容から判断する
- 変更後にも期待する行動が出ない文は、`claude-md-maintenance` の判定どおりノイズとして取り消す。ただし依頼の 5 点そのものを全部取り消す結果になるときは、取り消さずに残して人に知らせる（依頼が文の存在を求めているため）

#### 5. 変更時の確認

- `claude-md-maintenance` の「変更時の確認」に従い、新しいルールの用語と重なる記述を `grep` で洗い出す（`hooks-authoring.md`・`scripts-authoring.md`・`AGENTS.md`・skill）。食い違う記述があれば知らせる（このbuildで直すのは新しいルールだけ）

### 受け入れの基準

1. `.claude/rules/lefthook-ci-placement.md` があり、`paths` がちょうど `lefthook.yml`・`.lefthook/**`・`.github/workflows/**` の 3 つ
2. 本文が依頼の 5 点（4 点 ＋ `checks` の 1 点）を基準の文として持ち、道具の名前・具体例・理由・強調語を含まない
3. `hooks-authoring.md` は変わっていない
4. 比較テストを `claude-md-maintenance` の手順（Gas City の取り決めの読み替えを含む）で行い、期待する行動が変更前になく変更後にある。照らす表の「段」と変更後の答えが、決まっている道具で一致する。一致しない物は、文を直して試し直した記録と、残った理由がある
5. debride・Brakeman・Semgrep がルールでどう分かれたか（段・CI・直すか）が、bead の notes と PR に書かれている
6. 今の設定とルールの食い違い（frontend の CI に無い確かめ、CodeQL の別ワークフロー、htmlbeautifier の直しの判断 等）が、直されずに知らせとして書かれている
7. 理由・比較テストの記録が `docs/design/plans/` の計画の Decision Log と PR の Testing にあり、ルールには無い
8. `lefthook.yml`・`.lefthook/**`・`.github/workflows/**` の中身は変わっていない

### 仮定（bead にも書く）

- frontend の「今決まっている置き場所」は、開いている #955 の形（markuplint は直さない、pre-push に `next typegen && tsc --noEmit`）とする。#955 は決定の記録を Accepted で持つため
- 5 点目の「必須にする確かめ」は中身を確かめる物に限る。人の mail が Validate PR title も必須に登録すると書いており、PR のタイトルの確かめは別のワークフローのままでよいため
- 「入れる予定の道具」は、backend の開いている PR・枝（#836・#837・#839・#840・`ci/check-pr-language`・`build/debride-full-scope`）と、frontend の #947 の試しに出た Vitest・Playwright・Stryker とする
- SimpleCov・code-review-graph は合否を返さない報告のため、「必須にする確かめ」ではなく CI だけの報告として照らす

### 残る問い

- 人の答えが要る問いはない（上の仮定で進める）
- 比較テストで「依頼の 5 点の意味を変えない範囲」で直らない食い違いが残った場合、その扱い（基準を変えるか、置き場所を変えるか）は人が決める。build の中では残して知らせる

### 自律で進める根拠

- 依頼の原文がルールの中身（5 点）・`paths`・別ファイルにすること・テストの方法・知らせる物を決めており、設計で選ぶ余地は、ファイル名、比較テストの場面の作り方、照らす表の作り方、記録の置き場所だけ
- それらは、リポジトリの決まり（`claude-md-maintenance`・`docs/decisions/rule-and-hook-change-tests.md`）と Gas City の取り決め（worktree の headless Claude での比較テスト）から決まる
- 曖昧な所は「仮定」に書き、どれも依頼の文の範囲を広げない

