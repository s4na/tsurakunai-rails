# 既存Railsアプリへ導入する

標準8ルールから始め、変更する機能で役立つかを確認します。Rails Omakase等の別セットは不要です。設計方針・RSpec・ERBセットを全部入れる必要もありません。

## 最初の確認

[導入手順](installation.md)でGemと利用するクライアントのスキルを配置し、既存の `.rubocop.yml` にpluginを追加します。設定がなければ新規作成します。ファイル全体の置き換えや自動修正は不要です。

```sh
# 今回追加するRails検査を先に確認する。
bundle exec rubocop --only Rails,TsurakunaiRails
# プロジェクトの既存検査も含め、実際のテスト入口で確認する。
bundle exec tsurakunai-rails check -- bin/rails test
# RSpecなら: bundle exec tsurakunai-rails check -- bundle exec rspec
```

`Ruby lint`・`Tests`それぞれにPASS/FAILが出ます。lintに失敗してもテストは走ります。`View lint: SKIPPED`はテンプレートを検査していないという意味です。必要な場合だけ[ERB入力セット](view-inputs.md)を明示導入し、`check --views -- ...`を使います。

RuboCopの既存指摘が大量に出ても、今回の8ルールの価値とは分けて判断します。書式の統一や全件置換をこの導入へ混ぜないでください。`DisabledByDefault: true`や既存の個別overrideで検査が無効になる構成もあるため、使いたいcopが有効か確認します。

```sh
bundle exec rubocop --show-cops Rails/AfterCommitOverride TsurakunaiRails/ControllerCallbacks
```

標準の`AfterCommitOverride`は有効、任意の`ControllerCallbacks`は初期無効です。既存方針によるoverrideは尊重します。有効化する範囲は[ルール一覧](rules.md)で選べます。

## 最初の変更で効果を確認する

Codexなら`$tsurakunai-rails この変更をレビューしてください`、Claude Codeなら`/tsurakunai-rails この変更をレビューしてください`と依頼します。以下から、その変更に関係するものだけを判断材料にします。

- controllerの取得・permitが変わる: 他ユーザー／他tenantのIDで拒否され、DBが変わらないか。
- modelの保存条件が変わる: 不正入力の保存結果と、必要ならjob等の入口でも不変条件を保つか。
- validation失敗時のrenderが変わる: errorsと入力値が表示に残るか。
- partialの呼び出し元が増える: 異なるrecordを描画して、表示対象が食い違わないか。

既存テストで保証できるなら追加テストは不要です。指摘には発生条件・実際の結果・最小の修正を求めます。callbackの存在、modelの行数、通常のview変数だけを理由にした書き換えは、このスキルの期待する結果ではありません。

レビュー記録は「実行したコマンドと結果／確認した契約／具体的な指摘または指摘なしの根拠／結果に関係する未確認事項」で十分です。毎回18領域を埋める報告書は不要です。CIの成功と、文脈を追ったレビューの完了は区別します。

## チームで残す価値を判断する

最初の数件の変更で、重要な問題を見つけたか、正当な実装への指摘が多くないか、修正の判断が具体的になったかを確認します。採用した任意ルールが有用な問題を示さず例外ばかり増やすなら、そのcopを無効化または対象限定します。指摘数を増やすためにルールを足しません。

このパッケージで確認した効果と限界は[実用検証](acceptance.md)に記録しています。自分のアプリで同じ結果が出るとは限らないため、導入先の実例で判断してください。
