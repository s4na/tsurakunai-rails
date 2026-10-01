# つらくないRails

Railsの変更をどう作るか、その設計がどこで崩れるかを、別々のスキルで扱います。両方が同じ設計資料を参照し、機械で判定できる構文だけをRuboCop・ERB Lintで検査します。

GitLabの公開コードと37signalsの一次資料を読み、単純なCRUD、振る舞いを持つモデル、必要なPOROを使い分ける方針にしました。特定企業の階層やライブラリを一式コピーするものではありません。[調査根拠と採用判断](skills/tsurakunai-rails/references/daily-design.md#調査から採用したこと)

[導入と使い方](docs/installation.md) · [既存アプリへの導入・更新](docs/adoption.md)

## 使うスキル

- [tsurakunai-rails-implement](skills/tsurakunai-rails-implement/SKILL.md): 利用者の操作から、入口・責務・保存失敗・テストを組み立てる
- [tsurakunai-rails-review](skills/tsurakunai-rails-review/SKILL.md): 境界・状態・副作用が崩れる経路を、編集せず根拠付きで確認する
- [tsurakunai-rails](skills/tsurakunai-rails/SKILL.md): 既存の呼び出し名。依頼に合う実装・レビュー手順へ案内する

`install-skill --target codex`または`--target claude`で3つをまとめて配置します。Codexは`$tsurakunai-rails-implement`、Claude Codeは`/tsurakunai-rails-implement`のように呼びます。

## 実装: どう作るか

- **利用者の操作を入口にする**: routeと近い実装を読み、actor・許可入力・対象scope・成功/失敗の応答を決める
- **単純なCRUDは直接書く**: controller→modelの更新と応答分岐で済むなら、新しいserviceを作らない
- **状態を守るAPIをモデルに置く**: 不変条件・状態遷移を業務名のメソッドへまとめる。関連行を更新するだけでモデル外へ出さない
- **独立した仕事だけ分ける**: 外部I/O・独立計算・複数集約の調整は、追う場所を減らせる単位でPOROへ。値だけの計算に不要なDB・時刻・共有状態を混ぜない
- **失敗を先に扱う**: transaction、保存の戻り値、commit後の副作用、timeoutと再実行の扱いを決める
- **取得と表示の契約を作る**: scope・ページング・関連取得を追えるようにし、明示localsのpartialや利益のあるcomponentを選ぶ
- **公開結果をテストする**: modelとHTTP境界で成功・拒否・失敗後の状態を確認し、変更に関係する再実行やquery数も検証する

例えばタイトル編集は既存controllerとmodelで完結させます。注文と明細の確定はモデルの`confirm!`へ、決済や別集約との調整が加わるなら名前付きの操作へ分けます。最初からService・Concern・POROを一組生成しません。

## レビュー: 何を避けるか

- controllerやcontroller concernに料金計算・承認条件が埋まる
- 別tenantの取得、jobや直接更新による不変条件・認可の迂回が起きる
- 一部だけ保存される、保存失敗を成功扱いする、rollbackした処理の通知が出る
- callback・validation・描画に操作固有の複雑な手順や外部I/Oが隠れる
- 表示する行が増えるほどqueryや状態変更が増える
- 薄い転送クラスや曖昧な名前で、理解するために追う場所だけが増える
- stubやUIテストだけで、重要な状態・失敗・権限を見逃す

callback、Concern、partial、Currentの存在だけでは違反にしません。具体的な経路・結果・保守負担を確認します。設計上の指摘と不具合は分け、未計測の性能を断定しません。[共通資料の対応表・例外](skills/tsurakunai-rails/references/daily-design.md)

## 自動検査の役割

**スキルは文脈を判断し、lintは構文を検出します。** POROやViewComponentがないこと、modelが長いことをlintの合否にしません。

### 設計の制約（標準ON）

- TsurakunaiRails/ModelRequestContext: model内でparams・current_user等のHTTP状態を直接参照しない。同名の業務属性は許可名で残せる
- TsurakunaiRails/DefaultScope: default_scopeを使わず、呼び出し側から分かるscopeで絞り込む
- TsurakunaiRails/ValidationBypass: model内のvalidationを省略する更新APIを検出する。保守処理等の正当な利用は対象限定や個別OFFで扱う
- Rails/EnumHash: enumとDB値の対応をhashで明示する
- Rails/SaveBang: 保存結果を無視しない。成功/失敗を分岐するnon-bangも許容し、暗黙の戻り値は呼び出し元で確認する
- Rails/HasManyOrHasOneDependent: 親削除時の関連データの扱いを明示する。destroyへの一律変更は求めない
- Rails/UniqueValidationWithoutIndex: 一意性validationに対応するunique indexを確認する。schemaや条件によって静的に検査できない場合はレビューで補う

### 事故防止の制約（標準ON）

- Rails/ActiveRecordOverride: Active Recordの標準メソッドを上書きする定義
- Rails/DuplicateAssociation: 同じ名前の関連の重複定義
- Rails/AfterCommitOverride: 同じメソッドのcommit callbackを重複登録して片方を消す定義
- Rails/EnumUniqueness: 異なるenum値に同じDB値を割り当てる定義
- Rails/AddColumnIndex: add_columnにindexを指定しただけで、indexが作成されると期待するコード
- Rails/DangerousColumnNames: Active Recordのメソッドと衝突する列名
- Rails/NotNullColumn: defaultなしのNOT NULL列追加。既存行がある場合の失敗を避け、backfill等を検討する
- Rails/UnusedRenderContent: 本文を返せないHTTP statusで本文をrenderするコード

### RSpecの制約（specファイルで標準ON）

- RSpec/AnyInstance: instance全体をまとめてstubせず、対象instanceを明示する
- RSpec/MessageChain: メソッドチェーンのstubに依存しない
- RSpec/SubjectStub: テスト対象そのものをstubして検査を消さない
- RSpec/VerifiedDoubles: 実際のメソッド定義と照合するdoubleを使う。名前なしdoubleも対象
- RSpec/UnspecifiedException: 期待する例外の種類を指定する
- RSpec/OverwritingSetup: 同じscopeで同名のsetupを上書きしない
- RSpec/VoidExpect: expectにmatcherを書き、結果を検証する

RSpec本体の導入やMinitestの変更は要求しません。境界stubや既存テストの保証は文脈でも確認します。

### ERBと任意の制約

- TsurakunaiPartialInputs: ERB入力設定を導入した場合、partial内のinstance variableを明示localsへ置き換える。通常のviewは対象外
- ParserErrors: 同設定で、ERBの解析エラーを検出する
- StrictLocals: 対応するRailsで`--strict-locals`を選んだ場合、partialの入力を宣言する
- TsurakunaiRails/ControllerCallbacks: 標準OFF。callback全面禁止を選ぶ場合だけONにし、必要な認証hook等は許可名で残す

ERBは`erb_lint ~> 0.9`と`install-view-lint`の設定を導入し、`check --views -- <テストコマンド>`で検査します。`--views`なしでは未検査です。通常はcallbackの有無でなく、隠れた業務フローをスキルで確認します。

推奨するlintは標準ON、不要なcopは`.rubocop.yml`で個別OFFにできます。旧`config/policies.yml`はcallback全面禁止を含む厳格presetとして残しています。構文の指摘だけで不具合と断定せず、許可名・対象範囲・例外を調整します。[詳しい制限と設定](docs/rules.md)。自動修正は無効です。

## ドキュメント

- [導入と更新](docs/installation.md) / [既存アプリでの確認](docs/adoption.md)
- [実Railsアプリの検証と限界](docs/acceptance.md)
- [開発とテスト](docs/development.md) / [設計判断の評価](docs/design.md)
- [リリース手順](docs/releasing.md)

Ruby 3.0以上、RuboCop 1.74.0以上・2未満に対応。RubyGemsには未公開です。[MIT License](LICENSE)
