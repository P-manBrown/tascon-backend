---
paths:
  - ".claude/settings.json"
  - ".claude/hooks/**"
  - ".claude/skills/**/scripts/**"
  - ".lefthook/**"
  - "lefthook.yml"
---

# スクリプトで使う言語・コマンド

- スクリプトは、このプロジェクトの環境で明示的に入れてある言語・コマンドだけを使って書く
- 基本はシェル（bash）で書く。処理が込み入るときは、このプロジェクトで明示的に入れてある言語で書いてよい
- 言語・コマンドを使う前に、次のどこで入れているかを確かめる
  - `.devcontainer/devcontainer.json`のfeatures
  - ベースイメージ・Dockerfileで入れているもの
  - Feature `common-utils`を入れている場合は、それが入れるもの
  - パッケージの管理ファイルで宣言した道具
- ほかの道具の依存として入っているだけのものは使わない
