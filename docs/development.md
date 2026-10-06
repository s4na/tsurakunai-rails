# 開発とテスト

開発用Bundlerは2.5.23を使い、Ruby 3.0・3.1では実用検証用のRails 7.1／SQLite 1系を選びます。このRails依存はリポジトリの開発用で、配布Gemには追加しません。

```sh
bundle install
bundle exec rake spec
bundle exec ruby script/validate_skill.rb
bundle exec ruby script/team_acceptance.rb
bundle exec rubocop
bundle exec ruby script/package_smoke.rb
bundle exec rake build
actionlint
zizmor --offline .github/workflows
```

CIはcopの正常系・違反・例外・対象パス・非自動修正、CLIの失敗時の継続、AIルールの表示・配置と有効な既存指示・symlinkの保護、ビルドしたGemの実インストール・利用まで確認します。GitHub ActionsはSHA固定・read-only権限・認証情報を残さないcheckoutにし、actionlintとzizmorで検証します。

[Railsの実用検証](acceptance.md)では、6つの正常な契約と6つの回帰を実際のリクエスト・SQLite・描画で確認し、配布Gemでも同じ公開CLIを実行します。

スキル構造の検査は文章の意味を保証しません。規約の必須条件・禁止形・正常例・明示例外の判断は、期待解答を渡さない独立した担当の課題実行で確認し、[評価記録](improvement.md)に残します。

[ルール設計と追加基準](design.md) / [リリース手順](releasing.md) / [MIT License](../LICENSE)

新しい標準規約の公開経路は[team_app](../spec/fixtures/team_app)とscript/team_acceptance.rbで、生成profile・実DB・禁止構文・lintを通る2つの回帰を検証します。[棚卸しと改善フロー](improvement.md)へ判断品質と実行結果を残します。
