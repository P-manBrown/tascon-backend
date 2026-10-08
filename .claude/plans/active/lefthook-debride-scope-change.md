# lefthook debrideフックのスコープ変更（未着手）

## 背景

`lefthook.yml`の`debride`フックは、そのコミットでステージされた`.rb`ファイルのみ（`{all_files}`）をdebrideに渡している:

```yaml
debride:
  glob: '*.rb'
  run: bin/bundle exec debride --rails -w debride-whitelist.txt {all_files} | tee /dev/tty | grep -q 'LOC:\ 0'
  fail_text: 'Read the report above.'
```

2026-08-22、タスクグループ引き継ぎ機能実装のStep5（`accept_handover`エンドポイント追加）で、`config/routes.rb`＋`app/controllers/api/v1/task_group_shares_controller.rb`の2ファイルのみをコミット対象にしたところ、debride pre-commitが`accept_handover`・`request_handover`を「未使用の可能性」として誤検知しコミットが失敗した。

調査の結果、2種類の誤検知要因が判明した:

1. **ファイルスコープが狭いことによる誤検知**: debrideは「渡されたファイル群の中だけで呼び出し元を探す」ため、対象ファイルを絞るほど誤検知が増える。実測: 変更2ファイルのみだと`create`アクションまで誤検知されたが、`app`ディレクトリ全体を渡すと`create`の誤検知は消えた。
2. **`member do ... end`内の複数`patch`アクション問題**: `config/routes.rb`の同一`member`ブロック内に複数の`patch`カスタムアクションが並ぶと、`app`＋`config`をまとめて渡してもdebrideが一部を正しく紐付けられない（ファイルスコープを広げても解消しない、debride gem自体の限界）。

`app`ディレクトリ全体（またはapp+config）を渡しても実行時間は0.15秒程度で、実行コストは無視できるレベル。

## 変更内容（案）

`lefthook.yml`の該当行を変更:

```diff
  debride:
    glob: '*.rb'
-   run: bin/bundle exec debride --rails -w debride-whitelist.txt {all_files} | tee /dev/tty | grep -q 'LOC:\ 0'
+   run: bin/bundle exec debride --rails -w debride-whitelist.txt app config | tee /dev/tty | grep -q 'LOC:\ 0'
    fail_text: 'Read the report above.'
```

- `{all_files}`（変更ファイルのみ）→ `app config`（Railsアプリの解析対象ディレクトリ全体）に固定する
- `glob: '*.rb'`（`.rb`ファイルが変更された時だけこのフックを走らせるトリガー条件）自体は維持してよい（トリガー条件とdebrideへの入力ファイルは別の話）

## 期待される効果・限界

- 効果: ファイルスコープが狭いことに起因する誤検知（`create`のようなケース）は防げる
- 限界: `member`ブロック内の複数`patch`アクション問題は、この変更だけでは解消しない。今後も同様の誤検知が起きた場合は個別に`debride-whitelist.txt`へ追記する運用が引き続き必要

## 未確定事項（着手前にユーザー判断が必要）

- [ ] `app config`で十分か、それとも`.`（リポジトリ全体）にすべきか（`spec`や`db`配下等、他ディレクトリも含めるかどうかの判断）
- [ ] この変更を今回のタスクグループ引き継ぎ機能ブランチに含めるか、別の独立したブランチ・コミットにするか
- [ ] 変更後、既存の`debride-whitelist.txt`の内容で足りるか（スコープが変わると新たな検出/非検出が出る可能性があるため、変更後に一度リポジトリ全体でdebrideを実行し差分を確認する）

## 検証方法

1. `lefthook.yml`を変更
2. `bin/bundle exec debride --rails -w debride-whitelist.txt app config`を手動実行し、現状のwhitelistで通るか確認
3. 実際に何かファイルを変更して`git commit`し、pre-commitフックが正常に動作する（かつ実行時間が許容範囲）ことを確認
4. 既存の主要ブランチ・過去のコミット相当の変更点でも誤検知が起きないか、いくつかサンプル的に確認
