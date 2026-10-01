# つらくないためのルール一覧

標準15ルール、RSpec向け7ルール、文脈が必要な12領域を扱います。既存copはRuboCop Rails / RSpecを利用し、同じ検査を再実装しません。標準セットはplugin読み込みだけで有効になります。RSpecセットは `config/rspec.yml` の明示的な導入が必要です。

構文検査が指摘するのはリスクの入口です。型・業務・データ・呼び出し元を確認して修正または例外を判断します。新しいDB制約・削除・例外を機械的に導入しません。導入先の明示設定が優先されます。

## 標準セット

| cop | 防ぎたい事故 | 対応と境界 |
| --- | --- | --- |
| TsurakunaiRails/ControllerCallbacks | actionの認可・ロード・副作用の順序が追えない | 明示的な流れへ。認証基盤の必須hookは許可名で管理 |
| TsurakunaiRails/DefaultScope | 取得・集計・作成の対象が知らずに変わる | 名前付きscope。継承や動的定義はレビュー |
| TsurakunaiRails/ValidationBypass | validationが動くと思って更新する | 対象はmodel内の明示API。bulkと他レイヤーは文脈で判断 |
| Rails/ActiveRecordOverride | 標準の永続化APIの契約が上書きされる | lifecycle契約を維持する。model callbackを全部禁止しない |
| Rails/DuplicateAssociation | 同名の関連の定義が消える | 意図を一つに整理。継承を含む別ファイルの競合はレビュー |
| Rails/AfterCommitOverride | 同名のcommit hookが別の登録に置き換わる | 対象イベントを一つの登録にまとめる。配信保証は別に確認 |
| Rails/EnumHash | 配列の途中への値追加で既存データの意味が変わる | 値を明示。既存DBの値と一致するかレビュー |
| Rails/EnumUniqueness | 異なる状態が同じDB値に対応する | 重複を解消。既存データの移行計画も確認 |
| Rails/SaveBang | 更新に失敗しても成功扱いで先へ進む | 戻り値を判定するか例外API。暗黙の戻り値は許可し呼び出し元をレビュー |
| Rails/HasManyOrHasOneDependent | 親の削除時に関連が残る・予期せず消える | destroyを強制せずrestrict、DB側管理、nilなど業務の方針を明示 |
| Rails/UniqueValidationWithoutIndex | 並行登録で重複が入る | 対応indexを確認。schema.rbなし、条件付きvalidation、部分indexなどは別途レビュー |
| Rails/AddColumnIndex | 指定したつもりのindexが作られない | 正しいindex作成操作。適切な列・作成時のロックはレビュー |
| Rails/DangerousColumnNames | columnが永続化メソッド等と衝突する | 業務を表す別名。既存columnの改名は段階移行 |
| Rails/NotNullColumn | 既存行のあるテーブルへの列追加が失敗する | nullableで追加→backfill→制約などを検討。意味のないdefaultで通さない |
| Rails/UnusedRenderContent | 応答のbodyが意図せず消える | bodyを許可するstatusまたは空の応答にする |

独自copは自動修正を実装しません。追加した上流copで自動修正を持つものもこのセットでは `AutoCorrect: false` にしています。修正後の仕様・安全性をレビューするためです。`SaveBang`は型を推論せず、代入・引数・暗黙の戻り値などの全経路を保証しないため、永続化の結果を呼び出し元まで追います。

## RSpecセット（明示導入）

| cop | 防ぎたい事故 | 対応と境界 |
| --- | --- | --- |
| RSpec/AnyInstance | 別のinstanceまでstubされ、不正な動作が隠れる | 対象instanceまたは外部境界を明示 |
| RSpec/MessageChain | 内部の呼び出し構造に依存し、状態の不具合を見逃す | 公開APIと結果を検証。境界の必要なstubは許可 |
| RSpec/SubjectStub | 検査対象自身をstubし、壊れた実装でも通る | 実対象を実行して外部境界だけ置換 |
| RSpec/VerifiedDoubles | 存在しないメソッドや契約でもテストが通る | 名前なしdoubleも対象。instance/class/object doubleを検討 |
| RSpec/UnspecifiedException | 本来の失敗ではないNameError等でテストが通る | 想定する例外の種類・重要な情報をassert |
| RSpec/OverwritingSetup | 同名のsetupが上書きされ、意図した条件で実行されない | 同じscopeの定義を整理 |
| RSpec/VoidExpect | expectを書くがmatcherがなく何も検証しない | 実際のmatcherと結果を検証 |

Minitestでも、stubで業務の保証を消さないこと、期待する例外・状態・失敗経路を検証することは同じです。RSpecへの移行を要求しません。

## 意味的レビューの12領域

| ID・領域 | 最低限追う証拠 | 判断集 |
| --- | --- | --- |
| S01 認証・認可・テナント | 取得scope、全entrypoint、別accountの拒否と状態不変 | [境界](../skills/tsurakunai-rails/references/boundaries.md#s01-認証認可テナント) |
| S02 入力・SQL・出力 | 許可する属性とsort、query bind、HTMLの信頼境界 | [境界](../skills/tsurakunai-rails/references/boundaries.md#s02-入力sql出力) |
| S03 DB整合性 | schema、unique/FK/NULL、違反時の業務応答 | [データ](../skills/tsurakunai-rails/references/data.md#s03-db整合性) |
| S04 関連と削除 | 親子の寿命、監査、制約、件数、削除の失敗 | [データ](../skills/tsurakunai-rails/references/data.md#s04-関連と削除) |
| S05 更新結果・transaction | 保存結果、例外のscope、rollback時の状態 | [データ](../skills/tsurakunai-rails/references/data.md#s05-更新結果transaction) |
| S06 外部副作用・ジョブ | commit、enqueue失敗、再試行、二重実行、冪等キー | [境界](../skills/tsurakunai-rails/references/boundaries.md#s06-外部副作用ジョブ) |
| S07 競合・状態遷移 | 複数request、atomic更新、ロック、衝突の応答 | [データ](../skills/tsurakunai-rails/references/data.md#s07-競合状態遷移) |
| S08 migrationとdeploy | 現データ、旧新コードの共存、backfill、復旧 | [データ](../skills/tsurakunai-rails/references/data.md#s08-migrationとdeploy) |
| S09 query・一覧・バッチ | 件数、query数、順序、取得範囲、メモリ | [運用とテスト](../skills/tsurakunai-rails/references/testing.md#s09-query一覧バッチ) |
| S10 時刻・日付・金額 | 業務zone、日付境界、precision、通貨、丸め | [運用とテスト](../skills/tsurakunai-rails/references/testing.md#s10-時刻日付金額) |
| S11 cache・ログ・秘密 | tenant/userを含むkey、失効、PIIとtoken | [境界](../skills/tsurakunai-rails/references/boundaries.md#s11-cacheログ秘密) |
| S12 テストの信頼性 | 公開APIの結果、失敗時の状態、fixture、順序と時刻 | [運用とテスト](../skills/tsurakunai-rails/references/testing.md#s12-テストの信頼性) |

すべてを全変更に要求しません。変更した振る舞い・データ・entrypointに該当する領域を選び、根拠が足りない部分は未検証として記録します。

## 上流の仕様

[RuboCop Rails](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html) と [RuboCop RSpec](https://docs.rubocop.org/rubocop-rspec/latest/cops_rspec.html) の対象範囲・対応バージョンを利用します。この一覧はこのパッケージの採用理由とレビュー上の境界を示します。
