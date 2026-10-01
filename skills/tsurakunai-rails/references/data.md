# データ・更新・変更可能性

変更に関係する項目だけを確認してください。問題が起きていない実装や、必要な動作を確認できているテストまで書き換える必要はありません。

<a id="s03-db整合性"></a>

## validationとDB制約の対応

**起きやすい問題**: validationでは一意でも同時登録で二件入り、invoiceの外部IDなどが複数の行へ対応する。親が直接削除され、参照先が存在しない行もできる。

**確認すること**: modelのvalidationだけでなくschemaの複合unique index、foreign key、NOT NULLを業務上の不変条件へ対応させる。tenantごとの一意性、case-insensitive比較、nullableな値、部分indexの条件まで確認する。`structure.sql`や動的なtable名では静的copの成功を保証にしない。constraint violationが起きたとき、リクエスト全体が失敗すべきか既存行を返すべきかを決める。

**例外**: 外部システム由来の参照、取り込み途中の未完成データ、soft deleteによる再利用には別の保証があり得る。全列NOT NULLや全関連FKを根拠なく要求しない。

**検証**: DBへvalidationを迂回して書き込んでも禁止データを拒否すること、競合で二件できないこと、業務のエラー応答を確認する。既存データに制約を追加するときは不整合の棚卸しが先。

<a id="s04-関連と削除"></a>

## 親を削除するときの関連データの扱い

**起きやすい問題**: `has_many :invoices`の親を削除して履歴が孤立する。逆に`dependent: :destroy`を機械的に付けて会計履歴を消す。大量の子のcallbackで削除が長時間化する。

**確認すること**: 親と子の業務上の寿命を確認する。履歴を残すなら削除拒否や別の所有形態、完全に親に従属するなら削除を検討する。`:destroy`はcallbackを呼び、`:delete_all`やDB cascadeは呼ばない。`:nullify`はnullable列が必要。DB側で管理する関連や、親と独立した寿命の関連ではdependent指定がなくても正当。HasManyOrHasOneDependentを採用した場合の設定は、その保証と合わせて決める。async削除はenqueue後の失敗やFKとの整合性も追う。

**検証**: 通常の親削除だけでなく、子の削除が拒否された場合の親子の状態、監査・外部副作用、実際に想定する件数を確認する。through関連や読み取り専用modelへ一律のdestroyを要求しない。

<a id="s05-更新結果transaction"></a>

## 保存に失敗したときの処理とトランザクション

```ruby
# 問題: updateはfalseを返しても、後続が成功として進む
invoice.update(status: "paid")
notify_paid(invoice)

# 明示的に失敗を扱う一例
if invoice.update(status: "paid")
  notify_paid(invoice)
else
  render :edit, status: :unprocessable_entity
end
```

**確認すること**: APIの戻り値がbooleanかmodelかを確認する。`create`が返すmodelは保存に失敗してもtruthyであり、`if Invoice.create(...)`では成功を保証しない。例外で全体を中断するならbang APIを使う。複数更新の不変条件はtransactionでまとめ、失敗をtransaction内部で握りつぶしてcommitさせない。`rescue StandardError`で成功応答へ変えていないか、結果を返すserviceの呼び出し元が判定しているか追う。

**例外**: 戻り値を返し上位が判定するAPIや、エラーの表示のためにnon-bangを使うコードは正当。すべてbangへ置換しない。上の例もメール・課金などの外部副作用を含むなら[外部APIとジョブ](boundaries.md#s06-外部副作用ジョブ)のcommit境界を別途満たす必要がある。

**検証**: validation失敗や後半の更新失敗を再現し、成功応答・通知が出ず、必要なDB変更がrollbackすることを確認する。rollback後のRuby objectはDBと一致するとは限らず、DBの保証はreloadして確認する。

<a id="s07-競合状態遷移"></a>

## 同時更新と状態変更

```ruby
# 問題: 2 requestがともに在庫1を見てしまう
stock = Stock.find(id)
stock.update!(remaining: stock.remaining - 1)
```

**確認すること**: read→check→writeの間に別の処理が入る可能性を確認する。業務に応じて条件付きatomic update、row lock、optimistic locking、unique constraintを選ぶ。`with_lock`を使うならロック中に状態を読み直し、0以下を拒否する。外部決済までロック中に待つ構造を避ける。ロック順序・衝突・再試行でユーザーへ何を返すかを決める。

**例外**: 不変条件に関係のない統計値に強いロックを追加しない。ロックを付けただけでは二重リクエストの冪等性は成立しない。

**検証**: 二つの独立したrequest/DB接続による競合か、atomicな操作とDB制約の観測で保証する。単一transactionの同一接続で順に呼ぶテストを「並行実行済み」としない。

<a id="s08-migrationとdeploy"></a>

## migrationとデプロイの順序

**起きやすい問題**: columnを一度にrename/removeし、旧プロセスや実行中jobが参照できなくなる。大きいtableへロックの長い変更を行う。大量のbackfillをdeploy transactionへ混ぜる。

**確認すること**: 新column追加→旧新共存の読み書き→backfill→切り替え→旧参照除去のように、必要な場合は段階移行する。先にnullableで追加してデータを埋め、業務に合うconstraintへ締める。DB・table規模に応じてindexのオンライン作成、transaction可否、ロックを検討する。過去のmigrationが将来のmodel変更で壊れないか確認する。巨大backfillは再開・進捗・失敗時の処理を明確にする。実migrationの生成は導入先の規約に従う。

**例外**: 空の新tableや停止時間が許される小さい管理アプリで、無意味な多段deployを要求しない。defaultを追加してcopを黙らせる前に、その値が業務上正しいか確認する。

**検証**: 本番と同じschemaに既存行を置き、新旧コードが必要な期間動くこと、backfillの再実行と再開、失敗時の復旧を確認する。構文上reversibleでもデータが復元できるとは限らない。

## 仕様を確認する資料

- [Rails validations](https://guides.rubyonrails.org/active_record_validations.html)
- [Rails associations](https://guides.rubyonrails.org/association_basics.html)
- [Rails migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- [Rails query interface / locking](https://guides.rubyonrails.org/active_record_querying.html#locking-records-for-update)
