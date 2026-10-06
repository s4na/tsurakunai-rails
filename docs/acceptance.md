# 実用検証と限界

ルールの数ではなく、正当なRailsコードを通し、具体的な失敗を発見できるかを確認します。ここで使うのは検証用の小さな請求書アプリです。第三者の本番アプリでの実績や、開発時間の削減率を示すものではありません。

## 再現する

このリポジトリの開発依存を導入して実行します。アプリは一時フォルダへ複製し、DBはプロセスごとのSQLiteメモリDBです。既存アプリ・外部サービス・永続DBへ書き込みません。

```sh
bundle install
bundle exec ruby script/acceptance.rb
```

[検証アプリ](../spec/fixtures/acceptance_app)は本物のAction ControllerのRackリクエスト、Active Recordの保存・commit callback、Action ViewのERB描画を使います。認証済みaccountはテスト専用のRack環境から渡し、認証ライブラリや本番のログイン基盤を再実装しません。

正常なアプリは6契約・40 assertionで、未認証拒否、tenantの境界、validation失敗、成功時の更新、requestなしのmodel操作、一覧の表示を検証します。通常の認証callback、短いCRUD、model validation、トップレベルviewのinstance variableを許容しています。設計方針と事故防止の標準19ルールを使用します。callback制限は標準ONです。この既存契約のfixtureではauthenticate_account!とafter_save_commitのrecord_notificationを明示許可し、認証・commitの挙動を保って検証します。書式はこの検証の対象から外しています。

一度に1箇所を壊し、対応する契約テストが「エラーではなくassertion失敗」で検出すること、公開CLIが1を返すことを確認します。各ケース後に元へ戻します。

| 変更する箇所 | 観測する失敗 | 標準RuboCopの検出 | 文脈／実行での確認 |
| --- | --- | --- | --- |
| account内のfindをglobal findへ変更 | 他accountの行を更新できる | なし | requestとreload |
| 保存失敗後にreloadしてrender | 入力値がDBの値へ戻る | なし | 422のHTMLとDB状態 |
| modelの金額validationを削除 | 負の金額を保存し成功と返す | なし | requestとDB状態 |
| 同名のafter_create_commitとafter_update_commitへ分割 | create時の通知が消える | `Rails/AfterCommitOverride`と`TsurakunaiRails/ModelCallbacks` | model公開APIと通知回数 |
| collection partialでlocalの代わりに@invoiceを読む | 2行目にも1行目のmemoが出る | なし | 一覧の実際の描画。任意ERBセットでも検出 |
| permitにaccount_idを追加 | 通常更新で所有accountを移せる | なし | request後のaccount_id |

任意ERBセットについては、正常partialを通し、入力が食い違うpartialを検出し、lint失敗後も描画テストが走ることを確認します。T07では単一actionのpartialもlocalsが標準です。

CIではこの検証をテストとして実行します。さらに`script/package_smoke.rb`でも、ビルドしたGemを別のbundleへインストールして同じ検証を実行します。ソースだけ動き、配布物が使えない状態を防ぎます。Ruby 3.0・3.1とRuboCop下限ではRails 7.1／SQLite 1系、それ以外では各Rubyで解決できるRails／SQLite 2系を検証します。

## 新規約の代表的な実行

```sh
bundle exec ruby script/team_acceptance.rb
```

[team_app](../spec/fixtures/team_app)はcallbackを使わず、CRUD、modelのconfirm!、app/operations/invoices/settle.rbのcallを本物のActive RecordとSQLiteで実行します。init-policyで生成した規約・profileを使い、公開checkから6契約・30 assertionを実行します。

- CRUDは属性編集だけで、残高・確認状態・送信記録を変えない。保存失敗の値はDBへ入らない。
- modelの状態遷移は明示actorを受けて対象を返す。他accountからのoperationは拒否する。
- operationは請求書確認・残高変更・永続的な未送信記録を一緒にcommitする。途中の残高不足と外側rollbackでは残さない。
- 同一操作の繰り返しは業務例外となり、残高を二度減らさず記録も増やさない。

さらにtransactionを取り除く／identityのtenant条件を存在確認へ弱める変更を一箇所ずつ加え、lintは通っても実DBの契約がassertion失敗で検出することを確認します。別途、業務model hook、operationのCurrent、Concern宣言、actionの暗黙ロードを一例ずつ追加し、実効profileが該当copで拒否することも確認します。

このfixtureのDeliveryは永続する未送信記録で、実際の配信worker・外部決済・分散システムの実装ではありません。SQLiteの逐次実行でPostgreSQLのロックや本番の認可を保証しません。旧アプリの実リクエスト・描画検証と新しい配置・状態・transactionの検証は、ソースbundleと配布Gemの双方で実行します。

## スキルの判断品質

以下の判断評価は設計方針を標準ONにする前の、不具合検出に関する記録です。新しい日常設計方針の検出率を示すものではありません。

上のうち静的検査が通るケースは、[スキルの具体例](../skills/tsurakunai-rails/references/review.md#lintを通過する失敗の追い方)で取得範囲・入力・保存結果・描画結果を追います。独立レビューでは、正解や期待する指摘数を渡さず、6つの回帰と3つの正常なコード例をスキルで判断しました。6つの具体的な問題を特定し、正常な認証callback、単一actionのpartialでのinstance variable、HTTPと無関係なmodelのparams属性には修正を要求しませんでした。これは旧方針での1回の評価です。現在は単一actionのpartialもT07の対象であり、この記録を新規約の判断品質の証明には使いません。

CIはAIレビューを自動実行しません。独立レビューの観測結果はPRへ記録し、モデル全般の検出率や将来の判断を保証したとは扱いません。

## まだ保証しないこと

この検証では本番の認証基盤、PostgreSQL/MySQLの並行更新、外部決済の配信保証、大規模データの性能、Haml/Slim/Turboの全経路は検証していません。それらが変更に関係する場合は、導入先の契約と環境で確認します。lintだけで認可・データ整合性・設計品質を保証するものではありません。
