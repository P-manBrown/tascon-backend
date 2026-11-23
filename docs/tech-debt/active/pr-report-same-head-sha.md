# PRへの報告が、同じhead SHAのPRを区別しない
- **Status:** Open
- **Priority:** Low
- **Category:** Bug
- **Area:** `.github/workflows/report.yml`
- **Detected:** 2026-11-22
- **Description:** `report.yml`は、`workflow_run`の`head_sha`から、そのコミットを先頭に持つ開いたPRを`first`で1つ選び、成果物もそのSHAの`pull_request`のすべての実行から集める。同じhead SHAのPRが2つ開いている（同じブランチからbaseの違うPRを開いた）と、別のPRにコメントを書いたり、2つのPRの成果物を混ぜたりしうる。`rspec`はPRのマージコミットでテストするため、head SHAが同じでもbaseが違えば率も違いうる。PR #836 のレビューでCodexが指摘し、このリポジトリのスタックではブランチごとにSHAが違い起きないため、対処せず、起きたらその時に直すと決めた（計画`docs/design/plans/active/test-and-check-tools-ci.md`のDecision Log）。
- **Impact:** 起きると、PRに別のPRのカバレッジなどの報告が載る、または2つのPRの報告が混ざって載る。合否には関わらない（`report.yml`は必須のチェックではない）。
- **Proposed Resolution:** `workflow_run`の`pull_requests`からPR番号を取り、成果物を集める実行も、その番号のPRの実行だけに絞る。forkからのPRでは`pull_requests`が空になるため、その場合の扱い（今と同じSHAでの検索に戻す、または書かない）を決める。
- **Related:** PR #836（https://github.com/P-manBrown/tascon-backend/pull/836）、`docs/design/plans/active/test-and-check-tools-ci.md`
