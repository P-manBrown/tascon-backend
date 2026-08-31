@AGENTS.md

## 実装の委譲

- plan承認後の実装（ファイル編集・コミット作成）→Edit/Writeで直接行わず、`codex:codex-rescue`等のCodexへ委譲
- 1行修正も例外なくCodexへ委譲
- Claudeが直接編集可能→planファイル（`.claude/plans/`）、memoryファイル、docs（`docs/`）、Bruno CLI検証用の一時リクエストのみ
- `app/`、`config/`、`db/`等のプロダクションコード→Claudeによる直接編集禁止
