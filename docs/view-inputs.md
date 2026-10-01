# 変数を追い回さないビューへの導入

再利用partialの入力を明示し、渡し忘れは描画時に失敗させる。controllerの失敗経路まで表示をテストする。この三つを組み合わせて、レビューする人が暗黙の変数を毎回探す負担を減らします。この入力規約を採用したいチーム向けの任意セットです。単一action専用のpartialが正しい対象を表示しているなら、instance variableの存在だけで移行を要求しません。

新しい再利用UIには[ViewComponentを優先する方針](../skills/tsurakunai-rails/references/daily-design.md#viewcomponent優先)を適用します。このERBセットは既存partialや例外として残すERB向けです。componentの採用を自動判定したり、partialを変換したりはしません。

## 設定して一度に検証する

Gemfileの開発・テスト用groupへ、未導入なら次を追加します。

```ruby
gem "erb_lint", "~> 0.9", require: false
```

`bundle install` 後、プロジェクトのrootで実行します。

```sh
# 明示的なpartial入力の方針を選び、Rails/template engineが対応する場合
bundle exec tsurakunai-rails install-view-lint --strict-locals
bundle exec tsurakunai-rails check --views -- bin/rails test
# RSpecの場合は末尾を bundle exec rspec にする
```

`install-view-lint` は `.erb_lint.yml` と `.erb_linters/tsurakunai_partial_inputs.rb` を配置し、既存ファイルを上書きしません。既存設定がある場合はGem内の `config/erb_lint_strict.yml` の必要な項目を手動でマージし、custom linter用のloaderに `require "tsurakunai/rails/erb_lint/partial_inputs"` を配置します。入力規約を選び、strict localsが非対応のRailsでは `--strict-locals` を省略します。Haml/Slim等の既存linterはそのプロジェクトの入口で実行します。

`check --views` はRuby lint・ERB lint・指定テストを実行し、どれかが失敗すれば終了コード1にします。lintの失敗やERB設定の不足でもテストを実行します。`--views` なしの既存動作は同じです。CIにも同じコマンドを配置します。

## 少ないルールで入力を固定する

対象は `app/views/**/*.html.erb` です。variants、text/js ERB、Haml/Slimの検査をしたとは扱いません。必要な対象と既存linterに合わせて設定を調整します。

- **TsurakunaiPartialInputs**: `_` で始まるpartial内のRubyのinstance variableを検出します。通常のviewの `@invoice` は許容します。ERBのRuby tokenを読むため、HTML本文・コメント・通常の文字列中の `@invoice` は指摘せず、文字列の式展開とblock条件内の依存は指摘します。動的な `instance_variable_get` やhelper内の依存はスキルで追います。
- **ParserErrors**: ERBの構造上の解析エラーを報告します。すべてのRubyの構文・出力安全性を保証するものではありません。
- **StrictLocals**（対応環境で選択）: partialの入力宣言を求めます。宣言があるだけで呼び出し元が正しいとは保証しません。実際の描画でRailsが必須入力不足や未知の入力を拒否することも確認します。

書式やタグの好みのルールは有効にしません。自動修正は実行せず、partialとすべてのrender呼び出し元を一緒に直します。`StrictLocals` の自動修正で空の入力宣言だけを足すと、必要な入力を壊す可能性があります。

## 入力の規約を選んだpartialから移す

1. partialの `@invoice`、表示フラグ、helperの隠れた依存を調べ、renderの呼び出し元を列挙する。業務上の必須入力と任意の装飾を分ける。
2. recordは `invoice:` 等のlocalへ渡し、partialも同じlocalを使う。collectionのlocal名も揃える。呼び出し元だけを変更して終えない。
3. 対応環境では `<%# locals: (invoice:, can_edit:) %>` のように必須入力を宣言する。安全なdefaultが仕様として決まる任意入力だけにdefaultを付ける。
4. 通常の描画、異なるrecordと権限条件、validation失敗時のerrors・入力値・選択肢を確認する。ボタン非表示に加え、直接の更新requestでも認可を確認する。

導入範囲は再利用するpartial等に絞れます。既存の全partialへ規約を広げる必要はありません。規約を選んだ範囲で必要なら、ERB Lintのlinter単位の `exclude` や狭い `erb_lint:disable TsurakunaiPartialInputs` で理由つきの移行例外を残します。ファイルを全検査からexcludeすると構造の検査も失うため、必要なlinterだけの例外を優先します。

## 自動検査で残る部分

validation失敗時の変数不足、tenantの取得範囲、helper内部のN+1、描画によるDB更新や外部副作用は、変数名の検査だけで判定できません。[ビューのレビューガイド](../skills/tsurakunai-rails/references/views.md)で該当する呼び出し元を追い、実際のrequest/renderで結果を確認します。cache hitだけで確認を終えず、必要に応じてmiss・再描画も確認します。

ERB Lintの役割・設定・狭い例外は[公式ドキュメント](https://github.com/Shopify/erb_lint)、strict localsの振る舞いは[Rails Action View](https://guides.rubyonrails.org/action_view_overview.html#strict-locals)を確認します。
