# 導入と使い方

Ruby 3.0以上、RuboCop 1.74.0以上 / 2未満が必要です。Railsの起動には依存しません。RuboCopの下限は、Rails拡張の設定を断続的に誤検出する不具合が修正された1.74.0です（[修正内容](https://github.com/rubocop/rubocop/commit/f24b7873569dda34c97924ca9d8ca48b8fdee377)）。CIはRuby 3.0・3.1・3.2・3.3・3.4・4.0とRuboCopの下限で検証します。

まだRubyGemsには公開していません。GitHubから導入できます。チームではレビュー済みのcommit SHAを `ref:` に指定し、Gemfile.lockをコミットしてください。

```ruby
# Gemfile
group :development, :test do
  gem "rubocop-tsurakunai-rails",
      git: "https://github.com/s4na/tsurakunai-rails.git",
      branch: "main", require: false
end
```

`.rubocop.yml`に次のplugin設定を追加します。設定ファイルがなければ、この内容で作成できます。Rails Omakase等の別のルールセットは必要ありません。既存の設定がある場合は、その内容を残して追加してください。

```yaml
# .rubocop.yml
plugins:
  - rubocop-tsurakunai-rails
# Railsのバージョンを推定できない構成では、実際の対象版を明示する。
# AllCops:
#   TargetRailsVersion: 7.1
```

```sh
bundle install
# プロジェクト内へ配置する。必要なクライアントだけ実行する。
bundle exec tsurakunai-rails install-skill --target codex
bundle exec tsurakunai-rails install-skill --target claude
```

Codexでは `.agents/skills/tsurakunai-rails/`、Claude Codeでは `.claude/skills/tsurakunai-rails/` に配置します。`--project PATH`で別のプロジェクトを指定できます。配置したファイルをコミットすればチームで共有できます。既存フォルダは上書きしません。更新時はGem同梱の `skills/tsurakunai-rails/` と比較し、ローカル変更を保全してから入れ替えてください。アンインストールは配置したスキルフォルダとGem・plugin設定を取り除きます。

## 使う

既存アプリへの段階導入は[導入ガイド](adoption.md)、具体的に何を検出できたかは[実用検証](acceptance.md)を参照してください。

```sh
# Minitest。プロジェクトで実際に使っているテスト入口を指定する。
bundle exec tsurakunai-rails check -- bin/rails test
# RSpec
bundle exec tsurakunai-rails check -- bundle exec rspec
# RuboCopだけを実行する場合
bundle exec rubocop --only TsurakunaiRails,Rails,RSpec
```

`check`はこのpluginを明示的に読み込み、lintが失敗してもテストを実行します。両方成功なら0、どちらか失敗なら1、引数や導入先が不正なら2を返します。テストコマンドはシェル展開せず実行するため、パイプやリダイレクトは使えません。

Ruby lint・View lint・Testsごとの結果を表示します。`View lint: SKIPPED`は未検査を表し、成功には数えません。viewを含む検査が必要なら、任意ERBセットを導入して`--views`を指定します。

続けてCodexで `$tsurakunai-rails この変更を実装・検証してください`、Claude Codeで `/tsurakunai-rails この変更をレビューしてください` と依頼します。スキルはlint・テストと、文脈を追った設計レビューを両方行い、実行結果・判断根拠・未検証事項を報告します。**CLIの成功は設計レビューの完了ではありません。** 人間も [SKILL.md](../skills/tsurakunai-rails/SKILL.md) と [判断例](../skills/tsurakunai-rails/references/review.md) をレビュー手順として使えます。

CIには同じ `check -- <テストコマンド>` を置き、PRレビューにコードレビューの記録を残してください。AIのコードレビューをCIで自動実行したことにはしません。

## 標準方針を調整する

pluginを追加すると、設計方針8ルールと事故防止8ルール、RSpec7ルールが有効になります。以前のバージョンから更新すると新しい指摘が出るため、[更新時の確認](adoption.md)を先に読んでください。既存の`config/policies.yml`は互換用に残っていますが、指定は不要です。

合わないlintは`.rubocop.yml`で個別にOFFにできます。

```yaml
TsurakunaiRails/ControllerCallbacks:
  Enabled: false
```

スキルのPORO・純粋な計算・ViewComponent等も標準ONです。AIが読む設計方針は[AGENTS.md等への個別OFF](../skills/tsurakunai-rails/references/daily-design.md#方針を個別に外す)で調整します。RuboCopの設定とは別です。

## RSpecとERB

RSpec7ルールはplugin導入で有効になります。対象はRSpecのspecファイルで、RSpec本体をアプリへ追加したり、Minitestを置き換えたりはしません。`rubocop-rspec`は従来からこのGemの依存です。既存の`config/rspec.yml`読み込みも互換のため維持しますが、指定は不要です。

```yaml
RSpec/AnyInstance:
  Enabled: false
```

ERBを使うアプリでは、[ERB用の標準設定](view-inputs.md)と`erb_lint`を導入し、`check --views -- <テストコマンド>`を使います。`--views`なしでは設定があっても未検査です。strict localsは対応するRailsで選べます。ERBを使わないプロジェクトにこの依存は不要です。

各ルールの対象・設定・例外は[ルールの詳細](rules.md)を参照してください。書式やDSLの好みに関するルールは一括で有効にしません。

## 例外と段階導入

標準設定は認証・ロード等のcallbackも検出します。認証基盤などで必要なhookは許可名に指定できます。削除して認証を壊すより、対象を限定した例外を選びます。

```yaml
TsurakunaiRails/ControllerCallbacks:
  Enabled: true
  AllowedMethods:
    - authenticate_user! # 認証基盤の必須hook。request testで未認証拒否を検証。
```

複数のcallbackを同時登録した場合、すべてが許可名でなければ検出します。ブロック・動的な登録は許可名で見逃しません。認証の明示呼び出しへの移行では、redirect後の停止と全actionの認可を必ず確認してください。

個別の保守処理では理由と代替保証をコメントし、該当行または狭い範囲だけ `rubocop:disable` を使えます。既存アプリでは既存規約と新しい標準方針の違いを確認し、合わない項目をOFFにできます。機械的な全件置換は行わず、具体的な問題に関係する機能を最小限に修正・検証します。
