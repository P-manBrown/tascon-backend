---
paths:
  - ".claude/settings.json"
  - ".claude/hooks/**"
---

# フック設計時の注意

- `Stop`/`SubagentStop`で`hookSpecificOutput.additionalContext`を返すと、そのターンは継続扱いになり停止しない。無条件に注入する設計は無限ループを招く
- `Stop`/`SubagentStop`で判定込みの指示を注入したい場合、`type: "command"`で単純に注入する設計は避ける。判定自体は`type: "prompt"`(裏側の軽量モデル呼び出し)に任せ、該当時のみ`reason`をメインエージェントへ渡して可視ターンを発生させる
- `type: "command"`で`Stop`/`SubagentStop`を扱う場合は、入力JSONの`stop_hook_active`を確認し、`true`なら何も出力せず終了する(無限ループ防止)
- hookスクリプトはシェルスクリプトを優先する。追加インタプリタへの依存は避ける
