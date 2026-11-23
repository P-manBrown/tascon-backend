---
paths:
  - ".github/workflows/**"
---

# GitHub Actionsのワークフローの書き方

## PRへの報告

- 合否を決めない報告（カバレッジの率など）は、名前が`pr-report-<2桁の順>-<中身>`の短いMarkdownの成果物として残すだけにする。PRへのコメントは、まとめ役の`.github/workflows/report.yml`だけが書く。報告を残すjobには`pull-requests: write`を付けない
- 今あるワークフローに報告を足すときは、成果物を残すステップを足すだけにする。新しいワークフローで報告を残すときだけ、`report.yml`の`workflows`に、そのワークフローの名前を1行足す
