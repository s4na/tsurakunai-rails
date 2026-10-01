# つらくないRails

Railsアプリの日常設計に、おまかせの標準方針を持ち込むRuboCopプラグインとCodex / Claude Code向けスキルです。コントローラーを薄く保ち、業務処理・計算・表示の責務を分け、変更や運用の負担を抑えることを目指します。

**推奨する設計は標準でON。合わない方針だけ個別にOFFにできます。** 動作するかだけでなく、処理をどこに置くかをレビューします。

[導入と使い方](docs/installation.md) · [既存アプリへの導入・更新](docs/adoption.md)

## スキルが標準で確認すること

[tsurakunai-rails](skills/tsurakunai-rails/SKILL.md)は、次の制約を変更コードへ適用します。いずれもAIが文脈を見て判断する方針で、RuboCopが自動検出するものではありません。

- **コントローラーはHTTP処理に限定**: 業務の計算・判断・複数モデルの更新手順を置かない。単純なCRUDと応答の分岐は残す
- **モデルから独立した業務処理はPOROへ**: 見積・帳票・外部連携の手順は通常のRubyオブジェクトへ分離する。validationやレコード自身の状態遷移まで移さない
- **純粋な計算**: 値だけで済む計算は、DB・現在時刻・共有状態から切り離す。必要な値を引数で受け取り、引数を書き換えず結果を返す
- **ViewComponent優先**: 新しい再利用UIはpartialよりcomponentを選ぶ。静的な短い断片や既存component基盤は例外。partialというだけで遅いとは判断しない
- **クエリと描画を分離**: 取得・絞り込み・先読みをviewやhelperに隠さない。複雑な検索はquery objectへ、単純なscopeはそのままにする
- **外部処理と重い処理を明示**: 表示やvalidationに通信を隠さず、失敗・再実行を扱う。大量取得は分割し、job・cacheは必要性と運用負担を見て選ぶ
- **名前で仕事と副作用を示す**: `Manager#process`のような曖昧な名前を避け、対象と操作を表す。Railsや外部APIの決まった名前は維持する

[具体例・例外・個別OFFの書き方](skills/tsurakunai-rails/references/daily-design.md)。変更していないコードの一括改修、全モデルメソッドの切り出し、未承認の依存追加は行いません。認可・保存失敗・描画結果などの正しさは、[レビューガイド](skills/tsurakunai-rails/references/review.md)と実際のテストで確認します。

## RuboCopが自動検出すること

### 設計方針: 標準ON

| ルール | 制約 |
| --- | --- |
| TsurakunaiRails/ControllerCallbacks | controllerのcallbackを使わず処理順を明示する。認証hook等は許可名で残せる |
| TsurakunaiRails/ModelRequestContext | model内でparams・current_user等のHTTPの状態を直接参照しない |
| TsurakunaiRails/DefaultScope | 暗黙の絞り込みを避け、名前のあるscopeを使う |
| TsurakunaiRails/ValidationBypass | validationを省略する更新を通常のモデル操作に混ぜない |
| Rails/EnumHash | enumとDB値の対応を明示する |
| Rails/SaveBang | 保存結果を無視しない。失敗を分岐で扱うnon-bangも許容 |
| Rails/HasManyOrHasOneDependent | 親削除時の関連データの扱いを明示する |
| Rails/UniqueValidationWithoutIndex | 一意性validationに対応するunique indexを設ける |

構文の検出には限界があります。独自APIとの区別や業務上の例外は文脈で確認し、`.rubocop.yml`で個別OFF・許可名・対象範囲を調整します。**lint成功だけで上のスキルの設計方針を満たしたことにはなりません。**

### 補助の事故防止: 標準ON

既存の8ルールも維持します。Active Recordのメソッド上書き、関連・commit callback・enum値の重複、migrationの誤指定、本文を返せないHTTP statusでのrenderを検出します。[cop一覧と限界](docs/rules.md#標準セット)

### RSpec: 標準ON

RSpec7ルールはspecファイルを対象に標準で有効です。RSpec本体の導入やテスト方式の変更は要求しません。instance全体やメソッドチェーンのstub、テスト対象のstub、未検証double、例外の指定漏れ、setupの上書き、matcherの書き忘れを検査します。[7 copの名前と個別OFF](docs/rules.md#rspecセット明示導入)。

### ERB: 利用するアプリで設定する

ERBを使う場合は`erb_lint ~> 0.9`を開発依存へ追加し、`bundle exec tsurakunai-rails install-view-lint`で標準の入力検査を配置します。検証は`check --views -- <テストコマンド>`で実行します。設定後も`--views`なしでは未検査です。[導入とstrict localsの対応条件](docs/view-inputs.md)を確認してください。ViewComponentを強制・変換するlintではありません。

[全copの設定と例外](docs/rules.md)。自動修正は無効です。

## ドキュメント

- [導入と使い方](docs/installation.md)
- [既存アプリへの導入・更新](docs/adoption.md)
- [実際のRailsアプリを使った検証](docs/acceptance.md)
- [開発とテスト](docs/development.md)
- [ルールを追加する基準](docs/design.md) / [リリース手順](docs/releasing.md)

Ruby 3.0以上、RuboCop 1.74.0以上・2未満に対応。RubyGemsには未公開です。[MIT License](LICENSE)
