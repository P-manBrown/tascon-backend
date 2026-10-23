---
paths:
  - ".claude/settings.json"
  - ".claude/hooks/**"
---

# フック設計時の注意

- `Stop`/`SubagentStop`で`hookSpecificOutput.additionalContext`を返すと、そのターンは継続扱いになり停止しない。無条件に注入する設計は無限ループを招く
- `Stop`/`SubagentStop`で判定込みの確認をさせたい場合、判定をフックに持たせない。`type: "command"`で`decision: block`を返して1回だけ止め、確認の内容を`reason`で渡して、会話全体を持つメインエージェントに判断させる
- `type: "command"`で`Stop`/`SubagentStop`を扱う場合は、入力JSONの`stop_hook_active`を確認し、`true`なら何も出力せず終了する(無限ループ防止)
- hookスクリプトはシェルスクリプトを優先する。追加インタプリタへの依存は避ける

## 作成・変更時の確認

hookスクリプト、または`settings.json`のhookの登録を作成・変更したら、コミット前に次を確かめる。

- 発火すべき入力のJSONをstdinへ与えてスクリプトを直接実行し、出力と終了コードが想定どおりになる
- 発火すべきでない入力（matcherの対象外、`stop_hook_active`が`true`等）では何も出力しない
- `settings.json`へ登録した状態の実セッションで、想定した場面に発火する
