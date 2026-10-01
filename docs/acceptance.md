# 実用検証と限界

ルールの数ではなく、正当なRailsコードを通し、具体的な失敗を発見できるかを確認します。ここで使うのは検証用の小さな請求書アプリです。第三者の本番アプリでの実績や、開発時間の削減率を示すものではありません。

## 再現する

このリポジトリの開発依存を導入して実行します。アプリは一時フォルダへ複製し、DBはプロセスごとのSQLiteメモリDBです。既存アプリ・外部サービス・永続DBへ書き込みません。

```sh
bundle install
bundle exec ruby script/acceptance.rb
```

[検証アプリ](../spec/fixtures/acceptance_app)は本物のAction ControllerのRackリクエスト、Active Recordの保存・commit callback、Action ViewのERB描画を使います。認証済みaccountはテスト専用のRack環境から渡し、認証ライブラリや本番のログイン基盤を再実装しません。

正常なアプリは6契約・40 assertionで、未認証拒否、tenantの境界、validation失敗、成功時の更新、requestなしのmodel操作、一覧の表示を検証します。通常の認証callback、短いCRUD、model validation、トップレベルviewのinstance variableを許容しています。標準8ルールを使用し、任意の設計方針は採用していません。書式はこの検証の対象から外しています。

一度に1箇所を壊し、対応する契約テストが「エラーではなくassertion失敗」で検出すること、公開CLIが1を返すことを確認します。各ケース後に元へ戻します。

| 変更する箇所 | 観測する失敗 | 標準RuboCopの検出 | 文脈／実行での確認 |
| --- | --- | --- | --- |
| account内のfindをglobal findへ変更 | 他accountの行を更新できる | なし | requestとreload |
| 保存失敗後にreloadしてrender | 入力値がDBの値へ戻る | なし | 422のHTMLとDB状態 |
| modelの金額validationを削除 | 負の金額を保存し成功と返す | なし | requestとDB状態 |
| 同名のafter_create_commitとafter_update_commitへ分割 | create時の通知が消える | `Rails/AfterCommitOverride` | model公開APIと通知回数 |
| collection partialでlocalの代わりに@invoiceを読む | 2行目にも1行目のmemoが出る | なし | 一覧の実際の描画。任意ERBセットでも検出 |
| permitにaccount_idを追加 | 通常更新で所有accountを移せる | なし | request後のaccount_id |

任意ERBセットについては、正常partialを通し、入力が食い違うpartialを検出し、lint失敗後も描画テストが走ることを確認します。単一actionのpartialまでlocalsを必須にする方針は、チームが選ぶ場合だけです。

CIではこの検証をテストとして実行します。さらに`script/package_smoke.rb`でも、ビルドしたGemを別のbundleへインストールして同じ検証を実行します。ソースだけ動き、配布物が使えない状態を防ぎます。Ruby 3.0・3.1とRuboCop下限ではRails 7.1／SQLite 1系、それ以外では各Rubyで解決できるRails／SQLite 2系を検証します。

## スキルの判断品質

上のうち静的検査が通るケースは、[スキルの具体例](../skills/tsurakunai-rails/references/review.md#lintを通過する失敗の追い方)で取得範囲・入力・保存結果・描画結果を追います。独立レビューでは、正解や期待する指摘数を渡さず、6つの回帰と3つの正常なコード例をスキルで判断しました。6つの具体的な問題を特定し、正常な認証callback、単一actionのpartialでのinstance variable、HTTPと無関係なmodelのparams属性には修正を要求しませんでした。この1回の評価で検出漏れ・不要な指摘はありませんでした。

CIはAIレビューを自動実行しません。独立レビューの観測結果はPRへ記録し、モデル全般の検出率や将来の判断を保証したとは扱いません。

## まだ保証しないこと

この検証では本番の認証基盤、PostgreSQL/MySQLの並行更新、外部決済の配信保証、大規模データの性能、Haml/Slim/Turboの全経路は検証していません。それらが変更に関係する場合は、導入先の契約と環境で確認します。lintだけで認可・データ整合性・設計品質を保証するものではありません。
