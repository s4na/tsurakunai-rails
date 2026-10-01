# つらくないRails

Railsの「分かっている人がうまく使う」を、チームとAIでも再現するための小さなハーネスです。標準16ルール・RSpec向け7ルールで重要な構文上の問題を **RuboCop**、業務の文脈が必要な問題を **Codex / Claude Code向けスキル**、実際の振る舞いを **アプリのテスト**で確認します。

書式やメソッドの長さの好みを増やすパッケージではありません。指摘数より、認可漏れ、見えない状態変更、データ破損などの事故を減らすことを優先します。ルールはRails公式の禁止事項ではなく、明示的な実行順序を重視するチーム向けの方針です。

## 導入（Gem + スキル）

Ruby 3.2以上、RuboCop 1.72.1以上 / 2未満が必要です。Railsの起動には依存しません。CIはRuby 3.2・3.3・3.4・4.0とRuboCopの下限で検証します。

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

```sh
# Minitest。プロジェクトで実際に使っているテスト入口を指定する。
bundle exec tsurakunai-rails check -- bin/rails test
# RSpec
bundle exec tsurakunai-rails check -- bundle exec rspec
# RuboCopだけを実行する場合
bundle exec rubocop --only TsurakunaiRails,Rails
```

`check`はこのpluginを明示的に読み込み、lintが失敗してもテストを実行します。両方成功なら0、どちらか失敗なら1、引数や導入先が不正なら2を返します。テストコマンドはシェル展開せず実行するため、パイプやリダイレクトは使えません。

続けてCodexで `$tsurakunai-rails この変更を実装・検証してください`、Claude Codeで `/tsurakunai-rails この変更をレビューしてください` と依頼します。スキルはlint・テストと、文脈を追った設計レビューを両方行い、実行結果・判断根拠・未検証事項を報告します。**CLIの成功は設計レビューの完了ではありません。** 人間も [SKILL.md](skills/tsurakunai-rails/SKILL.md) と [判断例](skills/tsurakunai-rails/references/review.md) をレビュー手順として使えます。

CIには同じ `check -- <テストコマンド>` を置き、PRレビューに意味的レビューの記録を残してください。AIの意味的レビューをCIで自動実行したことにはしません。

## 何を守るか

[ルール一覧](docs/rules.md)に、copごとの採用理由・改善の方向・正当な例外・静的検査の限界をまとめています。

- **標準16ルール**: 独自4ルールにRuboCop Railsの重要な12ルールを組み合わせます。callback・暗黙scope・validation迂回・modelのHTTP依存に加え、永続化APIの上書き、関連・commit hookの重複、enumの値、更新失敗、関連削除、一意index、migrationと応答の事故を扱います。pluginの読み込みだけで上流pluginも読み込みます。
- **RSpec7ルール**: 全instanceのstub、message chain、検査対象のstub、契約を検証しないdouble、種類を指定しない例外assert、setupの上書き、matcherのないexpectを扱います。RSpec以外のプロジェクトへ要求しません。
- **意味的レビュー18領域**: 認可、入力・SQL・出力、DB整合性、削除、更新結果、外部副作用・job、競合、migration、query、時刻・金額、cache・秘密、テスト、controller/modelの責務、複数modelの処理、入力・検索・表示の境界、view/partialの入力、描画の取得と副作用。悪い例・改善案・例外・検証方法を[スキル](skills/tsurakunai-rails/SKILL.md)から必要に応じて読みます。

RSpecセットを使う場合は次を追加します。必要な上流GemもこのGemの依存として導入されます。

```yaml
inherit_gem:
  rubocop-tsurakunai-rails: config/rspec.yml
```

書式やDSL表現の好みに関する上流Rails/RSpecルールはこのセットから一括で有効にしません。既存の方針で追加するルールや例外は導入先の `.rubocop.yml` に明示してください。標準セットの自動修正は無効です。callbackの削除、bang APIやenumへの変更で意味・認可・既存DB値が変わる可能性があるためです。

独自controllerルールは `app/controllers/**/*.rb`（concern含む）、modelルールは `app/models/**/*.rb`（concern含む）を対象にします。継承関係・receiverの型は推論しません。model内の同名の独自APIも検出する可能性があります。異なる配置を使う場合は `Include` を上書きしてください。動的な `send`、別レイヤー、bulk処理、動的optionsは意味的レビューで判断します。上流の一意index検査もschemaや条件によって検査できない場合があり、lint成功だけでDB整合性を保証しません。

## コントローラとモデルの扱い

[責務の判断集](skills/tsurakunai-rails/references/responsibilities.md)に、置き場所の判断と具体例をまとめています。

- controllerは認証・認可・入力・対象取得・業務操作の呼び出し・HTTP応答を扱う。単純なCRUDはそのままでよい。
- modelはデータの不変条件、状態遷移、関連、純粋な業務計算を扱う。必要な値やactorは引数で渡す。
- 複数modelの手順とtransactionは、自然な集約または意味のある操作object等へ明示する。
- 画面固有の入力、複雑な検索、表示の整形は、必要性に応じてform/query/presenter等の境界へ分ける。

「全controllerをserviceへ」「modelは属性だけ」「行数が多いから分割」では判断しません。業務条件の重複、HTTPの暗黙の状態への依存、失敗時の不整合などの具体的な負担を根拠にします。構文だけで検出できるmodel内のHTTP helper呼び出しは `TsurakunaiRails/ModelRequestContext` が扱います。

## ビューの変数とpartial

partialの入力を毎回レビューで探す負担を減らすため、[ERB Lint設定と導入手順](docs/view-inputs.md)も同梱しています。`install-view-lint --strict-locals` と `check --views -- <テストコマンド>` で、対応環境では暗黙の入力・宣言漏れを検出し、実際の描画で渡し忘れを拒否できます。

[ビューの判断集](skills/tsurakunai-rails/references/views.md)で、トップレベルviewのinstance variable、partialへのlocals、必須・任意入力、validation失敗時のform、helper内部のquery・副作用を扱います。再利用partialの暗黙依存を整理し、通常のRailsのviewまで一律に禁止しません。認可はボタンの表示だけで終えず、更新actionでも保証します。ERBはRuboCopとは別のERB Lintで検査し、文脈が必要な部分はスキルと実際の描画テストで確認します。

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
