# hooks-authoringのStop/SubagentStopの判定の記述を今の方式に合わせる

## Context/Purpose

`.claude/rules/hooks-authoring.md`の「フック設計時の注意」に、Stop/SubagentStopで判定込みの指示を出すときは、`type: "command"`で単純に注入せず、判定を`type: "prompt"`に任せる、という行がある。この行は2026-09-04、無限ループの対処としてprompt hookへ切り替えた直後に書かれた。その後、prompt hookは判定モデルがClaude自身の説明を人間の訂正と取り違える誤判定を起こし、撤回された（`docs/decisions/feedback-reflection-timing.md`・`docs/decisions/reminder-hooks-removal.md`）。今の`record-check.sh`は、`type: "command"`で`decision: block`により1回止め、判定を会話全体を持つメインのエージェントに任せている（`docs/decisions/record-check-and-completion-reflection.md`）。ルールの行だけが見直されず、退けた方式を勧めたまま残っている。

## 合意した方針

- `hooks-authoring.md`の該当行を、判定をフックに持たせず、`decision: block`で1回止めてメインのエージェントに判断させる、という今の方式に書き換える
- 理由・経緯はルールに書かず、decisionとこのplanに任せる

## Progress

- [x] Step1: `hooks-authoring.md`の該当行を書き換え、`claude-md-maintenance`の比較テストを行う
  - 行の書き換えをCodexへ委譲した（このplanとともに未コミット。ブランチは比較テストの後、スタックの最上段`docs/complete-todoist-task-runner-plan`の上に作る）
  - 比較テストを終えた（検証結果）。行動は変更前から期待どおりだったが、Decision Logのとおり食い違いの解消として変更を残す

## 検証結果

- Step1の比較テスト（2026-10-23、対象: `hooks-authoring.md`、変更とplanは未コミットのためdetachなし）: 「`.claude/hooks/rubocop-on-edit.sh`を読んでhookの書き方を把握し、ターンの終わりにユーザーがコーディング規約に関わる指摘をしたかを判定してrulesへの反映を促すStopフックを足したい。hookのtypeと判定の場所を決めて設計を答えて」を問い、期待する行動を「`type: "command"`で`decision: block`により1回止め、判定はメインのエージェントに任せる」とした。どちらも`hooks-authoring`は`rubocop-on-edit.sh`のReadで差し込まれていた
  - 変更前: `type: "command"`で判定は本体に任せ、新しいフックではなく`record-check.sh`の`reason`の書き足しを勧めた。根拠は`docs/decisions/`の3件（prompt hookの誤判定、無限ループ、注入型の廃止）と`record-check.sh`。あわせて、`hooks-authoring`の「判定は`type: "prompt"`に任せる」がdecisionと食い違っており、どちらに揃えるか判断が要ると挙げた
  - 変更後: 同じ設計を答え、根拠に`docs/decisions/`の3件に加えて`hooks-authoring`の新しい行を挙げ、食い違いの指摘はなくなった
  - 期待する行動は変更前にもあったため、判定ではノイズにあたる。食い違いの解消として変更を残す（Decision Log）。変更前は、決定の記録を読みに行けば正しい設計にたどり着くが、ルールとの食い違いの判断をユーザーへ戻していた

## Decision Log

- 2026-10-23: `hooks-authoring.md`の、判定を`type: "prompt"`に任せる行は、今の方式（`decision: block`で1回止め、メインのエージェントに判断させる）に合わせて書き換える（ユーザー同意）。prompt hookは自己言及の誤判定で撤回済みで、今の方式で無限ループも誤判定も起きていない。残る弱点は、メインのエージェントが記録の要否を見落とすことで、方式ではなく判断の精度の問題のため。ルールは今の正しい手順だけを書く場所で、退けた方式を勧める行は新しいhookを作るときにpromptへ誘導する
- 2026-10-23: 比較テストで行動が変わらなくても、変更は取り消さない。ルールの追加ではなく、decisionとの食い違いの解消のため（`plan-work-records`の2026-10-20の決定と同じ扱い）

## Validation and Acceptance

- `hooks-authoring.md`に、判定を`type: "prompt"`に任せる記述がなく、`decision: block`で1回止めてメインのエージェントに判断させる記述がある
- `claude-md-maintenance`ルールの比較テストを行い、結果を検証結果に記録している
