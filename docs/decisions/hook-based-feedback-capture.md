# フックによるfeedback捕捉・plan完了検知の設計

## 背景

claude-mem導入を機に、ユーザーからの訂正・決定をCLAUDE.md/rules/skills/`.claude/memory/`へ反映するタイミングを検討した。当初はStop/PostToolUseフックによるリアルタイム自動反映を試みたが、以下の問題が生じた。

## リアルタイム自動反映を廃止した経緯

- `Stop`フックの`hookSpecificOutput.additionalContext`は、返すとそのターンを継続扱いにする仕様（ドキュメント上「continues the conversation」と明記）。無条件に注入する設計は無限ループを招いた
- `type: "prompt"`による判定型に切り替えても、判定モデルがClaude自身の説明・自己解説を人間の訂正と誤認する自己言及誤判定が複数回発生した
- `PostToolUse(Agent)`でサブエージェント完了を捉える設計も試みたが、実際に検証した結果、この環境の`Agent`ツールは非同期起動がデフォルトで、`PostToolUse(Agent)`は起動直後に発火することが判明した。サブエージェント完了は`task-notification`として新しいターンに届き、それを処理したターンの末尾で通常の`Stop`が発火する

これらの実装上の不安定さに加え、ドキュメントは人間とClaude間のコミュニケーションツールであり、その確定には人間のレビューを経るべきという判断から、リアルタイム自動反映の方針自体を撤回した。

## 現在の方針

- CLAUDE.md/rules/skills/`.claude/memory/`への反映は、`execution-plan`の完了処理（そのplanに関わる全ブランチがmainへマージ完了した時点）にまとめて行う。人間のPRレビューを経た後という位置づけになる
- 完了処理内でclaude-memを照会し、そのplan期間中の決定・教訓に記録漏れがないか監査する。照会範囲は、plan内に記録したworktree絶対パス（サブエージェントの`isolation: "worktree"`起動時に払い出される、`.claude/worktrees/agent-<agentId>`形式のパス）から解決されるclaude-memの`project`識別子に絞る。これは時刻ではなくworktree単位でスコープを切ることで、人間のレビュー待ちで完了処理が遅延しても並行作業と混ざらないようにするため
- plan内の`Decision Log`セクションへの記録は従来通り即時（`execution-plan` SKILL.md既存ルール）。これは対象が「plan単体の作業記録」であり、CLAUDE.md/rules/skills等プロジェクト全体への昇格とは別工程のため、遅らせる理由がない
- claude-memの`CLAUDE_MEM_SKIP_TOOLS`はデフォルトで`AskUserQuestion`を観測対象から除外する。これを除外したままだと、`AskUserQuestion`経由の決定は即時反映（`PostToolUse(AskUserQuestion)`フック）が機能しなかった場合にclaude-mem監査でも救えない。`compose.devcontainer.yml`で`AskUserQuestion`を除いたリストへ上書きしている

## plan完了検知の一般化

`.claude/plans/active/`から`.claude/plans/completed/`への移動検知は、当初`git mv`/`mv`コマンドのパターンマッチのみだったが、`cp`・`rsync`等の他の移動手段や`Write`ツールでの直接作成を取りこぼすため、`plans/active/`と`plans/completed/`双方がコマンド中に現れるかという判定と、`Write`ツールでの`plans/completed/`配下への直接作成検知を追加した。

## rules遵守確認フックの一般化

当初は`.claude/rules/`・`.claude/skills/`配下の編集のみを対象にした専用チェックだったが、`.claude/rules/*.md`各ファイルのfrontmatter`paths:`に一致する変更全般を対象にする汎用チェックへ拡張した（`claude-md-maintenance.md`自身の`paths`に`.claude/rules/**/*.md`等が含まれるため、専用チェックはこの汎用チェックに包含される）。

実装は当初Pythonで`**`globパターンをマッチさせていたが、実行環境にPythonが存在する保証がないため、bashの`[[ $str =~ $regex ]]`（正規表現マッチ）による実装へ書き直した。
