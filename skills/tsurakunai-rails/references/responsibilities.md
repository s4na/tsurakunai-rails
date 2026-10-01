# コントローラとモデルの責務

変更に関係する項目だけを確認してください。[日常の設計方針](daily-design.md)は標準で適用し、このガイドでは正しさと例外を確認します。変更していない実装や、必要な動作を確認できているテストまで書き換える必要はありません。

以下はこのパッケージの判断方針で、Railsの禁止事項ではありません。コードは責務の置き場所を示す部分例です。schema、認可、業務の失敗応答を省略したまま完成実装としてコピーしないでください。クラスの数や行数より、同じ業務操作をHTTP・job・管理画面から呼んでも同じ不変条件と失敗の扱いが保たれることを重視します。

<a id="s13-コントローラはhttpの入口と出口を扱う"></a>

## コントローラで扱う処理

**起きやすい問題**: controller内に割引・承認条件・在庫の計算があり、jobや別actionへコピーされる。一方だけ条件を直して、同じ操作で異なる結果になる。認可や失敗の応答も、callbackや巨大なprivate methodの中へ隠れる。

**置くもの**: 認証・対象の認可、許可した入力の取り出し、tenantに沿った対象の取得、業務操作の呼び出し、結果に応じたrender/redirect/status。単純なCRUDの `record.update(permitted_attributes)` と成功・失敗の分岐はcontrollerにあってよい。

