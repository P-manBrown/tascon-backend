@AGENTS.md

## 実装の委譲

- execution-planに記載された実装タスクを進める際（コード変更、それに伴うdocs/ARCHITECTURE.md更新を含む）→Edit/Writeで直接行わず、`codex:codex-rescue`等のCodexへ委譲
- 1行修正も例外なくCodexへ委譲
- 上記に該当しない、ハーネス自体の運用・設計に関する作業（plan文書自体の作成・更新、memoryファイル、`.claude/`配下のハーネス設定ファイル（skills/rules/settings/hooks等）、Bruno CLI検証用の一時リクエスト）→Claudeが直接編集可能
