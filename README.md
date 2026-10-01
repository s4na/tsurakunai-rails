# つらくないRails

Railsの「分かっている人がうまく使う」を、チームとAIでも再現するための小さなハーネスです。標準8ルールと任意の設計方針・RSpecセットで重要な構文上の問題を **RuboCop**、業務の文脈が必要な問題を **Codex / Claude Code向けスキル**、実際の振る舞いを **アプリのテスト**で確認します。

書式やメソッドの長さの好みを増やすパッケージではありません。指摘数より、認可漏れ、見えない状態変更、データ破損などの事故を減らすことを優先します。標準は構文上の事故に絞り、callback禁止やモデルのHTTP依存検出などの設計方針は初期無効です。スキルも具体的な失敗の根拠がある場合に指摘します。

## 導入（Gem + スキル）

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

既存アプリへの段階導入は[導入ガイド](docs/adoption.md)、具体的に何を検出できたかは[実用検証](docs/acceptance.md)を参照してください。

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

続けてCodexで `$tsurakunai-rails この変更を実装・検証してください`、Claude Codeで `/tsurakunai-rails この変更をレビューしてください` と依頼します。スキルはlint・テストと、文脈を追った設計レビューを両方行い、実行結果・判断根拠・未検証事項を報告します。**CLIの成功は設計レビューの完了ではありません。** 人間も [SKILL.md](skills/tsurakunai-rails/SKILL.md) と [判断例](skills/tsurakunai-rails/references/review.md) をレビュー手順として使えます。

CIには同じ `check -- <テストコマンド>` を置き、PRレビューに意味的レビューの記録を残してください。AIの意味的レビューをCIで自動実行したことにはしません。

## 何を守るか

[ルール一覧](docs/rules.md)に、copごとの採用理由・改善の方向・正当な例外・静的検査の限界をまとめています。