**外へ出す条件**: 業務の計算・判断・複数更新は、重複がなくてもHTTP処理から分ける。他の入口でも守るべき状態遷移・計算・複数更新がHTTPの流れへ混ざる、同じ業務条件が複数actionで変わり始める、処理の失敗がどの状態を残すか追えない場合。対象modelの操作または[複数モデルの更新](responsibilities.md#s15-複数モデルの業務処理に明示的な入口を作る)の処理へ寄せ、controllerには入力と結果の対応を残す。

```ruby
# 問題候補: 別の入口で同じ承認条件と履歴更新を再実装する
if invoice.draft? && invoice.total_cents > 0
  invoice.update!(status: :approved, approved_by: current_user)
end

# 責務を分ける一例: 認可した対象とactorを明示的に渡す
invoice = current_account.invoices.find(params[:id])
authorize_invoice!(invoice, :approve)
invoice.approve!(approved_by: current_user)
redirect_to invoice
```

**エラーの扱い**: input不正、権限不足、対象不存在、業務上の拒否、想定外の障害を区別する。modelや処理からHTTP statusを返させず、controllerで応答へ対応させる。`rescue StandardError`ですべてを成功や入力不正へ変えない。例外とresult objectのどちらも認めるが、成功か失敗かを呼び出し元が無視できる設計を見落とさない。

**例外**: 単一actionの短い処理をラップするだけのserviceやDTOを要求しない。HTML/JSONのresponse分岐はHTTPの責務であり、業務ロジックの重複とは限らない。認証・ロード等のcallbackは、対象と順序の契約を満たす通常の実装として認める。

**検証**: request testで認可・入力・成功と失敗のstatus/redirect・状態不変を確認し、同じ業務操作を別の入口から呼んだ結果も必要に応じて検証する。「serviceを呼ぶこと」だけで保証を終えない。

<a id="s14-モデルはデータと業務の不変条件を保つ"></a>

## モデルで守るデータの条件

**起きやすい問題**: controllerが認める状態だけをmodelが受け入れるつもりだが、jobの `update!` ではその条件が抜ける。逆にmodelが `params` / `current_user` / sessionを読み、consoleやjobから使えない。毎回のsave callbackが遠隔APIや別集約の更新まで起こし、無関係な修正が他の業務を実行する。

**置くもの**: そのデータの関連、常に成立すべきvalidationとDB制約、状態の問い合わせ、レコード自身の状態遷移、明示的な取得条件。独立した業務計算、外部I/O、複数集約の調整は必要に応じてPOROへ分ける。値だけの計算には必要な値を渡し、モデルの意味を表す短い計算やvalue objectは残してよい。必要なactor・値・時刻は引数として渡す。役割とtenantの業務条件が不変条件なら、HTTPの認可だけに頼らず当該操作で維持する。

```ruby
# 構造例: 状態遷移をmodelの公開操作にする
# approverの権限・tenant一致など、実アプリの必要な条件もこの境界で保証する。
def approve!(approved_by:)
  with_lock do
    raise InvalidTransition unless draft? && total_cents.positive?

    update!(status: :approved, approved_by: approved_by)
  end
end
```

`with_lock`だけで二重requestの冪等性や認可は保証されない。直接 `update!(status: ...)` で操作を迂回する呼び出し元が残っていないか追う。必要に応じて遷移のvalidation・DB制約・操作APIの使い方を合わせる。modelにメソッドを置いただけで全入口の保証ができたと扱わない。

**callbackとvalidation**: 局所的で決定的な正規化などはmodel callbackの候補。ただし、呼び出し元が渡した値を意図せず変更しない。validationは正しさの検査を行い、外部通信・別行の作成・メール送信などを隠して実行しない。複数modelや外部副作用を伴う業務は[複数モデルの更新](responsibilities.md#s15-複数モデルの業務処理に明示的な入口を作る)・[外部APIとジョブ](boundaries.md#s06-外部副作用ジョブ)へ。全callbackを禁止せず、saveのたびに何が起きるかを読める範囲へ保つ。

**scopeと取得**: scopeはrelationとして合成できる明示的な条件にする。時刻は定義時に固定せず呼び出す時点の業務上の境界を使う。tenantの取得は引数や呼び出し元のrelationへ明示し、`Current`の暗黙の値を使う場合はjob/consoleでの初期化・解除・境界保証を確認する。標準のsave/destroyなどの契約を上書きして独自処理を隠さない。

**例外**: Active Record modelを属性と関連だけの箱へ変えることを要求しない。永続化から独立した計算は、分離によって理解・テストしやすくなる単位でPOROや関数へ分ける。メソッド数だけで分割しない。`params`などが正当な業務属性なら、その名前だけでHTTP依存と扱わない。ModelRequestContextの許可名や狭い例外で対応する。

**検証**: 公開操作の正常・拒否・競合、直接保存の経路、callbackの回数、job/console相当のrequest非依存の呼び出しを確認する。必要なactorをHTTPのglobalから取得してテストを通さない。

<a id="s15-複数モデルの業務処理に明示的な入口を作る"></a>

## 複数モデルをまとめて更新する処理

**起きやすい問題**: controller・model callback・jobにまたがって注文と在庫と履歴を変更し、途中で失敗すると一部だけ残る。modelが関係の薄い全業務を引き受ける。すべての保存をserviceへ移した結果、常に守るべきmodelの条件は逆に抜ける。

**選ぶ順序**: 一つのmodelまたは自然な集約で表現できる操作なら、その公開操作を候補にする。複数の集約・業務の手順・外部境界をまたぎ、処理の成功条件とtransactionを一つに見せる必要があるなら、プロジェクトの規約に合う普通のRuby object（use case / operation / service等）を選ぶ。共通の`.call`基底classやresult frameworkの導入を必須にしない。

**引数と戻り値**: 許可済みの具体的な値・actor・対象を渡し、HTTPのparams/session/renderは渡さない。成功時に何を返すか、業務上の拒否と障害をどう伝えるかを決める。request/job双方の認可や不変条件が維持される位置を確認し、controllerで認可済みという前提だけでjobからの操作を認めない。

**transaction**: DB上で一体となる変更を明示し、同じDB接続のtransactionで原子性を保つ。別DB・外部API・queueまで一緒にrollbackできるとは扱わない。内部のmodel操作は自身の不変条件を維持し、外側の手順は失敗を握りつぶさない。save callbackから別のuse caseを無条件に起動して循環・重複を作らない。副作用・再試行・冪等性は[外部APIとジョブ](boundaries.md#s06-外部副作用ジョブ)/[同時更新](data.md#s07-競合状態遷移)も確認する。

**例外**: ただ `User.create!` を転送するだけのserviceを全modelに作らない。規約の違いはそれだけで欠陥ではない。変更されない全controllerへ同じ抽出を広げない。

**検証**: 処理の公開入口から最終DB状態を確認し、途中の失敗時に必要な変更が残らないことを検証する。外部境界はstubできるが、重要な入力・冪等キー・失敗時の処理は検証する。

<a id="s16-入力検索表示を永続モデルへ押し込まない"></a>

## 入力・検索・表示を分ける目安

**起きやすい問題**: wizardの一画面専用のvirtual attributeとvalidationが永続modelへ増え、別の入口からの保存に影響する。`attr_accessor :admin_request`の設定を忘れると必要な検査が抜ける。一覧のfilter・pagination・HTTP params・CSV表示まで一つのmodelへ集まる。

**入力**: 複数modelへの入力や一時的な確認欄が独立した検証・エラー表示を持つなら、form object（必要ならActive Model）を候補にする。HTTP入力のpermit・認可は入口に残し、formへは許可した値を渡す。UI固有の確認と、保存したデータが常に満たすmodel/DBの条件を分ける。formのvalidationを通っただけでmodelやDBの保証を迂回しない。

**検索**: 単純で再利用する条件は名前付きscopeでよい。多くのfilter・sort・集計が組み合わさるときは、tenantに沿ったbase relationと明示的なfilter値を受けるquery object等を候補にする。`InvoiceSearch.new(scope: current_account.invoices, filters: permitted_filters)`のように取得範囲を失わない。query objectへ抽出した際に `Invoice.all` へ戻って認可を落とさない。未検証のsort文字列をSQLへ渡さない。

**表示と値**: HTMLの整形はview/helper/presenter等へ、レスポンス形式はserializer等の境界へ置く。純粋な業務計算と表示用の通貨文字列は分ける。数値・時刻の表現や複数属性の不変条件が独立する場合はvalue objectを候補にする。種類だけでクラスを増やさない。

**例外**: 単純なCRUDの数個の入力にform objectを必須としない。正当なvirtual attributeやvalidation contextもある。常に成立すべき条件が、文書化されないrequest flagで変わることを問題にする。

**検証**: 不正入力のエラーの所在、複数modelの更新失敗、filter/sortとtenantの境界、表示時の副作用なし、HTTP以外の保存経路で不変条件が維持されることを確認する。

## 置き場所を選ぶ目安

| 処理 | 最初の候補 | 抽出を考える具体的な変化 |
| --- | --- | --- |
| permit、認証・対象認可、HTTP応答 | controller / 認可policy | 複数の入口で認可の契約が曖昧になる |
| 単純な取得・CRUDと応答分岐 | controller + model | 業務の計算・判断・複数更新を追加する |
| データの不変条件、レコード自身の状態遷移 | model / 自然な集約 | 独立した計算・値や別集約の手順が混ざる |
| 独立した業務計算 | modelの値の振る舞い / value object / 必要なPORO | 必要な値を受け取り結果を返す。独立した仕事を分けると追う場所が減るか |
| 複数の集約の手順とtransaction | 意味のある操作object等 | 途中失敗と最終状態を一つに追えない |
| 画面固有の入力・確認とエラー | form object等 | 永続データの条件と画面の条件が衝突する |
| 合成可能な取得条件 | scope | filter・集計・取得計画が一つの独立した責務になる |
| 表示・レスポンスの整形 | view/helper/presenter/serializer等 | modelがHTTP・HTMLへ依存する |

機械は型や業務意図を推論できないため、controller内のif、modelの行数、serviceの有無を一律に禁止しません。標準ONの `ModelRequestContext` copはmodel内の特定名の呼び出しを検出するだけで、業務属性との区別はできません。許可名や個別OFFで調整できます。job等で必要な値が欠ける具体的な問題と、その入口の契約を根拠に判断します。

## 仕様を確認する資料

- [Rails controllers](https://guides.rubyonrails.org/action_controller_overview.html)
- [Rails Active Record](https://guides.rubyonrails.org/active_record_basics.html)
- [Rails Active Model](https://guides.rubyonrails.org/active_model_basics.html)
- [Rails callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)
