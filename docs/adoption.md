# 既存Railsアプリへ導入する

設計方針8ルールと事故防止8ルールが標準で有効になります。Rails Omakase等の別セットは不要です。RSpec7ルールも標準ONです。ERBを使うアプリではERB用の設定と依存を導入し、`check --views`を使います。

## 最初の確認

[導入手順](installation.md)でGemと利用するクライアントのスキルを配置し、既存の `.rubocop.yml` にpluginを追加します。設定がなければ新規作成します。ファイル全体の置き換えや自動修正は不要です。

```sh
# 今回追加するRails検査を先に確認する。
bundle exec rubocop --only Rails,TsurakunaiRails,RSpec
# プロジェクトの既存検査も含め、実際のテスト入口で確認する。
bundle exec tsurakunai-rails check -- bin/rails test
# RSpecなら: bundle exec tsurakunai-rails check -- bundle exec rspec
```

`Ruby lint`・`Tests`それぞれにPASS/FAILが出ます。lintに失敗してもテストは走ります。`View lint: SKIPPED`はテンプレートを検査していないという意味です。必要な場合だけ[ERB入力セット](view-inputs.md)を明示導入し、`check --views -- ...`を使います。

RuboCopの既存指摘が大量に出ても、このパッケージの方針とは分けて判断します。書式の統一や全件置換をこの導入へ混ぜないでください。`DisabledByDefault: true`や既存の個別overrideで検査が無効になる構成もあるため、使いたいcopが有効か確認します。

```sh
bundle exec rubocop --show-cops Rails/AfterCommitOverride TsurakunaiRails/ControllerCallbacks
```

`AfterCommitOverride`と`ControllerCallbacks`はいずれも標準で有効です。既存方針によるoverrideは尊重します。合わないcopは[ルール一覧](rules.md)から選び個別にOFFにできます。

## 以前のバージョンから更新する

以前は設計方針8ルールが初期OFF、RSpec7ルールも別途有効化する方式でした。更新後は認証callback、default_scope、validationを省略する更新などにも指摘が出ます。既存の個別`Enabled: false`は引き続き優先されます。全件を機械的に書き換えず、許可名・対象範囲・個別OFFを選んでください。既存の`config/policies.yml`・`config/rspec.yml`読み込みはそのまま使えます。RSpec未使用アプリにRSpec本体は不要です。

スキルも「具体的な不具合だけ」から、日常の設計方針を標準で適用する動作へ変わります。[方針一覧](../skills/tsurakunai-rails/references/daily-design.md)を確認し、導入先のAGENTS.mdやCLAUDE.mdで合わない方針をOFFにできます。インストール済みのスキルは自動更新されないため、ローカル変更を保全してGem同梱版と比較してください。

## 最初の変更で効果を確認する

Codexなら`$tsurakunai-rails この変更をレビューしてください`、Claude Codeなら`/tsurakunai-rails この変更をレビューしてください`と依頼します。以下から、その変更に関係するものだけを判断材料にします。

- controllerに計算や業務判断を追加する: HTTP処理から切り離し、値だけで済む計算を純粋にする。
- 再利用UIを追加する: ViewComponentを選ぶ。静的な短い断片や既存基盤などの例外も確認する。
- controllerの取得・permitが変わる: 他ユーザー／他tenantのIDで拒否され、DBが変わらないか。
- modelの保存条件が変わる: 不正入力の保存結果と、必要ならjob等の入口でも不変条件を保つか。
- validation失敗時のrenderが変わる: errorsと入力値が表示に残るか。
- partialの呼び出し元が増える: 異なるrecordを描画して、表示対象が食い違わないか。

既存テストで保証できるなら追加テストは不要です。不具合には発生条件と実際の結果、設計上の指摘には該当する方針と対象の処理を求めます。modelの行数や通常のview変数だけを理由にした書き換えは要求しません。認証callbackは許可名で残せます。

レビュー記録は「実行したコマンドと結果／確認した契約／具体的な指摘または指摘なしの根拠／結果に関係する未確認事項」で十分です。毎回18領域を埋める報告書は不要です。CIの成功と、文脈を追ったレビューの完了は区別します。

## チームで残す価値を判断する

最初の数件の変更で、重要な問題を見つけたか、正当な実装への指摘が多くないか、修正の判断が具体的になったかを確認します。標準ルールが有用な問題を示さず例外ばかり増やすなら、そのcopを無効化または対象限定します。指摘数を増やすためにルールを足しません。

このパッケージで確認した効果と限界は[実用検証](acceptance.md)に記録しています。自分のアプリで同じ結果が出るとは限らないため、導入先の実例で判断してください。
