# diffの見方

- 「公式機能」はツールが提供する機能、「スクリプト」はここに書いたコマンドの組み合わせを指す
- 「未確認」は、公式ドキュメント等で確かめられなかった点を指す

## 親ブランチとのdiff（CLI）

- 親ブランチの確かめ方（公式機能）: `git-spice log short`で現在のスタックを表示し、対象ブランチの1段下を親とする。追跡中の全ブランチは`git-spice log short --all`で表示する
- 親ブランチとのdiff（公式機能）: `git-spice branch diff`で現在のブランチ、`git-spice branch diff --branch <ブランチ>`で指定したブランチと親の差分を表示する。`git diff <親>...<ブランチ>`と同じ範囲になる
- 変更ファイルの一覧（公式機能）: `git diff --stat <親>...<ブランチ>`
- git-spiceで追跡していないブランチ（スクリプト）: PRがあれば`gh pr view <PR番号> --json baseRefName`でPRのbaseを確かめ、`git diff <base>...<ブランチ>`で見る。PRも無ければ`git diff main...<ブランチ>`で`main`とのmerge-baseからの差分を見る。`<base>`はローカルのrefを指すため、ローカルの`<base>`が古い可能性がある、またはリモートにしか無いときは、`git fetch origin <base>`してから`origin/<base>`を使う

## Claude Code CLIの`/diff`

- できること（公式機能）: 作業ツリーの未コミット変更（Claudeの編集と、それ以外の未コミット変更）を表示する。fullscreen rendererではdiff panel、classic rendererではdiff dialogで開く
- できること（公式機能）: Claudeがファイルを編集した後は、ターンごとの編集を表示する。ターンごとの表示はClaudeのファイル編集に基づき、シェルコマンドで変えた内容は`Current`（作業ツリー）にだけ出る
- できないこと: 比較元のブランチ・コミットを指定した表示、コミット済みの変更（親ブランチとの差分）の表示。公式ドキュメント（2026-10-29確認）に方法の記載が無い。未確認
- 親ブランチとの差分を会話内で見る（スクリプト）: プロンプトで`!git-spice branch diff`を実行し、出力を会話に出す

## Zed（ホスト側からDev Containerを開いた状態）

- できること（公式機能）: Project Diff（コマンドパレットの`git: diff`、またはGit Panel）で、gitが捉えている変更を一覧し、hunk・ファイル単位でstage/unstageする
- できること（公式機能）: File Historyで1ファイルのコミット履歴を表示し、コミットを選ぶとそのコミットでのそのファイルの差分を表示する
- できないこと: 親ブランチとコミット済みの変更を比較する表示。公式ドキュメント（2026-10-29確認）に記載が無い。未確認
- Dev Container越しに上記が動くこと: コンテナ内から確かめられない。未確認
- 親ブランチとの差分を見る（スクリプト）: Zedのターミナルで`git-spice branch diff`を実行する。ターミナルがコンテナ内で動くことは未確認
