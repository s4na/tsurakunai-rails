# つらくないためのルール一覧

日常設計のスキル方針を主軸に、設計方針7ルールと補助の事故防止8ルールを標準で有効にします。RSpec向け7ルールも標準ON、ERB入力検査はERB利用アプリで設定します。既存copはRuboCop Rails / RSpecを利用し、同じ検査を再実装しません。設計方針・事故防止の両セットはplugin読み込みだけで有効になります。RSpecもplugin読み込みで有効です。既存の`config/rspec.yml`は互換用に残しています。

lintの指摘だけでは不具合と断定できません。実際の型、データ、呼び出し元を確認して修正の要否を判断します。新しいDB制約・削除・例外を機械的に導入しません。導入先の明示設定が優先されます。

[スキルの具体的な設計方針と個別OFF](../skills/tsurakunai-rails/references/daily-design.md)は別に定めます。実装スキルは良い形を選ぶ手順、レビュースキルは問題状態を追う手順です。RuboCopはPORO・純粋関数・ViewComponentの採用を自動判断しません。

## 標準セット

以下は既存の事故防止ルールです。日常設計を支える補助の検査として維持します。

| cop | 防ぎたい事故 | 直すときの注意 |
| --- | --- | --- |
| Rails/ActiveRecordOverride | 標準の永続化APIの契約が上書きされる | lifecycle契約を維持する。model callbackを全部禁止しない |
| Rails/DuplicateAssociation | 同名の関連の定義が消える | 意図を一つに整理。継承を含む別ファイルの競合はレビュー |
| Rails/AfterCommitOverride | 同名のcommit hookが別の登録に置き換わる | 対象イベントを一つの登録にまとめる。配信保証は別に確認 |
| Rails/EnumUniqueness | 異なる状態が同じDB値に対応する | 重複を解消。既存データの移行計画も確認 |
| Rails/AddColumnIndex | 指定したつもりのindexが作られない | 正しいindex作成操作。適切な列・作成時のロックはレビュー |
| Rails/DangerousColumnNames | columnが永続化メソッド等と衝突する | 業務を表す別名。既存columnの改名は段階移行 |
| Rails/NotNullColumn | 既存行のあるテーブルへの列追加が失敗する | nullableで追加→backfill→制約などを検討。意味のないdefaultで通さない |
| Rails/UnusedRenderContent | 応答のbodyが意図せず消える | bodyを許可するstatusまたは空の応答にする |

<a id="設計方針セット任意"></a>

## 設計方針セット（標準ON）

以下は不具合の断定ではなく、このパッケージの標準の設計方針です。合わないcopは個別に`Enabled: false`を設定できます。既存の`config/policies.yml`はcallback全面禁止を含む厳格presetとして残します。通常の導入では不要です。許可名や対象範囲も調整できます。

| cop | 防ぎたい事故 | 直すときの注意 |
| --- | --- | --- |
| TsurakunaiRails/ModelRequestContext | modelがHTTPの暗黙の状態を必要とし、job等から使えない | 同名業務属性は区別できない。AllowedMethodsで許可する |
| TsurakunaiRails/DefaultScope | 取得・集計・作成の対象が知らずに変わる | 明示的なscopeを使う。正当な利用は対象限定や個別OFFで残せる |
| TsurakunaiRails/ValidationBypass | validationが動くと思って更新する | 対象はmodel内の明示API。bulkと他レイヤーは文脈で判断 |
| Rails/EnumHash | 配列の途中への値追加で既存データの意味が変わる | 値を明示。既存DBの値と一致するかレビュー |
| Rails/SaveBang | 更新に失敗しても成功扱いで先へ進む | 戻り値を判定するか例外API。暗黙の戻り値は許可し呼び出し元をレビュー |
| Rails/HasManyOrHasOneDependent | 親の削除時に関連が残る・予期せず消える | destroyを強制せずrestrict、DB側管理、nilなど業務の方針を明示 |
| Rails/UniqueValidationWithoutIndex | 並行登録で重複が入る | 対応indexを確認。schema.rbなし、条件付きvalidation、部分indexなどは別途レビュー |

