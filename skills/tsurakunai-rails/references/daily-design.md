# 共通の設計判断

実装は「どのように作るか」、レビューは「その形が崩れる経路」を見る。同じ判断を使うため、この参照先を共有します。ここでいうハードな検査は、禁止・問題状態のうち機械で判定できる構文をlintにしたものです。すべての設計判断を自動化したという意味ではありません。

## 基本の流れ

利用者の操作 → controller/jobの入口 → modelの業務API → 必要な協力オブジェクト → 保存結果・応答、の順に追える形を基本にします。単純なCRUDはcontroller→modelのままにします。POROやserviceを経由すること自体を目的にしません。

| どう作るか | レビューで避ける状態 | 機械で分かる範囲 |
| --- | --- | --- |
| actor・対象scope・許可属性を入口で決める | 別tenantの対象取得、別入口で認可を迂回する | 認可の正しさはlintだけでは分からない |
| modelの業務名APIで不変条件と状態遷移を守る | HTTP層だけに条件があり、直接保存やjobで抜ける | enum値・保存APIなどの構文だけ |
| 一緒に成功する更新と失敗時の応答を決める | 一部だけcommit、保存失敗を成功扱いする | SaveBangは戻り値無視の一部を検出 |
| lifecycleの局所処理と操作固有の手順を分ける | callback順序に複雑な業務や外部副作用が隠れる | callbackの複雑さは判定しない。全面禁止copは任意 |
| scopeを合成し、必要な検索だけFinderへ分ける | 多機能Finderの流用で権限・件数・条件が変わる | query数や適切な抽象化は文脈と実測で確認 |
| 明示入力のpartialやcomponentで描画を組み立てる | 入力の食い違い、隠れた追加query、描画時の更新 | ERB入力lintは直接の変数参照を補助検出 |
| 独立計算には必要な値を渡し、結果を返す | 時刻・金額・共有状態への依存で結果が変わる | 独立性や丸めの正しさはテストで確認 |
| 外部I/Oの失敗・再実行・commitを扱う | rollback済みの通知、timeout後の二重処理 | 配信保証や冪等性は静的には保証しない |
| 公開結果を速いmodel/HTTP境界のテストで確認する | stubやUIテストだけで重要な状態を見逃す | RSpecの期待・double等の形式を補助検査 |

## 責務を分ける目安

モデルは属性だけの箱ではありません。レコードや自然な集約が守る条件、状態遷移、短い問い合わせをモデルの公開APIに置きます。関係する複数行を更新するだけでserviceへ移す必要はありません。

独立した計算、外部通信、複数集約を調整する操作は、理解しやすくなる場合に名前付きPOROへ分けます。モデル配下の協力オブジェクトでも構いません。計算がモデルの値の意味を表すなら、そのメソッドやvalue objectに残せます。関数形式やクラス数を強制しません。

Concernはdomain traitとしてまとまる処理に使えます。行数を減らすだけの任意の寄せ集めにしません。薄い委譲だけのService基底クラス、共通result framework、同じ形に揃えるための層は増やしません。名前は仕事を説明する業務語を選び、接尾辞だけで判定しません。

## callback・Current・表示

認証hook、単純な正規化、lifecycle付随処理などはcallbackの正当な用途です。操作固有の複雑な更新・外部I/Oは明示APIから追える形を選びます。Currentを使う場合も、request外の初期化・解除・権限の前提を確認し、存在だけで欠陥にしません。

partialを禁止せず、必要な入力をlocalsで渡します。UIの振る舞い、再利用、独立した描画テストに利益があるときに既存component基盤やViewComponentを選びます。partialというだけで遅い、componentにすればN+1が消えるとは扱いません。

本パッケージでは、複雑な取得条件・先読み・ページングを表示処理から追いやすい境界へ寄せることを推奨します。これは採用方針であり、37signalsがview内のscopeやCurrentを禁止しているという主張ではありません。遅延評価のSQLや既存helperの呼び出しだけで違反にしません。

