# ルール・skill・hookを変更したときのテストの方法

- **Status:** Accepted
- **Verification Status:** Verified
- **Date:** 2026-10-22
- **Related Files:** `.claude/rules/claude-md-maintenance.md`, `.claude/rules/hooks-authoring.md`, `.claude/agents/rule-tester.md`, `.claude/hooks/rule-tester-guard.sh`

## Context

`.claude/CLAUDE.md`・`AGENTS.md`・rules・skillは、書き足しても、それを読んだエージェントの行動が変わるとは限らない。行動が変わらない記述はノイズとして文脈を圧迫する。そこで、変更の前後で同じプロンプトを与え、行動が変わるかを確かめる比較テストを行っている。

比較テストは、条件を揃えないと結果が当てにならない。実際に、次のことで変更前のテストが汚れた。

- 個人のmemoryが入り、memoryで正しく動いたため、必要な記述をノイズと判定しかけた
- 変更の意図を先に書いてコミットしたplan・Decision Logを、変更前のエージェントが読んで答えた
- サブエージェントの文脈に入るgitStatus（ブランチ名・直近のコミット）から、変更内容を推測された
- 読み込みを制限する指示を、エージェントが守らなかった
- エージェント定義・SKILL.mdを書き換えた直後に起動すると、書き換え前の内容で動いた

hookは入力に対して決まった出力を返すため、モデルの解釈の差を見る比較テストでは確かめられない。

## Decision

比較テストで確かめるのは「共有された条件で作業するエージェントの行動が、その記述で変わるか」とし、次の条件で行う。

- 専用のサブエージェント`rule-tester`（`omitClaudeMd: true`）で行う。memoryと個人の設定は入れず、`.claude/CLAUDE.md`・`AGENTS.md`は定義の指示でReadさせる
- 混ぜてはいけないもの: memory、テスト対象の変更そのものの記録（plan・Decision Log・検証結果。コミット済みでも）、変更した人の会話の文脈。あってよいもの: `CLAUDE.md`・`AGENTS.md`、本番と同じ経路で読み込まれるほかのルール・skill・コード
- `rule-tester`の読み込みの制限は、定義の`hooks`（`rule-tester-guard.sh`）で強制する。`.claude/rules/`・`.claude/skills/`・`.claude/plans/`・`.claude/memory/`のRead、それらを含む範囲のGrep・Globを拒否し、ルールは`paths`による差し込み、skillはSkillツールでだけ使わせる。ガードを実行できないときはRead・Grep・Globを止める
- 変更前の状態は、テスト対象以外の未コミット変更を退避し、メインのcheckoutをテスト対象の変更の最初のコミットの1つ前へdetachして作る。worktreeは使わない（`paths`で差し込まれるルールはメインのcheckoutのファイルのため）。変更内容を表すブランチはテストの後に作る
- 起動の前に、`rule-tester`の定義・Skillツールが返す内容が想定した版であることを引用させて確かめ、ずれていれば`touch`してから確かめ直す
- `rule-tester`で場面を作れないとき（`paths`が`.claude/plans/`だけのルール等）も、テストしないまま変更を残さない。ガードは`.claude/plans/rule-test-fixture.md`の1ファイルだけReadを通し、テストの時だけそこに中身のないダミーのplanを置く
- 判定は、テストの前に決めた期待する行動が、変更前になく変更後にあるかだけで行う。人が読むための明確化は、行動が変わらなくても残してよい

hookの変更は、比較テストではなく、入力JSONをstdinへ与えたスクリプトの直接実行（発火すべき入力・発火すべきでない入力）と、`settings.json`へ登録した実セッションでの発火で確かめる。

## Considered Options

- **`claude -p`のヘッドレスセッション**: サブスクリプションと別料金になるおそれがある
- **Agentツールの通常のサブエージェント**: 個人のmemoryが入る
- **`isolation: "worktree"`で変更前を作る**: worktreeは既定でmainから作られ、差し込まれるルールはメインのcheckoutのファイルのため、変更前を再現できない
- **`git stash`だけで変更前を作る**: コミット済みの記録とgitStatusから変更内容が漏れる
- **エージェント定義の`omitGitStatus`・`env`でgitStatusを外す**: 試したが外れなかった
- **読み込みの制限を定義の指示だけで行う**: 守られなかった
- **採用: `rule-tester`＋ガードのフック＋detachによる変更前の状態**

## Consequences

- 比較テストのたびに、退避・detach・定義の確認の手間がかかる
- `rule-tester`はルール・skillが読み込まれるか（`paths`・description）自体は確かめられない。自分から読みに行くと、本番で読み込まれない場面でも内容を知るため
- 定義・SKILL.mdがファイルの変更から遅れて読み込み直される仕組みは確かめておらず、引用による確認で補っている