### 任意のcallback全面禁止

`TsurakunaiRails/ControllerCallbacks`は標準OFFです。構文だけでは局所的な認証・lifecycle処理と複雑な業務フローを区別できません。全面禁止を選ぶ場合に個別ONまたは旧`config/policies.yml`を使い、必要なhookは`AllowedMethods`で許可します。複雑な実行順序・副作用はレビュースキルで追います。

独自copは自動修正を実装しません。追加した上流copで自動修正を持つものもこのセットでは `AutoCorrect: false` にしています。修正後の仕様・安全性をレビューするためです。方針セットでも自動修正は無効です。`SaveBang`は型を推論せず、代入・引数・暗黙の戻り値などの全経路を保証しないため、永続化の結果を呼び出し元まで追います。

独自のcontrollerルールは`app/controllers/**/*.rb`、modelルールは`app/models/**/*.rb`を対象にします。concernも含みます。別の配置を使う場合は`Include`を上書きしてください。継承関係やreceiverの型は推論せず、同名の独自APIを検出することがあります。動的な`send`、別レイヤー、bulk処理、動的optionsはコードレビューで確認します。

`ModelRequestContext`はmodel内のreceiverなしまたは `self` の `params` / `session` / `cookies` / `flash` / `request` / `response` / `current_user` / `current_account` 呼び出しを対象とします。ローカル変数・引数や別objectの同名APIは対象外です。これらが正当な業務属性なら `AllowedMethods` で名前を許可します。HTTP objectの引数渡しや `Current` への依存などはコードレビューで判断します。

<a id="rspecセット明示導入"></a>

## RSpecセット（標準ON）

RSpecのspecファイルを対象にします。RSpec本体を追加する設定ではありません。合わないcopは`.rubocop.yml`で`Enabled: false`にできます。

| cop | 防ぎたい事故 | 直すときの注意 |
| --- | --- | --- |
| RSpec/AnyInstance | 別のinstanceまでstubされ、不正な動作が隠れる | 対象instanceまたは外部境界を明示 |
| RSpec/MessageChain | 内部の呼び出し構造に依存し、状態の不具合を見逃す | 公開APIと結果を検証。境界の必要なstubは許可 |
| RSpec/SubjectStub | 検査対象自身をstubし、壊れた実装でも通る | 実対象を実行して外部境界だけ置換 |
| RSpec/VerifiedDoubles | 存在しないメソッドや契約でもテストが通る | 名前なしdoubleも対象。instance/class/object doubleを検討 |
| RSpec/UnspecifiedException | 本来の失敗ではないNameError等でテストが通る | 想定する例外の種類・重要な情報をassert |
| RSpec/OverwritingSetup | 同名のsetupが上書きされ、意図した条件で実行されない | 同じscopeの定義を整理 |
| RSpec/VoidExpect | expectを書くがmatcherがなく何も検証しない | 実際のmatcherと結果を検証 |

Minitestでも、stubで業務の保証を消さないこと、期待する例外・状態・失敗経路を検証することは同じです。RSpecへの移行を要求しません。

## ERB入力セット（明示導入）

[導入手順](view-inputs.md)の設定で、partialの暗黙の入力（TsurakunaiPartialInputs）と解析エラー（ParserErrors）を検査します。対応するRailsでは入力宣言（StrictLocals）も選べます。書式のルールは含めません。Rubyの標準15ルールとは別のERB Lintで実行し、入力の渡し忘れは実際の描画でも検証します。

<a id="意味的レビューの18領域"></a>

## コードレビューで確認すること

