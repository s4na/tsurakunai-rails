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
bundle exec rubocop --only TsurakunaiRails,Rails
```

`check`はこのpluginを明示的に読み込み、lintが失敗してもテストを実行します。両方成功なら0、どちらか失敗なら1、引数や導入先が不正なら2を返します。テストコマンドはシェル展開せず実行するため、パイプやリダイレクトは使えません。

Ruby lint・View lint・Testsごとの結果を表示します。`View lint: SKIPPED`は未検査を表し、成功には数えません。viewを含む検査が必要なら、任意ERBセットを導入して`--views`を指定します。

続けてCodexで `$tsurakunai-rails この変更を実装・検証してください`、Claude Codeで `/tsurakunai-rails この変更をレビューしてください` と依頼します。スキルはlint・テストと、文脈を追った設計レビューを両方行い、実行結果・判断根拠・未検証事項を報告します。**CLIの成功は設計レビューの完了ではありません。** 人間も [SKILL.md](../skills/tsurakunai-rails/SKILL.md) と [判断例](../skills/tsurakunai-rails/references/review.md) をレビュー手順として使えます。

CIには同じ `check -- <テストコマンド>` を置き、PRレビューにコードレビューの記録を残してください。AIのコードレビューをCIで自動実行したことにはしません。

## 任意のルールセットを使う

RSpecの追加検査を使う場合は、`.rubocop.yml`へ次を追加します。

```yaml
inherit_gem:
  rubocop-tsurakunai-rails: config/rspec.yml
```

設計方針セットの全8ルールも採用する場合は、同じ配列へ追加します。必要なルールだけを個別に有効化しても構いません。

```yaml
inherit_gem:
  rubocop-tsurakunai-rails:
    - config/policies.yml
    - config/rspec.yml
```

RSpec用の依存Gemも、このGemと一緒に導入されます。書式やDSLの好みに関するルールを一括で有効にはしません。追加したいルールは、導入先の`.rubocop.yml`で指定してください。

各ルールの対象・設定・例外は[ルールの詳細](rules.md)を参照してください。ERBの検査には[別の導入手順](view-inputs.md)があります。

## 例外と段階導入

標準設定では認証・ロード等のcallbackを使うだけで指摘しません。callback禁止の方針を明示採用した場合は、必要なcallbackを許可できます。

```yaml
TsurakunaiRails/ControllerCallbacks:
  Enabled: true
  AllowedMethods:
    - authenticate_user! # 認証基盤の必須hook。request testで未認証拒否を検証。
```

複数のcallbackを同時登録した場合、すべてが許可名でなければ検出します。ブロック・動的な登録は許可名で見逃しません。認証の明示呼び出しへの移行では、redirect後の停止と全actionの認可を必ず確認してください。

個別の保守処理では理由と代替保証をコメントし、該当行または狭い範囲だけ `rubocop:disable` を使えます。既存アプリでは標準設定から始め、必要な方針だけを選びます。選んでいない方針のために例外を記録する必要はありません。機械的な全件置換は行わず、具体的な問題に関係する機能を最小限に修正・検証します。
