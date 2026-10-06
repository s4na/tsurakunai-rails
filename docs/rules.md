# つらくないためのルール一覧

ルールの正本は[チーム規約T01〜T09](../skills/tsurakunai-rails/references/team-policy.md)です。各ルールは必須の形・契約と禁止形を対で定め、実装スキルとレビュースキルの両方を拘束します。lintはそのうち構文で判断できる部分を自動検査します。lintの対象外であることは、必須条件を任意にする理由になりません。

| 適用する場所 | どうあるべきかで拘束する | どうでないべきかで拘束する |
| --- | --- | --- |
| ルール | 必須の責務・入力・公開API・失敗契約・検証を定める | 禁止形と、認める例外の範囲・代替保証を定める |
| 実装スキル | 適用IDの必須条件を実装・実行で満たす | 禁止形を採用せず、実装後にも使用していないことを確認する |
| レビュースキル | 必須条件があることを確認し、欠落を規約違反として報告する | 禁止形を使っていないことを確認し、使用を規約違反として報告する |

設計方針11 copと補助の事故防止8 cop、RSpec向け7 copを標準ONにします。ERB入力検査はERB利用アプリで設定します。既存copはRuboCop Rails / RSpecを利用し、同じ検査を再実装しません。両セットとRSpecはplugin読み込みで有効になり、既存の`config/rspec.yml`は互換用に残しています。

lintの指摘だけでは不具合と断定できません。実際の型、データ、呼び出し元、明示例外を確認します。適用する規約の必須条件が欠ける、または禁止形を使うことが確認できたら、動作が壊れていなくても規約違反として修正します。新しいDB制約・削除・例外を機械的に導入しません。導入先の明示規約が優先され、lint設定だけから新しい許可は推定しません。

