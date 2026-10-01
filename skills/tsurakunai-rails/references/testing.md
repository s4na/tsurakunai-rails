# query・業務値・テスト

## S09 query・一覧・バッチ

**つらい状況**: 一覧の各行で関連を取得し件数に比例してqueryが増える。全件を `to_a`してworkerのメモリが尽きる。sortが同値になるとページ間で欠落や重複が起きる。

**判断と改善**: 表示が読む関連・実際のquery数・想定件数を確認してpreload/includes等を選ぶ。joinへ変えて親が重複したり絞り込みが変わる影響も確認する。全件が不要なら範囲やpaginationを設け、batchは必要な順序・cursor・更新中のデータに対応する。sortには業務に合う安定したtie breakerを持たせる。SQLで集計すべきものをRubyへ全件転送していないか追う。

**例外**: 小さく上限が保証された集合を根拠なくbatchへ変えない。N+1をコードの見た目だけで断定しない。CSVの全件exportは仕様としてあり得るが、そのメモリ・中断・再実行を確認する。

**検証**: 複数の親と子でquery数が件数に比例しないこと、ページ境界と同値sortの結果、代表的な件数でのメモリと実行時間を確認する。単一fixtureだけで性能を保証しない。

## S10 時刻・日付・金額

**つらい状況**: サーバーのzoneと業務zoneで日付が違い、締切や日別集計の対象がずれる。float計算・通貨混在・丸めの位置で請求額が変わる。

**判断と改善**: 保存時刻、表示zone、業務の「一日」や締切を区別する。日付範囲は業務zoneの境界から構築し、夏時間のあるzoneの一日を固定24時間と仮定しない。金額は必要なprecision・scaleのdecimalまたは最小通貨単位のintegerを検討し、通貨、換算、丸めのタイミングを仕様として扱う。実際の値域とDB型を確認する。

**例外**: 経過秒の計算と業務日付は違う。測定・近似値にdecimalを強制しない。通貨ごとの小数桁を無条件に2桁と仮定しない。

**検証**: zoneが異なる日付境界、DST、月末、負数・大きい金額・丸めの境界など、変更した仕様に必要なケースを確認する。境界テストの時刻は固定し、終了後に戻す。

## S12 テストの信頼性

```ruby
# 弱い保証: 実際に保存したか、認可を守ったか分からない
expect(service).to receive(:call)

# 重要な境界の一例（実際のルート・認可に合わせる）
expect do
  patch invoice_path(other_account_invoice), params: { invoice: { memo: "changed" } }
end.not_to change { other_account_invoice.reload.memo }
expect(response).to have_http_status(:not_found)
```

**判断と改善**: 仕様は公開APIの応答、reloadした状態、重要な外部境界への値で検証する。成功だけでなく入力不正、未認証・他tenant、保存失敗、retryや競合の影響があるケースを選ぶ。factoryのcallback、`let!`、共有fixture、全instanceのstubがテストの前提を隠していないか追う。stubは外部ネットワークや時刻などの境界に使い、検査する業務ロジック自身は実行する。doubleが実契約へ対応するか、例外assertが別のエラーでも通らないか確認する。

**例外**: 重要な内部ロジックの単体テストを禁止しない。外部APIを全部実通信に変えない。Minitest/RSpec、factory/fixture、describeの語句、expectの数は好みとして指摘しない。

**検証**: 関係するテストをランダム順で実行し、共有状態・時刻が漏れないことを確認する。期待値は検査対象と同じ計算をコピーして作らず、具体的な仕様から導く。並行性が必要な保証は同一接続で順に呼ぶだけでは成立しない。CIでfocusが残る設定やskipによって必要なケースが走らない可能性も確認する。テスト全体の再設計を依頼と無関係に広げない。

## 仕様を確認する資料

- [Rails query interface](https://guides.rubyonrails.org/active_record_querying.html)
- [Testing Rails](https://guides.rubyonrails.org/testing.html)
- [RSpec verifying doubles](https://rspec.info/features/3-12/rspec-mocks/verifying-doubles/)
