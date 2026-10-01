# 判断が必要な具体例

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

これは構造の例。`require_login`がredirectするだけならreturnするか例外を使って処理を止める必要がある。実際の認証ライブラリの規約に従う。認証・認可が元と同じ対象の全actionで必ず動くことをrequest testで確認する。ApplicationControllerやconcernのcallbackも追う。Deviseなどが要求するcallbackは理由を付けて例外にする。

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

`expect(service).to receive(:call)`だけでは、金額・状態・認可が正しいか分からない。requestまたは公開API経由で状態をreloadして確認し、失敗時に状態が変わらないこと、他ユーザーのIDで読めない・更新できないことを確認する。外部ネットワーク境界のstubは使ってよいが、境界に渡る金額・冪等キーなどの重要な値は検証する。

## 例外をレビューする

```ruby
# 統計の再集計。updated_at以外を変更せず、業務validationは不要。
# rubocop:disable TsurakunaiRails/ValidationBypass
update_columns(updated_at: Time.current)
# rubocop:enable TsurakunaiRails/ValidationBypass
```

理由が実装と一致するか、監査・callback・楽観ロックも省略する影響を確認する。ルール全体の無効化や大量のtodo生成を初手にしない。

## 参照先

仕様が必要なときは対象バージョンの公式資料を確認する。

- [Controller callbacks](https://guides.rubyonrails.org/action_controller_overview.html#controller-callbacks)
- [Active Record callbacks / transaction callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)
- [Active Record validations](https://guides.rubyonrails.org/active_record_validations.html)
- [Active Record migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- [Testing Rails applications](https://guides.rubyonrails.org/testing.html)