[共通の設計判断と個別OFF](../skills/tsurakunai-rails/references/daily-design.md)も同じ正本に従います。RuboCopはPORO・純粋関数・ViewComponentの採用を自動判断しません。T05の配置やT08の公開契約も必須レビューの対象です。[禁止構文がないのに不合格になる対例](../skills/tsurakunai-rails/references/team-policy.md#禁止構文がなくても合格にしない例)を実装とレビューで共有します。

## AIが常時読むルール

[共通ルール](../config/agent_rules.md)を`install-rules --target codex|claude`で配置します。規約の正本を読むことと、実装・レビューで両方向を満たすことを指示し、具体的な規約を重複して持ちません。スキルを呼ぶ前から同じ基準を使います。[導入先・既存指示との統合・読み込みの確認](installation.md#aiが常時読むルールを配置する)を確認してください。

## 標準セット

基準は[チーム規約T01〜T09](../skills/tsurakunai-rails/references/team-policy.md)です。以下は既存の事故防止ルールです。日常設計を支える補助の検査として維持します。

| cop | 防ぎたい事故 | 直すときの注意 |
| --- | --- | --- |
| Rails/ActiveRecordOverride | 標準の永続化APIの契約が上書きされる | lifecycle契約を維持し、必要なhookはT02の明示許可として残す |
| Rails/DuplicateAssociation | 同名の関連の定義が消える | 意図を一つに整理。継承を含む別ファイルの競合はレビュー |
| Rails/AfterCommitOverride | 同名のcommit hookが別の登録に置き換わる | 対象イベントを一つの登録にまとめる。配信保証は別に確認 |
| Rails/EnumUniqueness | 異なる状態が同じDB値に対応する | 重複を解消。既存データの移行計画も確認 |
| Rails/AddColumnIndex | 指定したつもりのindexが作られない | 正しいindex作成操作。適切な列・作成時のロックはレビュー |
| Rails/DangerousColumnNames | columnが永続化メソッド等と衝突する | 業務を表す別名。既存columnの改名は段階移行 |
| Rails/NotNullColumn | 既存行のあるテーブルへの列追加が失敗する | nullableで追加→backfill→制約などを検討。意味のないdefaultで通さない |
| Rails/UnusedRenderContent | 応答のbodyが意図せず消える | bodyを許可するstatusまたは空の応答にする |

<a id="設計方針セット任意"></a>

## 設計方針セット（標準ON）

以下はチーム規約T01〜T09のうち構文で検査できる制限です。ルール全体の合格には正本の必須条件も満たす必要があります。個別OFF・許可名・対象範囲のoverrideは可能ですが、変更する理由と代替保証をRAILS_TEAM_POLICY.mdへ揃えます。既存のconfig/policies.ymlは互換用で、現在の標準でもcallback制限はONです。

| cop | 防ぎたい事故 | 直すときの注意 |
| --- | --- | --- |
| TsurakunaiRails/ControllerCallbacks | actionのロード・更新・通知が暗黙の順序へ隠れる（T01） | 認証等の必須hookをAllowedMethodsで許可。認可を消さず対象取得はactionへ |
| TsurakunaiRails/ModelCallbacks | saveやfindから別の業務が始まる（T02） | AllowedCallbacksで種類と名前を事前許可。本体と全入口を検証 |
| TsurakunaiRails/ImplicitContext | actor・tenant等の入力がglobalへ隠れる（T03） | Current定数の参照を検出。業務の同名定数はAllowedConstantsで許可 |
| TsurakunaiRails/Concern | 業務APIがmixinsへ隠れ、配置と依存が散る（T04） | app内のActiveSupport::Concern宣言を検出。必要な基盤・既存契約は対象限定で許可 |
| TsurakunaiRails/ModelRequestContext | modelがHTTPの暗黙の状態を必要とし、job等から使えない | 同名業務属性は区別できない。AllowedMethodsで許可する |
| TsurakunaiRails/DefaultScope | 取得・集計・作成の対象が知らずに変わる | 明示的なscopeを使う。正当な利用は対象限定や個別OFFで残せる |
| TsurakunaiRails/ValidationBypass | validationが動くと思って更新する | 対象はmodel内の明示API。bulkと他レイヤーは文脈で判断 |
| Rails/EnumHash | 配列の途中への値追加で既存データの意味が変わる | 値を明示。既存DBの値と一致するかレビュー |
| Rails/SaveBang | 更新に失敗しても成功扱いで先へ進む | 戻り値を判定するか例外API。暗黙の戻り値は許可し呼び出し元をレビュー |
| Rails/HasManyOrHasOneDependent | 親の削除時に関連が残る・予期せず消える | destroyを強制せずrestrict、DB側管理、nilなど業務の方針を明示 |
| Rails/UniqueValidationWithoutIndex | 並行登録で重複が入る | 対応indexを確認。schema.rbなし、条件付きvalidation、部分indexなどは別途レビュー |

### 対象と例外

ControllerCallbacksはcontrollerのreceiverなし/selfの登録を検出します。AllowedMethodsの全登録名が一致し、ブロックがない場合だけ許可します。ModelCallbacksはmodelのvalidation/save/create/update/destroy/find/initialize/touch/commit/rollback hookとset_callbackを、receiverなし/self・定数・class取得の呼び出しで検出します。`Invoice.after_commit`や`self.class.after_save`も対象です。AllowedCallbacksは登録種類ごとの名前です。ブロック・混合・動的な登録名・set_callbackは許可名では通しません。`transaction.after_commit`等のインスタンスへの明示的登録は対象外ですが、外側transactionとの順序・配信保証はレビューします。receiverの型は推論しないため、modelクラスのローカル変数・引数・動的取得による登録はレビューで確認します。

ImplicitContextはmodels/jobs/operations/services/queries/forms/helpers/components内の末尾名Currentの定数参照を検出します。HTTP境界のcontrollerと定数のclass/module宣言は対象外です。CurrentAttributesの型推論はせず、別名・alias・ERB・別配置はレビューします。Concernはmodels/controllers/operations/services内のActiveSupport::Concernへのextend/includeを検出します。普通のmoduleや動的include、ライブラリ内部は検査できません。T04の暗黙APIはレビューで補います。

`AllowedConstants: [Electric::Current]`は明示名に加え、`module Electric`の本体やその中にネストしたclass/moduleの`Current`を許可します。`::Current`、別名前空間、`module Electric::Tools`から外側の`Electric`への探索にはこの許可を広げません。[Rubyの字句上のネスト](https://docs.ruby-lang.org/en/3.3/syntax/modules_and_classes_rdoc.html)を使う構文検査で、定数の実在、同名定数による遮蔽、継承や動的評価の解決はしません。許可した業務定数へ解決することを確認し、曖昧な箇所では完全修飾名を使ってください。

独自copは自動修正を実装しません。追加した上流copで自動修正を持つものもこのセットでは `AutoCorrect: false` にしています。修正後の仕様・安全性をレビューするためです。方針セットでも自動修正は無効です。`SaveBang`は型を推論せず、代入・引数・暗黙の戻り値などの全経路を保証しないため、永続化の結果を呼び出し元まで追います。

独自のcontrollerルールは`app/controllers/**/*.rb`、modelルールは`app/models/**/*.rb`を対象にします。concernも含みます。別の配置を使う場合は`Include`を上書きしてください。継承関係やreceiverの型は推論せず、同名の独自APIを検出することがあります。動的な`send`、別レイヤー、bulk処理、動的optionsはコードレビューで確認します。

`ModelRequestContext`はmodel内のreceiverなしまたは `self` の `params` / `session` / `cookies` / `flash` / `request` / `response` / `current_user` / `current_account` 呼び出しを対象とします。ローカル変数・引数や別objectの同名APIは対象外です。これらが正当な業務属性なら `AllowedMethods` で名前を許可します。HTTP objectの引数渡しや別名globalはコードレビューで判断します。Current定数はImplicitContextが補助検出します。

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

[導入手順](view-inputs.md)の設定で、partialの暗黙の入力（TsurakunaiPartialInputs）と解析エラー（ParserErrors）を検査します。対応するRailsでは入力宣言（StrictLocals）も選べます。書式のルールは含めません。Rubyの標準19ルールとは別のERB Lintで実行し、入力の渡し忘れは実際の描画でも検証します。

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
