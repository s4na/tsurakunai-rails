# リリース

RubyGemsの自動公開はしません。認証情報と公開権限はこのリポジトリに含めません。

1. バージョンを `lib/tsurakunai/rails/version.rb` で更新し、ルールの追加・互換性変更・スキルの変更点をリリース説明に記録する。既定の新ルールは利用側CIを失敗させ得るため、挙動変更として説明する。
2. CI、独立レビュー、`bundle exec ruby script/package_smoke.rb` を完了する。
3. `bundle exec rake build` で `pkg/rubocop-tsurakunai-rails-<version>.gem` を作り、`gem specification <gemのパス>` で同梱内容・依存・メタデータを確認する。
4. メンテナが公開を承認した後だけ `gem push <gemのパス>` を実行し、同じcommitをversion tagとGitHub Releaseにする。
5. 公開済みGemをクリーンな環境で導入し、plugin読み込みと両クライアントのスキル配置を確認する。READMEの導入例を公開済みversionへ更新する。

スキルはGemと同じversionで同梱する。利用側でコピーしたスキルはGem更新だけでは更新されない。更新時はローカル変更と比較して入れ替える。
