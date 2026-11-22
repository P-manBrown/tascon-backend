# 既存のワークフローがActionをタグで参照している
- **Status:** Open
- **Priority:** Medium
- **Category:** Security
- **Area:** `.github/workflows/ci.yml`、`.github/workflows/related-documents.yml`、`.github/workflows/semantic-pull-request.yml`
- **Detected:** 2026-11-22
- **Description:** 既存のワークフローの`uses:`14か所が、40桁のコミットのSHAでなくタグで参照している。`ci.yml`の`actions/checkout@v7`8か所と`actions/cache@v6`4か所、`related-documents.yml`の`actions/checkout@v7`、`semantic-pull-request.yml`の`amannn/action-semantic-pull-request@v5`。一方、テストと確かめの道具をCIに入れる計画（`docs/design/plans/active/test-and-check-tools-ci.md`）で新しく足した`uses:`は、SHAと版のコメントで固定しており、同じファイルの中で書き方が混ざっている。この計画は既存のタグ参照を書き換えないと決めて範囲外にした（仕様`docs/design/specs/test-and-check-tools-ci.md`のREQ-003）。
- **Impact:** タグは付け替えられるため、Actionの作者のアカウントが乗っ取られると、同じタグのまま中身を差し替えられ、CIで任意のコードが動く（2025年のtj-actions/changed-filesの例）。`ci.yml`のjob`rspec`は`secrets.RAILS_MASTER_KEY`を環境変数に持ったままタグ参照の`actions/checkout`・`actions/cache`を動かすため、マスターキーを外へ送られうる。`amannn/action-semantic-pull-request`は第三者のActionで危険が高い。各ワークフローのトークンの権限は読み取りだけ（`contents: read`、`pull-requests: read`）。
- **Proposed Resolution:** 14か所をすべて40桁のSHAと行末の版のコメントに置き換える。`main`から切った別のPRで行う。更新は`.github/dependabot.yml`の`github-actions`（PR #836 で追加）に任せる。書き方が揃えば、新しいワークフローも既存の書き方にならって固定される。2026-11-22に「`uses:`はSHAで固定する」をルール（`.claude/rules/lefthook-ci-placement.md`）に足す案を比較テストしたが、変更前から新しい`uses:`をSHAで固定したため、ルールを足しても行動が変わらず、ルールは足さなかった。決まりを確実に守らせたいなら、`uses:`がSHAでない行があれば落ちる確かめをCIの`checks`に足す。
- **Related:** PR #836（https://github.com/P-manBrown/tascon-backend/pull/836）、`docs/design/plans/active/test-and-check-tools-ci.md`、`docs/design/specs/test-and-check-tools-ci.md`
