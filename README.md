# つらくないRails

Railsの「分かっている人がうまく使う」を、チームとAIでも再現するための小さなハーネスです。重要な構文上の問題を **RuboCop**、業務の文脈が必要な問題を **Codex / Claude Code向けスキル**、実際の振る舞いを **アプリのテスト**で確認します。

書式やメソッドの長さの好みを増やすパッケージではありません。指摘数より、認可漏れ、見えない状態変更、データ破損などの事故を減らすことを優先します。ルールはRails公式の禁止事項ではなく、明示的な実行順序を重視するチーム向けの方針です。

## 導入（Gem + スキル）

Ruby 3.2以上、RuboCop 1.72以上 / 2未満が必要です。Railsの起動には依存しません。CIはRuby 3.2・3.3・3.4・4.0とRuboCopの下限で検証します。

まだRubyGemsには公開していません。GitHubから導入できます。チームではレビュー済みのcommit SHAを `ref:` に指定し、Gemfile.lockをコミットしてください。

```ruby
# Gemfile
group :development, :test do
  gem "rubocop-tsurakunai-rails",
      git: "https://github.com/s4na/tsurakunai-rails.git",
      branch: "main", require: false
end
```

このPRの検証中は `branch: "codex/rails-harness"` を使ってください。マージ後は `main` に変更します。既存のRuboCop / Omakase設定に、次を**追加**します。

```yaml
# .rubocop.yml
plugins:
  - rubocop-tsurakunai-rails
```

```sh
bundle install
# プロジェクト内へ配置する。必要なクライアントだけ実行する。
bundle exec tsurakunai-rails install-skill --target codex
bundle exec tsurakunai-rails install-skill --target claude
```

Codexでは `.agents/skills/tsurakunai-rails/`、Claude Codeでは `.claude/skills/tsurakunai-rails/` に配置します。`--project PATH`で別のプロジェクトを指定できます。配置したファイルをコミットすればチームで共有できます。既存フォルダは上書きしません。更新時はGem同梱の `skills/tsurakunai-rails/` と比較し、ローカル変更を保全してから入れ替えてください。アンインストールは配置したスキルフォルダとGem・plugin設定を取り除きます。

## 使う

```sh
# Minitest。プロジェクトで実際に使っているテスト入口を指定する。
bundle exec tsurakunai-rails check -- bin/rails test
# RSpec
bundle exec tsurakunai-rails check -- bundle exec rspec
# RuboCopだけを実行する場合
bundle exec rubocop --only TsurakunaiRails
```

`check`はこのpluginを明示的に読み込み、lintが失敗してもテストを実行します。両方成功なら0、どちらか失敗なら1、引数や導入先が不正なら2を返します。テストコマンドはシェル展開せず実行するため、パイプやリダイレクトは使えません。

続けてCodexで `$tsurakunai-rails この変更を実装・検証してください`、Claude Codeで `/tsurakunai-rails この変更をレビューしてください` と依頼します。スキルはlint・テストと、文脈を追った設計レビューを両方行い、実行結果・判断根拠・未検証事項を報告します。**CLIの成功は設計レビューの完了ではありません。** 人間も [SKILL.md](skills/tsurakunai-rails/SKILL.md) と [判断例](skills/tsurakunai-rails/references/review.md) をレビュー手順として使えます。

CIには同じ `check -- <テストコマンド>` を置き、PRレビューに意味的レビューの記録を残してください。AIの意味的レビューをCIで自動実行したことにはしません。

## 何を守るか

| 問題 | 担当 | 初期方針 |
| --- | --- | --- |
| controller callbackによる暗黙の実行順序 | `TsurakunaiRails/ControllerCallbacks` | before / after / aroundとprepend / append、旧filter名を検出 |
| 暗黙の絞り込み・作成時の既定値 | `TsurakunaiRails/DefaultScope` | `default_scope`を検出し、名前付きscopeへ |
| 検証を迂回する個別更新 | `TsurakunaiRails/ValidationBypass` | `update_attribute(!)`、`update_column(s)`、`save(!)(validate: false)`を検出 |
| 認可・テナント境界・DB制約・競合 | スキル + テスト | 具体的な失敗シナリオに基づき判断 |
| transactionと外部副作用・再試行 | スキル + テスト | rollback、重複、配信保証の必要性を確認 |
| migration・N+1・テストの保証 | スキル + テスト | 変更の影響と観測できる振る舞いを確認 |

controllerルールは `app/controllers/**/*.rb`（concern含む）、modelルールは `app/models/**/*.rb`（concern含む）を対象にします。継承関係・receiverの型は推論しません。model内の同名の独自APIも検出する可能性があります。異なる配置を使う場合は `Include` を上書きしてください。動的な `send`、別レイヤー、`update_all` / `insert_all`などのbulk処理、動的なvalidation optionsは意味的レビューで判断します。DB制約で保証されたbulk処理まで一律禁止しません。

3ルールとも自動修正しません。callbackの削除で認証が落ちたり、更新APIの差し替えでcallbackや性能が変わるためです。

## 例外と段階導入

認証ライブラリなどで必要なcallbackは、その用途を確認して対象を絞って許可できます。

```yaml
TsurakunaiRails/ControllerCallbacks:
  AllowedMethods:
    - authenticate_user! # 認証基盤の必須hook。request testで未認証拒否を検証。
```

複数のcallbackを同時登録した場合、すべてが許可名でなければ検出します。ブロック・動的な登録は許可名で見逃しません。認証の明示呼び出しへの移行では、redirect後の停止と全actionの認可を必ず確認してください。

個別の保守処理では理由と代替保証をコメントし、該当行または狭い範囲だけ `rubocop:disable` を使えます。既存アプリでは最初に `--only TsurakunaiRails` で棚卸しし、機械的に全件置換せず、変更する機能から認可・状態のテストを追加します。変更しない既存領域を一時的に `Exclude` する場合は担当と解消条件を記録します。全体無効化や大量のtodo生成を初手にしません。

## 開発と品質

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

[ルール設計と追加基準](docs/design.md) / [リリース手順](docs/releasing.md) / [MIT License](LICENSE)
