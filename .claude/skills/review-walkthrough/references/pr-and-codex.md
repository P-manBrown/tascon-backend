# PRのURLとCodexレビュー

- 「公式機能」はツールが提供する機能、「スクリプト」はここに書いたコマンドの組み合わせを指す

## PRのURL

- スタックの各ブランチのPR URL（公式機能）: `git-spice log long --json`の各ブランチの`change.url`。スタックの下（`main`に近い側）から順に並べるには、`down`をたどる
- 1つのPRのURL（公式機能）: `gh pr view <PR番号> --json url`

## Codexレビュー

- 実行（公式機能）: レビュー対象のworktreeの中で、SKILL.mdの「対象diffの特定」で決めた対象と比較元に合わせて次を実行する
  - ブランチ: `codex review --base <比較元>`
  - 未コミットの変更: `codex review --uncommitted`
  - コミット範囲: 範囲の終点のコミットへ移り、`codex review --base <始点>`
- 実行はworktreeの中だけで行い、メインのcheckoutではブランチを切り替えない
