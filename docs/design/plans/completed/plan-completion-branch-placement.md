# planの完了処理のブランチをスタックの下側に挿入する

## Context/Purpose

`git-spice-workflow` skillは、新しい作業のブランチを未マージのスタックの最上段に積むと定めている。planの完了処理のブランチもこれに従って最上段に積まれ、上に未レビューの作業が積み上がっているほど、完了処理の変更がmainへ入るのが遅れる。完了処理の変更は、マージ済みのplanの記録を閉じるだけで、上に積まれた作業に依存しない。そこで、完了処理のブランチはスタックのmainに近い側へ挿入する。

## 合意した方針

- 完了処理のブランチは、PR作成済みのブランチのうち最上段のものの直上へ挿入する。PR作成済みのブランチがなければ`main`の直上に挿入する
- 挿入後に上の段をrestackしたら、そのうちpush済みのブランチをpushし直す
- `git-spice-workflow`の「最上段に積む」の例外として書き、`execution-plan`の完了処理からそれを参照する

## Progress

- [x] Step1: `git-spice-workflow`と`execution-plan`を書き換え、`claude-md-maintenance`の比較テストを行う
  - 比較テストを終えた（検証結果）。ブランチはユーザーの指示で`docs/hooks-authoring-stop-judgment`（#747）と`docs/notification-architecture`の間に挿入した

## 検証結果

- Step1の比較テスト（2026-10-24、対象: `git-spice-workflow`・`execution-plan`のSKILL.md、変更は未コミットのためdetachなし）: 「planに関わる全ブランチがmainにマージされたので、そのplanの完了処理を行う。完了処理の変更をコミットするブランチをスタックのどこに作るか、作成コマンドと、作成・コミット後に必要な操作を答えて。コマンドは実行しない。今のスタック（下から）: main ← docs/a（#801、PR作成済み） ← docs/b（#802、PR作成済み） ← feat/c（push済み、PR未作成） ← feat/d（未push）。今いるブランチはfeat/d。」を問い、期待する行動を「docs/bの直上へ`--insert`で挿入する」とした。変更前・変更後とも、プロンプトの前にSkillツールで両skillの該当箇所を引用させ、作業ツリーの内容と一致することを確かめた
  - 変更前: 最上段（feat/dの上）に積み、`--insert`で途中に挟まないと答えた
  - 変更後: docs/bの直上へ`--insert --no-commit --no-restack`で挿入し、コミット後にrestackしてpush済みのfeat/cだけをpushし直すと答えた
  - 期待する行動は変更後にだけ現れた
- 未確認: push済み・PR未作成のブランチの下へ挿入してpushし直す操作は、該当するブランチがまだないため実際には行っていない

## Decision Log

- 2026-10-24: 完了処理のブランチは、PR作成済みのブランチの下ではなく上に挿入する（ユーザー同意）。下に挿入すると、PR作成済みのブランチの土台が変わり、rebase・force push・CI再実行が要る。PRのマージ先も変わり、完了処理のPRが通るまでマージ待ちのPRを止める。完了処理はplanのブランチがmainへマージされた時点で行うため、別のPR群をマージしている途中に重なりうる
- 2026-10-24: 境界はpushの有無ではなくPR作成の有無にする（ユーザー同意）。今後オーケストレーター等でエージェントが自律的に作業すると、レビューが追いつかずPR未作成のブランチが長く残りうる。ローカルの故障で作業を失わないよう、PR作成前でもpushしておく運用を見込む。PR未作成のブランチは、push済みでもCI（`pull_request`のみで起動）が走らず、レビュー中の差分もないため、下に挿入してpushし直すコストが小さい

## Validation and Acceptance

- `git-spice-workflow`に、完了処理のブランチをPR作成済みのブランチのうち最上段のものの直上（なければ`main`の直上）へ挿入し、restack後にpush済みのブランチをpushし直す記述がある
- `execution-plan`の完了処理から、その記述を参照している
- `claude-md-maintenance`ルールの比較テストを行い、結果を検証結果に記録している
