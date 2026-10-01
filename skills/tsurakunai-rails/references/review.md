# 判断が必要な具体例

変更に関係する項目だけを確認してください。[日常の設計方針](daily-design.md)は標準で適用し、このガイドでは正しさと例外を確認します。変更していない実装や、必要な動作を確認できているテストまで書き換える必要はありません。

## callbackの移行で認可を落とさない

```ruby
# before_action :require_login
# before_action :load_invoice
# before_action :authorize_invoice

def update
  require_login
  invoice = current_account.invoices.find(params[:id])
  authorize_invoice(invoice)
  invoice.update!(invoice_params)
  redirect_to invoice
end
```

これは構造の例。`require_login`がredirectするだけならreturnするか例外を使って処理を止める必要がある。実際の認証ライブラリの規約に従う。認証・認可が元と同じ対象の全actionで必ず動くことをrequest testで確認する。ApplicationControllerやconcernのcallbackも追う。認証基盤などで必要なcallbackは標準で許容する。全面禁止を選んだ導入先ではAllowedMethodsで残せる。上の明示呼び出し例は、処理順を追いやすくするために移行を選んだ場合の候補であり、全actionの認証・認可を保つことが前提である。

## validationとDB制約

`validates :external_id, uniqueness: { scope: :account_id }`だけでは、二つのリクエストが両方のvalidationを通過できる。対応する複合unique indexを確認し、衝突時の応答もテストする。DB・業務のnullの扱いを確認する。indexを既存データへ追加するときは重複の調査・解消、オンライン作成可否、旧コードの動作を検討する。

## 外部副作用

```ruby
Order.transaction do
  order.confirm!
  PaymentGateway.charge(order.id) # DB rollbackで外部の課金は戻らない
end
```

外部APIをcommit後に移しても、commitと送信の間にプロセスが落ちれば送信されない。再試行で二重課金も起こり得る。業務が要求する配信保証に応じて永続ジョブ、outbox、冪等キーを選ぶ。決済がない変更にこの仕組みを要求しない。

## テストが呼び出しだけを保証している

`expect(service).to receive(:call)`は委譲の検証には使えるが、それだけでは金額・状態・認可を保証しない。変更した仕様がどの既存テストで保証されるか確認し、不足する保証にだけ追加する。requestまたは公開API経由で状態をreloadして確認し、失敗時に状態が変わらないこと、他ユーザーのIDで読めない・更新できないことを確認する。外部ネットワーク境界のstubは使ってよいが、境界に渡る金額・冪等キーなどの重要な値は検証する。

## 例外をレビューする

```ruby
# 統計の再集計。updated_at以外を変更せず、業務validationは不要。
# rubocop:disable TsurakunaiRails/ValidationBypass
update_columns(updated_at: Time.current)
# rubocop:enable TsurakunaiRails/ValidationBypass
```

ValidationBypassは標準ON。個別OFFにしている場合は、この例外コメントは不要。省略した監査・callback・楽観ロックに実際の影響があるか確認し、安全な保守処理を個別updateへ機械的に変えない。

## lintを通過する失敗の追い方

次はRailsのリクエスト・SQLite・描画で再現できる問題です。表の形に一致するだけで指摘せず、差分で変わる契約と実際の呼び出し元を確認します。アプリ全体の点検表ではありません。

| 差分 | 調べる範囲と失敗の証拠 | 最小の修正候補・正当な対例 |
| --- | --- | --- |
| `current_account.invoices.find(id)`を`Invoice.find(id)`へ変更 | current accountの定義、認可policy、他accountのIDでのrequest。成功し、他accountの行が更新されれば漏えい・改ざん | 認可済みrelationから取得する。global find後に対象の認可を確実に行う実装ならglobal findだけで指摘しない |
| permitに`account_id`や`owner_id`を追加 | 属性の意味、所有権移転の認可、request後のreload。同じ利用者が任意の所属へ移せれば認可の迂回 | 移転を許可しない通常更新ではpermitから外す。認可した移転専用操作は認める |
| validation失敗後に`reload`・`find`・`new`してrender | 保存戻り値、表示に使うobject、実際のHTML。reloadで入力値がDBの値へ戻る、または別objectへの置換でerrorsが消えて再入力が必要になる | 保存に失敗したobjectをそのまま描画する。成功後のreloadや、意図的な入力破棄は欠陥ではない |
| validationをcontrollerへ移す・modelから削る | その条件が全入口の不変条件か、job/console等の公開操作とDB制約。requestでは拒否するが直接保存は不正値を受け入れる | modelまたはDBで必要な条件を保つ。画面だけの確認欄をformへ移すのは正当 |
| collectionや別actionがpartialを使う | `render`のcollection/as/localsとpartial内の変数。異なる2行を描画し、両方に同じ`@invoice`の値が出る | 対象recordのlocalを読む。単一actionの用意済みinstance variableはそのままでよい |

指摘は例えば「他accountのinvoice IDを送ると200となりmemoが変更される。account内のinvoiceだけを更新する契約に反する。取得を`current_account.invoices.find`に戻し、他accountのIDでは404か403でDBが変わらないことを既存request testで確認する」のように書きます。単に「controllerが太い」「認可が見当たらない」では終えません。

DB制約や既存の認可・テストが契約を保証している場合は、それを根拠に指摘を見送ります。再現できなければ、コードから確定する経路と未確認の前提を分けて報告します。スキル利用時に、このパッケージの検証アプリや全シナリオを導入先へコピーする必要はありません。

## 参照先

仕様が必要なときは対象バージョンの公式資料を確認する。

- [Controller callbacks](https://guides.rubyonrails.org/action_controller_overview.html#controller-callbacks)
- [Active Record callbacks / transaction callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)
- [Active Record validations](https://guides.rubyonrails.org/active_record_validations.html)
- [Active Record migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- [Testing Rails applications](https://guides.rubyonrails.org/testing.html)