| 確認すること | 確認箇所 | 詳細 |
| --- | --- | --- |
| 認証・認可とアカウントごとのデータ取得 | 取得scope、全呼び出し経路、別accountの拒否と状態不変 | [境界](../skills/tsurakunai-rails/references/boundaries.md#s01-認証認可テナント) |
| 入力値をSQLやHTMLへ渡すときの確認 | 許可する属性とsort、query bind、HTMLの信頼境界 | [境界](../skills/tsurakunai-rails/references/boundaries.md#s02-入力sql出力) |
| validationとDB制約の対応 | schema、unique/FK/NULL、違反時の業務応答 | [データ](../skills/tsurakunai-rails/references/data.md#s03-db整合性) |
| 親を削除するときの関連データの扱い | 親子の寿命、監査、制約、件数、削除の失敗 | [データ](../skills/tsurakunai-rails/references/data.md#s04-関連と削除) |
| 保存に失敗したときの処理とトランザクション | 保存結果、例外のscope、rollback時の状態 | [データ](../skills/tsurakunai-rails/references/data.md#s05-更新結果transaction) |
| 外部APIとジョブの失敗・再実行 | commit、enqueue失敗、再試行、二重実行、冪等キー | [境界](../skills/tsurakunai-rails/references/boundaries.md#s06-外部副作用ジョブ) |
| 同時更新と状態変更 | 複数request、atomic更新、ロック、衝突の応答 | [データ](../skills/tsurakunai-rails/references/data.md#s07-競合状態遷移) |
| migrationとデプロイの順序 | 現データ、旧新コードの共存、backfill、復旧 | [データ](../skills/tsurakunai-rails/references/data.md#s08-migrationとdeploy) |
| クエリ・ページング・バッチ処理 | 件数、query数、順序、取得範囲、メモリ | [運用とテスト](../skills/tsurakunai-rails/references/testing.md#s09-query一覧バッチ) |
| 時刻・日付・金額の扱い | 業務zone、日付境界、precision、通貨、丸め | [運用とテスト](../skills/tsurakunai-rails/references/testing.md#s10-時刻日付金額) |
| キャッシュの更新とログへの情報漏えい | tenant/userを含むkey、失効、PIIとtoken | [境界](../skills/tsurakunai-rails/references/boundaries.md#s11-cacheログ秘密) |
| 不具合を見逃さないテスト | 公開APIの結果、失敗時の状態、fixture、順序と時刻 | [運用とテスト](../skills/tsurakunai-rails/references/testing.md#s12-テストの信頼性) |
| コントローラで扱う処理 | permit・認可・操作・結果の対応、業務条件の重複 | [責務](../skills/tsurakunai-rails/references/responsibilities.md#s13-コントローラはhttpの入口と出口を扱う) |
| モデルで守るデータの条件 | 全入口の条件、状態遷移、HTTP依存、callbackの局所性 | [責務](../skills/tsurakunai-rails/references/responsibilities.md#s14-モデルはデータと業務の不変条件を保つ) |
| 複数モデルをまとめて更新する処理 | 自然な集約、transaction、成功と失敗、actorの契約 | [責務](../skills/tsurakunai-rails/references/responsibilities.md#s15-複数モデルの業務処理に明示的な入口を作る) |
| 入力・検索・表示を分ける目安 | UI専用の条件と保存条件、queryのscope、表示の副作用 | [責務](../skills/tsurakunai-rails/references/responsibilities.md#s16-入力検索表示を永続モデルへ押し込まない) |
| ビューとpartialへ渡す値 | renderの全入口、locals、必須/optional、validation失敗の表示 | [ビュー](../skills/tsurakunai-rails/references/views.md#s17-ビューとpartialの入力を明示する) |
| ビューやhelper内のDBアクセスと更新 | helper内部、tenant scope、N+1、状態変更、共有objectの変更 | [ビュー](../skills/tsurakunai-rails/references/views.md#s18-描画で業務処理とデータ取得を隠さない) |

すべてを全変更に要求しません。変更した振る舞い・データ・呼び出し経路に該当する領域を選び、根拠が足りない部分は未検証として記録します。

## 上流の仕様

[RuboCop Rails](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html) と [RuboCop RSpec](https://docs.rubocop.org/rubocop-rspec/latest/cops_rspec.html) の対象範囲・対応バージョンを利用します。この一覧はこのパッケージの採用理由とレビュー上の境界を示します。
