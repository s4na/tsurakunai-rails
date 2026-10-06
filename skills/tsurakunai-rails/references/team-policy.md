# Railsチーム規約

Railsへの習熟度や好みが違う人が増えても、同じ変更を同じ場所へ書き、入口から処理を追えるようにする。便利さのために入力・実行順序・責務を隠す機能を制限し、その中では業務の表現を自由に選ぶ。以下はRails自体の善悪ではなく、このチームが採る標準である。

導入先の `RAILS_TEAM_POLICY.md` と既存の明示規約を先に読む。導入先の決定があれば優先する。未指定の判断はこの標準を使う。既存コードの存在だけを許可の根拠にせず、新しい流儀・例外を実装の都合で増やさない。未変更領域を一括改修しない。

## 標準の書き方

| ID | チームで揃えること | 使わない形／認める範囲 | 確認方法 |
| --- | --- | --- | --- |
| T01 | action内に、対象取得→認可→入力→操作→応答を見せる | 対象ロード・業務更新・通知のaction callbackは使わない。認証・framework必須hookは名前で事前許可する | ControllerCallbacks＋全actionの未認証・認可拒否テスト |
| T02 | modelの公開業務メソッドで状態を変える | save/validation/find callbackから業務手順を起動しない。全入口で必要な局所的正規化や基盤hookだけを登録名で事前許可する | ModelCallbacks＋許可hookの本体・全入口の状態確認 |
| T03 | actor・tenant・時刻等を引数または取得済み対象で渡す | model/job/操作/query/form/helper/componentからCurrentを読まない。HTTP境界での利用は可。表示にも必要な値を渡す | ImplicitContext＋引数とrequestなしの実行。別名のglobal・ERBはレビュー |
| T04 | 共通の業務は名前付きobjectを明示的に呼ぶ | 新規の業務Concern・includeによる暗黙API・実行時のmethod生成を使わない。Railsや認証ライブラリ内部のmixinsは置き換えない | Concern＋通常のmodule/include・動的定義のレビュー |
| T05 | CRUDはcontroller→model、状態遷移はmodelの業務名メソッド | 一回のsaveを転送するServiceは作らない。複数集約・外部I/Oを調整する処理だけ `app/operations/<対象>/<動詞>.rb` の普通のclassへ。既存規約に配置があれば統一して従う | 操作全体と呼び出し元をレビュー |
| T06 | scopeは明示し、複雑な検索は `app/queries/` で認可済みrelationを受ける | default_scope、取得中のCurrent、view/helper内のfind・whereによる対象選択を使わない。描画時のrelation列挙は可 | DefaultScope＋取得範囲・件数・query計測 |
| T07 | partialには、単一action用も含め必須値をlocalsで渡す | partialのinstance variable、params/Current/暗黙helperで入力を補わない。トップレベルviewのinstance variableは可。UI方式は既存partial/component基盤に揃える | ERB入力lint＋全render入口と失敗時の描画 |
| T08 | 通常CRUDは保存結果で分岐、業務操作はbang APIで失敗を伝える | 保存結果の無視、曖昧なboolean/result/例外の混在を増やさない。モデル操作は成功時に対象を返し、拒否は業務例外、保存失敗はAR例外。既存の戻り値契約があれば維持する | SaveBang＋公開APIの正常・拒否・rollbackテスト |
| T09 | 永続データの条件はvalidation＋DB制約、結果を公開境界で確かめる | validation bypassやstubで保証を消さない。外部副作用はcommitとの順序と再実行の契約を明示する | 既存のDB/保存/RSpecルール＋実リクエスト・model・jobの結果 |

T01〜T08は動くコードにも適用する規約である。不具合が証明できないから自由に使ってよい、とは扱わない。動作不良の報告とは分け、規約ID・対象・標準の置き換え先を示す。クラス数、modelの行数、ifの数、Serviceという名前だけで合否を決めない。

## 迷わない選び方

1. 属性編集だけなら既存actionとmodelを使う。例: `if invoice.update(invoice_params)` の成功／422分岐。
2. レコードとその明細を一緒に確定するなら `invoice.confirm!(confirmed_by:)`。条件・transaction・戻り値をこの公開入口へ揃える。
3. 独立した集約や外部APIをまたぐなら `Invoices::CollectPayment.new(...).call` のような一つの操作class。必要な依存は引数、業務手順は `call` に置き、共通のService基底classやresult frameworkは導入しない。
4. 計算や取得だけを分ける場合も、同じ領域の既存の置き場所とAPIに揃える。既存のない検索はquery、画面専用の入力検証はform、独立計算は業務名POROとする。単純な処理には新しい層を挟まない。

外部処理をcallbackから単に `save!` の次へ移して完了にしない。外側transactionのrollback、送信前の停止、送信成功後のtimeout、二重実行を要件に応じて扱う。commitとの連携は利用中のRails/queueの仕様で検証する。金銭等の保証が必要なら永続的な送信記録・冪等キーを設計する。表示変更にその仕組みは追加しない。

## 例外をチームの判断として残す

例外は「この実装では便利」「37signalsで使っている」だけでは認めない。必要な基盤・既存の契約・具体的な移行コストがある場合、対象、理由、代替保証をこのファイルへ短く記録し、対応するlintの許可名／対象限定／行単位disableと一緒に変更する。既存の明示許可は再承認を求めない。AIはlintを通す目的で勝手に許可を広げない。

| 対象・規約ID | 必要な理由 | 設定と代替保証 |
| --- | --- | --- |
| 未登録 | チームで採用した例外がある場合だけ行を追加 | 例: T01の認証hook名をAllowedMethodsに登録し、全actionの未認証拒否をrequest testで確認 |

`AllowedMethods` は同名の全controller hook、`AllowedCallbacks` は同じ種類・名前の全model hookに適用される。本体の意味・継承・対象actionはlintで保証されない。一箇所だけの例外は行単位disableまたは狭いExcludeを使う。承認済みhookへ別の処理を追加するときは、その例外の保証を再確認する。

既存アプリは認証・保存・commitを保ったまま、変更対象の機能から合わせる。未移行の範囲は理由付きの狭いExclude等で見えるようにし、全体OFFを新しい標準と混同しない。Haml/SlimやERB内部、別名のCurrentAttributes、ライブラリ内のcallback、動的登録はレビューの対象として残る。
