# 開発とテスト

開発用Bundlerは2.5.23を使い、Ruby 3.0・3.1では実用検証用のRails 7.1／SQLite 1系を選びます。このRails依存はリポジトリの開発用で、配布Gemには追加しません。

```sh
bundle install
bundle exec rake spec
bundle exec ruby script/validate_skill.rb
bundle exec rubocop
bundle exec ruby script/package_smoke.rb
bundle exec rake build
actionlint
zizmor --offline .github/workflows
```

CIはcopの正常系・違反・例外・対象パス・非自動修正、CLIの失敗時の継続と既存ファイル保護、ビルドしたGemの実インストール・利用まで確認します。GitHub ActionsはSHA固定・read-only権限・認証情報を残さないcheckoutにし、actionlintとzizmorで検証します。

[Railsの実用検証](acceptance.md)では、6つの正常な契約と6つの回帰を実際のリクエスト・SQLite・描画で確認し、配布Gemでも同じ公開CLIを実行します。

[ルール設計と追加基準](design.md) / [リリース手順](releasing.md) / [MIT License](../LICENSE)
