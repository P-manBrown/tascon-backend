---
name: project-setup
description: 新しく取り出したリポジトリやworktreeで、git-spiceの設定をし、依存をインストールするskill。セッション開始時とサブエージェント開始時に自動で実行される。手で実行するのは、clone直後、worktree作成後、依存（Gemfile等）を変えた後。
---

# project-setup

`scripts/setup.sh`を、clone直後、worktreeを作った後、依存を変えた後に実行する。SessionStart（起動時のみ）とSubagentStartのhookからも自動で実行される。手で実行するときは現在のディレクトリのリポジトリに対して動き、標準入力は読まない。

```bash
bash .claude/skills/project-setup/scripts/setup.sh
```

- リポジトリのlocalのgitの設定に、git-spiceのネイティブのスタック・マージのコマンド・squashでのマージの設定を入れる。OSによらず行い、値が既に同じなら書き換えない
- 依存のインストールはLinuxでのみ行う。それ以外のOSでは設定だけをして終了コード0で終わる
- 依存がそろっていれば、すぐ終わる
- 成功時は標準出力に何も出さない。失敗時は理由を出して0以外で終わる
