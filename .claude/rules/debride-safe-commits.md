---
paths:
  - "app/**/*.rb"
  - "config/routes.rb"
  - "lefthook.yml"
---

# debride-safeなコミット

- 新設privateメソッドやassociation（`has_many`等）を、実際に呼び出す・使用するコードより先の別コミットに分離しない。使用コードと同一コミットに含める（lefthookのdebride pre-commit hookが未使用コードとして検出し失敗するため）
- lefthookの`debride` hookはstagedな`.rb`ファイルのみscanする。対象ファイルが狭いほどfalse positiveが増える既知の制約あり
- pre-commit debride失敗時→`bin/bundle exec debride --rails -w debride-whitelist.txt app config`を手動実行し、lefthookの結果と比較して原因を切り分ける
- `config/routes.rb`の`member`ブロック内に複数の`patch` custom actionがある場合、対象範囲を広げても一部のfalse positiveは解消しない。その場合→`debride-whitelist.txt`へ個別追加
