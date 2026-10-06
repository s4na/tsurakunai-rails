# Railsチーム規約

Railsへの習熟度や好みが違う人が増えても、同じ変更を同じ場所へ書き、入口から処理を追えるようにする。便利さのために入力・実行順序・責務を隠す機能を制限し、その中では業務の表現を自由に選ぶ。以下はRails自体の善悪ではなく、このチームが採る標準である。

導入先の `RAILS_TEAM_POLICY.md` と既存の明示規約を先に読む。導入先の決定があれば優先する。未指定の判断はこの標準を使う。既存コードの存在だけを許可の根拠にせず、新しい流儀・例外を実装の都合で増やさない。未変更領域を一括改修しない。

## ルールとスキルの共通の合格条件

各ルールは「どうあるべきか」と「どうでないべきか」を対で定める。以下の必須欄は推奨ではない。変更に適用するIDについて、**必須の形・契約を満たし、禁止した形を使っていないこと**を両方確認する。例外は対象と代替保証が明示された範囲だけに適用する。

実装スキルは両方を満たすコードを作り、レビュースキルも両方を検査する。禁止構文がない、lintが成功した、現状のテストが成功したという理由だけでは規約適合としない。lintで判定できない必須条件も、規約IDを使ったレビューと公開結果の検証で拘束する。判断の証拠が足りなければ未確認とし、合格へ読み替えない。

## 標準の書き方

| ID | 必須：どうあるべきか | 禁止：どうでないべきか | 適用範囲・認める例外 | 確認方法 |
| --- | --- | --- | --- | --- |
| T01 | action内に、対象取得→認可→入力→操作→応答を見せる | 対象ロード・業務更新・通知をaction callbackへ隠す | 認証・framework必須hookは名前で事前許可する | ControllerCallbacks＋actionの入口・未認証・認可拒否テスト |
| T02 | 集約の状態遷移の条件・更新をmodelの公開業務メソッドに揃える | save/validation/find callbackから業務手順を起動する。状態遷移の条件・更新をcontroller/jobへ分散する | 通常の属性CRUDはT05。全入口で必要な局所的正規化や基盤hookだけを登録名で事前許可する | ModelCallbacks＋公開APIと全入口の状態確認。配置はレビュー |
| T03 | 必要なactor・tenant・時刻等を引数または取得済み対象で渡す | model/job/操作/query/form/helper/componentでCurrentやHTTPの暗黙入力から補う | HTTP境界のCurrent利用は可。表示にも必要な値を渡す | ImplicitContext/ModelRequestContext＋引数とrequestなしの実行。別名のglobal・ERBはレビュー |
| T04 | 共有が必要な業務は名前付きobjectと明示した依存で呼ぶ | 新規の業務Concern・includeによる暗黙API・実行時のmethod生成を使う | Railsや認証ライブラリ内部のmixinsは置き換えない。単純な処理のために協力objectを増やさない | Concern＋呼び出しと依存、通常のmodule/include・動的定義のレビュー |
| T05 | 属性CRUDはcontroller→model、状態遷移はmodel、複数集約・外部I/Oの調整は `app/operations/<対象>/<動詞>.rb` の普通のclassのcallへ揃える | 一回のsaveを転送するService、新しい共通Service基底classやresult framework、同じ操作の別流儀を増やす | 既存の配置・API契約が明示されていれば統一して従う。必要な計算/query/formは用途のある単位で分ける | 操作全体・置き場所・呼び出し元をレビュー。lintだけでは判定しない |
| T06 | 条件を明示scopeへ揃え、複雑な検索は `app/queries/` で認可済みrelationを受け、描画前に取得条件を決める | default_scope、取得中のCurrent、view/helper内のfind・whereによる対象選択、queryへ抽出した際の認可範囲の破棄 | 単純なscopeをqueryへ包まない。描画時のrelation列挙は可。既存の明示配置は維持 | DefaultScope＋取得scope・件数・query計測。入力relationはレビュー |
| T07 | 全partialの必須値をlocalsで渡し、全render入口・保存失敗時にも同じ入力契約を満たす | partialのinstance variable、params/Current/暗黙helperで入力を補う。必須localを呼び出し元で省く | 単一action用も適用。トップレベルviewのinstance variableは可。既存partial/component基盤に揃える | ERB入力lint＋呼び出し元と実際の描画。localsを使うことだけでは合格にしない |
| T08 | CRUDは保存結果で分岐。modelの状態遷移はbang名のAPI、operationはcallと内部のbang保存を使い、成功時は対象、拒否は業務例外、保存失敗はAR例外へ揃える | 保存結果を無視する。新しい操作でboolean/result/例外を混在させる。想定外の障害を業務拒否へ握りつぶす | 既存の明示された戻り値・失敗契約は維持。operationのcallにbang名を強制しない | SaveBang＋戻り値・正常・拒否・rollbackテスト。API名だけでは判定しない |
| T09 | 永続データの不変条件をmodel/公開操作で守り、DBで表現できる条件は制約でも保護し、正常・拒否・失敗の結果を公開境界で確かめる | validation bypassや検査対象のstubで保証を消す。外部送信をDB transactionでrollbackできると扱う | 承認済みbulk等は代替保証を維持。外部副作用がある変更ではcommit・送信失敗・再実行の契約を明示する | 既存のDB/保存/RSpecルール＋実リクエスト・model・jobの結果と必要な再実行 |

T01〜T09は動くコードにも適用する規約である。必須条件の欠落と禁止形の使用は、どちらも規約違反として扱う。動作不良の報告とは分け、ID・対象・欠けた必須条件または禁止形・標準の置き換え先を示す。クラス数、modelの行数、ifの数、Serviceという名前だけで合否を決めない。

## 禁止構文がなくても合格にしない例

以下は新しい明示規約や例外がない場合の対例である。実装とレビューの両方で同じ判断を使う。

| 変更の条件 | 満たす形 | 満たさない形と規約ID |
| --- | --- | --- |
| タイトル属性だけを編集する | actionで認可したrecordをupdateし、保存結果で応答を分ける | updateを一回転送するだけのUpdateTitleServiceを新設。callbackがなくてもT05に反する |
| 請求書とその明細を一緒に確定する | invoice.confirm!(confirmed_by: actor)へ条件・transaction・更新を揃え、action/job双方から呼ぶ | 各action/jobに同じ条件と明細更新を直書き。ConcernがなくてもT02/T05を満たさない |
| 新しい確定操作の公開APIを作る | 成功時にinvoiceを返し、拒否と保存失敗を定めた例外で伝える | confirm!という名前でも成功時true、失敗時falseを返す。保存結果を無視していなくてもT08を満たさない |
| 複雑な請求書検索を抽出する | 認可済みrelationと許可filterをqueryへ渡し、そのrelationを絞る | query内部でInvoice.allからやり直す。default_scopeやCurrentがなくてもT06を満たさない |
| partialへinvoiceとcurrencyを渡す | 全render入口で両localを渡し、保存失敗時も入力とerrorsを保つ | partial内はlocalだけでも、別actionがcurrencyを渡し忘れる。T07を満たさない |

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