| セット | 有効になる条件 | 主な検査内容・詳細 |
| --- | --- | --- |
| 標準8ルール | plugin導入で有効 | API・関連・commit hookの上書き、enum値の重複、migration・応答の事故。[一覧](docs/rules.md#標準セット) |
| 設計方針8ルール | 必要なcopを個別採用 | callback・default scope・validation迂回・modelのHTTP依存等。正当な使い方もあるため初期無効。[一覧と境界](docs/rules.md#設計方針セット任意) |
| RSpec7ルール | `config/rspec.yml`を明示導入 | stub・double・例外の期待・setup・matcherの検査。[一覧](docs/rules.md#rspecセット明示導入) |
| ERB入力セット | 設定と依存を明示導入 | partialの入力・構造を検査。対応環境ではstrict localsも選択。[導入・対象・制限](docs/view-inputs.md) |

構文の検出を業務上の欠陥と同一視せず、意図と呼び出し元を確認して修正します。未採用の方針に合わせた修正や例外コメントは不要です。

方針の採用例（callbackを使わない規約をチームで選んだ場合だけ）:

```yaml
TsurakunaiRails/ControllerCallbacks:
  Enabled: true
  AllowedMethods:
    - authenticate_user!
```

全8方針を採用すると決めた場合は `config/policies.yml` を `inherit_gem` で読み込めます。RSpecセットと両方を使う場合は、同じGemの配列へ `config/policies.yml` と `config/rspec.yml` を指定します。全方針の導入は必須ではありません。

RSpecセットを使う場合は次を追加します。必要な上流GemもこのGemの依存として導入されます。

```yaml
inherit_gem:
  rubocop-tsurakunai-rails: config/rspec.yml
```

書式やDSL表現の好みに関する上流Rails/RSpecルールはこのセットから一括で有効にしません。既存の方針で追加するルールや例外は導入先の `.rubocop.yml` に明示してください。標準セットの自動修正は無効です。callbackの削除、bang APIやenumへの変更で意味・認可・既存DB値が変わる可能性があるためです。

独自controllerルールは `app/controllers/**/*.rb`（concern含む）、modelルールは `app/models/**/*.rb`（concern含む）を対象にします。継承関係・receiverの型は推論しません。model内の同名の独自APIも検出する可能性があります。異なる配置を使う場合は `Include` を上書きしてください。動的な `send`、別レイヤー、bulk処理、動的optionsは意味的レビューで判断します。上流の一意index検査もschemaや条件によって検査できない場合があり、lint成功だけでDB整合性を保証しません。

## スキルの内容

Codex / Claude Code向けの `tsurakunai-rails` は、lintで分からない業務の文脈を追って実装・レビューを行います。導入と呼び出しは次のとおりです。必要なクライアントだけ導入します。

```sh
bundle exec tsurakunai-rails install-skill --target codex
bundle exec tsurakunai-rails install-skill --target claude
```

- Codex: `$tsurakunai-rails この変更を実装・検証してください`
- Claude Code: `/tsurakunai-rails この変更をレビューしてください`

スキルは次の判断集から、変更に関係する領域だけを読みます。18領域の個別一覧は[ルール一覧](docs/rules.md#意味的レビューの18領域)へまとめています。

| 判断集 | 扱う内容 |
| --- | --- |
| [責務](skills/tsurakunai-rails/references/responsibilities.md) | controller・modelの不変条件、複数modelの処理、入力・検索・表示 |
| [ビュー](skills/tsurakunai-rails/references/views.md) | partialの入力、失敗時の表示、描画の取得・副作用 |
| [データ](skills/tsurakunai-rails/references/data.md) | DB整合性・削除・保存結果・競合・migration |
| [境界](skills/tsurakunai-rails/references/boundaries.md) | 認証・認可・tenant、SQL・出力、外部副作用、cache・秘密 |
| [運用とテスト](skills/tsurakunai-rails/references/testing.md) | query・一覧・時刻・金額・テストの保証 |

全18領域を毎回点検せず、変更に関係するものだけ確認します。既存設計が契約を満たしていれば維持し、callback・service・instance variableの存在、命名や行数を理由に指摘しません。指摘には発生条件、期待と実際の差、具体的な損害、最小の修正と必要な検証を示します。正当な部分stubや既存テストの保証も尊重し、全local化・クラス抽出・網羅性だけを理由にした追加テストを要求しません。

実行手順と指摘基準は[スキル本体](skills/tsurakunai-rails/SKILL.md)を参照してください。

## コントローラとモデルの扱い

[責務の判断集](skills/tsurakunai-rails/references/responsibilities.md)に、置き場所の判断と具体例をまとめています。

- controllerは認証・認可・入力・対象取得・業務操作の呼び出し・HTTP応答を扱う。単純なCRUDはそのままでよい。
- modelはデータの不変条件、状態遷移、関連、純粋な業務計算を扱う。必要な値やactorは引数で渡す。
- 複数modelの手順とtransactionは、自然な集約または意味のある操作object等へ明示する。
- 画面固有の入力、複雑な検索、表示の整形は、必要性に応じてform/query/presenter等の境界へ分ける。

「全controllerをserviceへ」「modelは属性だけ」「行数が多いから分割」では判断しません。業務条件の重複、HTTPの暗黙の状態への依存、失敗時の不整合などの具体的な負担を根拠にします。任意の `TsurakunaiRails/ModelRequestContext` はmodel内の特定名の呼び出しを検出し、実際のHTTP依存かどうかは文脈で判断します。

## ビューの変数とpartial

複数入口の表示対象の食い違い等を解消する選択肢として、[ERB Lint設定と導入手順](docs/view-inputs.md)も同梱しています。`install-view-lint --strict-locals` と `check --views -- <テストコマンド>` で、対応環境では暗黙の入力・宣言漏れを検出し、実際の描画で渡し忘れを拒否できます。

[ビューの判断集](skills/tsurakunai-rails/references/views.md)で、トップレベルviewのinstance variable、partialへのlocals、必須・任意入力、validation失敗時のform、helper内部のquery・副作用を扱います。再利用partialの暗黙依存を整理し、通常のRailsのviewまで一律に禁止しません。認可はボタンの表示だけで終えず、更新actionでも保証します。ERBはRuboCopとは別のERB Lintで検査し、文脈が必要な部分はスキルと実際の描画テストで確認します。

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

## 開発と品質

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

[Railsの実用検証](docs/acceptance.md)では、6つの正常な契約と6つの回帰を実際のリクエスト・SQLite・描画で確認し、配布Gemでも同じ公開CLIを実行します。

[ルール設計と追加基準](docs/design.md) / [リリース手順](docs/releasing.md) / [MIT License](LICENSE)
