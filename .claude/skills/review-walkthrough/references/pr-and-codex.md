# PRのURLとCodexレビュー

- 「公式機能」はツールが提供する機能、「スクリプト」はここに書いたコマンドの組み合わせを指す

## PRのURL

- スタックの各ブランチのPR URL（公式機能）: `git-spice log long --json`の各ブランチの`change.url`。スタックの下（`main`に近い側）から順に並べるには、`down`をたどる
- 1つのPRのURL（公式機能）: `gh pr view <PR番号> --json url`

## Codexレビュー

- 実行（公式機能）: レビュー対象のworktreeの中で`codex review --base <親ブランチ>`を実行する。`<親ブランチ>`は`git-spice log short`で確かめたスタック上の親
- 実行はworktreeの中だけで行い、メインのcheckoutではブランチを切り替えない