## 導入先に合わせる

これらを標準の判断として使い、導入先の明示的な規約と今回の依頼範囲を優先します。例えばAGENTS.mdやCLAUDE.mdに「この画面は既存ViewComponentを使用」「このAPIは既存service境界を維持」と書けば、その前提で実装・レビューします。方針をOFFにする指示も尊重し、理由の報告書を条件にしません。

lintの個別OFFは`.rubocop.yml`の`Enabled: false`、許可名・対象範囲で指定します。AI向け規約とは独立しています。`ControllerCallbacks`は標準OFFで、全面禁止を選ぶプロジェクトだけ有効にできます。旧`config/policies.yml`はその厳格な方針を含む互換presetです。

前版の「モデル外への一律分離」「再利用UIはViewComponent優先」「callback全面禁止」は置き換えました。既存の個別OFFは再有効化しません。変更していない領域の一括改修、未承認の依存追加、公開・デプロイは行いません。

## 調査から採用したこと

以下は2026-10-01の一次資料調査です。実在するコード、各組織の規約、本パッケージでの採用判断を区別します。GitLabの全体構造や37signalsの好みを、そのまま小さなチームへ持ち込みません。

- **GitLabの実コード**: [WebHookの入口](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/app/controllers/concerns/web_hooks/hook_actions.rb)はcreateにservice、updateに直接のmodel更新を使う。[Label](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/app/models/label.rb)は親整合性や削除条件をmodelで扱う。したがって「すべてservice」「modelはデータだけ」とは読まない
- **GitLabの取得と描画**: [LabelsPreloader](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/app/models/preloaders/labels_preloader.rb)と[テスト](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/spec/models/preloaders/labels_preloader_spec.rb)は関連・権限の一括取得とquery数を扱う。[一覧](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/app/views/projects/labels/index.html.haml)はComponentとpartialを併用する。採用するのは取得量と入力契約の明示で、特定のUI方式の全面強制ではない
- **GitLabの規約と実装の差**: [抽象化の再利用](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/doc/development/reusing_abstractions.md)は、多機能なFinder等の流用が余分な条件や性能負担を持ち込む例を説明する。大規模組織向けの階層・共通service規約は丸写しせず、低水準のscope等を適切に合成する判断を採る
- **37signalsのdomain model**: [Vanilla Rails is plenty](https://dev.37signals.com/vanilla-rails-is-plenty/)はARとPOROを含むdomain modelの公開APIを重視する。[Good concerns](https://dev.37signals.com/good-concerns/)ではdomain traitのConcernと協力POROを併用する。採用するのは凝集性で、Concernかcompositionかの一律選択ではない
- **37signalsのcallback**: [Globals, callbacks and other sacrileges](https://dev.37signals.com/globals-callbacks-and-other-sacrileges/)は単純なlifecycle付随処理を認め、複雑なflowを区別する。callbackやCurrentの存在をhard lintで不具合と確定しない
- **Fizzyの公開実装**: [STYLE](https://github.com/basecamp/fizzy/blob/a703bf1de29ab9cc56672f125f25b14f47418f7b/STYLE.md)、[ClosuresController](https://github.com/basecamp/fizzy/blob/a703bf1de29ab9cc56672f125f25b14f47418f7b/app/controllers/cards/closures_controller.rb)、[Card::Closeable](https://github.com/basecamp/fizzy/blob/a703bf1de29ab9cc56672f125f25b14f47418f7b/app/models/card/closeable.rb)はcontroller→model操作とtransactionを示す。一方[メッセージpartial](https://github.com/basecamp/fizzy/blob/a703bf1de29ab9cc56672f125f25b14f47418f7b/app/views/cards/_messages.html.erb)は関連scopeやCurrentも使う。これを「view内DB参照禁止」の根拠にはしない。Fizzyは確認時点のcommitを固定している

この調査は、各社の全コードが同じ規約を守ることや、この方針による性能改善・開発時間削減を実証したものではありません。
