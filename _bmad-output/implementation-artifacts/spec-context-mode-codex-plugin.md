---
title: 'context-modeのCodex導入をプラグイン方式に統一'
type: 'chore'
created: '2026-11-12'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

Claude Codeと同じくcontext-modeをマーケットプレイスのプラグインとしてCodexに登録する。npm版の直接導入と手動MCP・hook登録を取り除き、プラグインからMCP・hook・skillを読み込む。codebase-memory-mcpとclaude-memは変更しない。

</frozen-after-approval>

## Implementation Notes

- 作業前のツリーはクリーン。現在のブランチはCodex連携の設定を含む`chore/codex-claude-mem`。
- `.devcontainer/postCreateCommand.sh`のcontext-mode直接導入だけを削除する。Claude Codeと同様にユーザー設定としてプラグインを登録し、Codex Featureの設定volumeに保持する。
- 実環境の`~/.codex/config.toml`からcontext-modeの手動MCP設定、`~/.codex/hooks.json`から同ツールの直接登録hookだけを削除する。他ツールの設定は保持する。
- 上流READMEのプラグイン手順と実機CLIを確認済み。`hooks`は有効、`plugin_hooks`は削除済み機能なので追加しない。
- 検証はシェル構文、プラグイン登録・手動設定の除去、プラグインMCPの初期化と診断、hookの実行を対象とする。
- プラグイン`context-mode@context-mode` 2.1.8を登録。MCP初期化・`ctx_stats`は成功。`ctx_doctor`はhook信頼承認のD5のみFAIL、他の項目はPASS。SessionStart hook本体の直接実行は終了コード0で、追加文脈を返した。Codex経由のhook実行はユーザー承認後に確認が必要。
- `bash -n .devcontainer/postCreateCommand.sh`・`git diff --check`は成功。バックアップとの比較で、context-mode手動MCP以外のTOML設定とRTK hookの保持を確認。
- 新しいCodex設定volumeへの導入手順: `codex plugin marketplace add mksglu/context-mode`、続けて`codex plugin add context-mode@context-mode`。Codexを再起動し、プラグインhookの承認が表示されたら内容を確認して承認する。`ctx_doctor`のD5がPASSになることと実セッションのhook実行を確認する。既存の設定volumeでは登録済みプラグインが保持される。

## Review Triage Log

- medium: hookの信頼承認が未完了で、直接実行はCodex経由の動作を証明しない。実測でもD5がFAIL。信頼状態を書き換えず、再起動後の承認・検証が残ることを明記する。
- low: 新しい設定volumeへの導入手順が欠けていた。上記にマーケットプレイス登録、プラグイン追加、hook承認、検証の手順を追記した。
