# 境界・副作用・情報の扱い

変更に関係する項目だけを確認してください。[日常の設計方針](daily-design.md)は標準で適用し、このガイドでは正しさと例外を確認します。変更していない実装や、必要な動作を確認できているテストまで書き換える必要はありません。

<a id="s01-認証認可テナント"></a>

## 認証・認可とアカウントごとのデータ取得

```ruby
# 問題候補: 別accountのIDも取得できる
invoice = Invoice.find(params[:id])
# 改善の一例: account scopeに加えて操作の認可も確認する
invoice = current_account.invoices.find(params[:id])
authorize_invoice!(invoice, :update)
```

継承元、concern、middleware、policyまで追い、別の場所で認可が成立している可能性を確認する。認証と認可は別。account内でも役割・状態により操作できない場合がある。HTTPだけでなくjob、管理画面、bulk APIの入口も追う。callbackを明示呼び出しへ移すときはredirect後に処理が止まるか、全actionを覆うか確認する。

**検証**: 未認証、別account、権限のない役割の入力で読む・更新することを拒否し、DB状態・外部副作用が変化しないことを確認する。実証なしに脆弱性と断定しない。Deviseの必須callbackを削除すること自体を目的にしない。

<a id="s02-入力sql出力"></a>

## 入力値をSQLやHTMLへ渡すときの確認

```ruby
# 問題: 任意属性・任意のSQLを外部入力で渡す
invoice.update!(params[:invoice].to_unsafe_h)
Invoice.order(params[:sort])

# 明示した境界の一例
invoice.update!(params.require(:invoice).permit(:memo))
sort = { "recent" => { created_at: :desc, id: :desc } }.fetch(params[:sort], { id: :asc })
current_account.invoices.order(sort)
```

保存できる属性は役割と操作ごとに決め、account_id・金額・承認状態などを無条件にpermitしない。値はbind parameter等で扱い、column名・sort・table名はallowlistへ対応させる。単純な文字列置換やSQLへ渡す前のescapeだけで安全としない。ユーザー入力へ `html_safe` / `raw`を付ける経路は、実際の信頼境界とsanitizeの要件を確認する。

**例外**: 入力が固定値・信頼済み内部DSLなら、その証拠を確認する。strong parametersだけで認可が済んだと扱わない。Rails versionに応じた入力APIを選ぶ。

**検証**: account_idや承認状態の追加入力で権限を越せないこと、未知のsortが安全な既定値または拒否になること、危険なHTMLの出力を確認する。

<a id="s06-外部副作用ジョブ"></a>

## 外部APIとジョブの失敗・再実行

**起きやすい問題**: transaction内の課金は成功したが後のDB更新が失敗する。rollback前にenqueueしたjobが存在しない行を読む。commit後に送信する構造へ直しても、送信前のプロセス停止で通知が失われる。

**確認すること**: 当該Rails version、queue adapter、enqueueのcommit待ちの設定を確認し、動作を推測しない。外部副作用はDB rollbackで戻らない。業務の保証に応じてcommit後の処理、永続job、outbox、外部APIの冪等キーを選ぶ。IDなどをjobへ渡し、実行時の削除・状態変更・tenant scopeを扱う。retry範囲を決め、一時エラーと永続エラーを分ける。callbackの重複登録で片方が消える問題は標準copでも検出する。

**例外**: 重要性が低く再生成できる通知へ決済と同じ配信保証を要求しない。`after_commit`は正当なlifecycle hookになり得るが、それだけで配信保証や冪等性が成立したとしない。

**検証**: rollback、enqueue/送信失敗、同一jobの再実行、対象削除、外部APIが成功した後でのtimeoutを確認する。同じ課金や業務更新が二度成立しないことを境界の値とDB状態で確認する。

<a id="s11-cacheログ秘密"></a>

## キャッシュの更新とログへの情報漏えい

**起きやすい問題**: `Rails.cache.fetch("invoices")`がaccount間で共有され、別accountのデータを返す。認可前のcache結果をそのまま表示する。決済tokenや個人情報をparams・例外・job引数ごとログへ出す。

**確認すること**: cacheの値が依存するtenant・user・権限・locale・versionをkeyまたは別の隔離で表現する。認可はcache hitでも維持する。更新・削除時の失効とstaleの許容範囲を決める。ログは障害調査に必要なID・状態を残し、秘密の値そのものを残さない。`filter_parameters`が独自ログ・外部監視・job payloadまで覆うとは限らない。credentialをfixtureへコピーしない。

**例外**: 全利用者が同じ値を見る公開cacheならuser keyは不要。個人情報を全く観測できなくすることで必要な監査を壊さない。要求される保管・アクセス制御を確認する。

**検証**: 異なるaccount・権限でcache hitを再現し、情報が混ざらないこと、更新後の結果、実際のlogと例外通知の出力を確認する。

## 仕様を確認する資料

- [Rails security](https://guides.rubyonrails.org/security.html)
- [Rails Active Job](https://guides.rubyonrails.org/active_job_basics.html)
- [Rails caching](https://guides.rubyonrails.org/caching_with_rails.html)
- [Rails transaction callbacks](https://guides.rubyonrails.org/active_record_callbacks.html#transaction-callbacks)
