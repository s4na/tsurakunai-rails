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

Codexでは`.agents/skills/`、Claude Codeでは`.claude/skills/`配下に、`tsurakunai-rails`・`tsurakunai-rails-implement`・`tsurakunai-rails-review`の3フォルダを配置します。共通資料は`tsurakunai-rails/references/`に一度だけ置き、他の2つが参照します。`--project PATH`で別のプロジェクトを指定できます。配置したファイルをコミットすればチームで共有できます。いずれかの既存フォルダがあれば、全体の配置を始めず終了します。既存ファイルは上書きしません。更新時はGem同梱の`skills/`の3フォルダと比較し、ローカル変更を保全してから入れ替えてください。更新・アンインストールは3フォルダを一組として扱います。旧版の1フォルダだけを残すと、新しい相互参照は使えません。アンインストール時はGem・plugin設定も取り除きます。

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

実装するときはCodexで`$tsurakunai-rails-implement この変更を実装してください`、レビューでは`$tsurakunai-rails-review この変更を編集せず確認してください`と呼びます。Claude Codeは先頭を`/`にします。既存の`tsurakunai-rails`も両手順へ案内する入口として残ります。

実装スキルは入口・状態・失敗・テストを作る手順、レビュースキルは崩れる経路を確認する手順です。[共通資料](../skills/tsurakunai-rails/references/daily-design.md)を共有します。**CLIの成功は文脈レビューの完了ではありません。** CIはAIの判断を自動実行しません。

## 標準方針を調整する

pluginを追加すると、設計方針7ルールと事故防止8ルール、RSpec7ルールが有効になります。以前のバージョンから更新すると新しい指摘が出るため、[更新時の確認](adoption.md)を先に読んでください。既存の`config/policies.yml`はControllerCallbacksの全面禁止も有効にする厳格presetとして残っています。通常の導入では不要です。

合わないlintは`.rubocop.yml`で個別にOFFにできます。

```yaml
TsurakunaiRails/ControllerCallbacks:
  Enabled: false
```

実装・レビューでは[共通の設計判断](../skills/tsurakunai-rails/references/daily-design.md#導入先に合わせる)を標準で使います。AGENTS.md等の既存規約や方針をOFFにする指示を優先します。RuboCopの設定とは別です。

## RSpecとERB

RSpec7ルールはplugin導入で有効になります。対象はRSpecのspecファイルで、RSpec本体をアプリへ追加したり、Minitestを置き換えたりはしません。`rubocop-rspec`は従来からこのGemの依存です。既存の`config/rspec.yml`読み込みも互換のため維持しますが、指定は不要です。

```yaml
RSpec/AnyInstance:
  Enabled: false
```

ERBを使うアプリでは、[ERB用の標準設定](view-inputs.md)と`erb_lint`を導入し、`check --views -- <テストコマンド>`を使います。`--views`なしでは設定があっても未検査です。strict localsは対応するRailsで選べます。ERBを使わないプロジェクトにこの依存は不要です。

各ルールの対象・設定・例外は[ルールの詳細](rules.md)を参照してください。書式やDSLの好みに関するルールは一括で有効にしません。

## 例外と段階導入

callback全面禁止は標準OFFです。厳格presetや個別設定でONにする場合も、認証基盤などで必要なhookは許可名で残せます。

```yaml
TsurakunaiRails/ControllerCallbacks:
  Enabled: true
  AllowedMethods:
    - authenticate_user! # 認証基盤の必須hook。request testで未認証拒否を検証。
```

複数のcallbackを同時登録した場合、すべてが許可名でなければ検出します。ブロック・動的な登録は許可名で見逃しません。認証の明示呼び出しへの移行では、redirect後の停止と全actionの認可を必ず確認してください。

個別の保守処理では理由と代替保証をコメントし、該当行または狭い範囲だけ `rubocop:disable` を使えます。既存アプリでは既存規約と新しい標準方針の違いを確認し、合わない項目をOFFにできます。機械的な全件置換は行わず、具体的な問題に関係する機能を最小限に修正・検証します。
