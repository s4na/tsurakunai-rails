# つらくないRails

Railsの変更をどう作るか、その設計がどこで崩れるかを、別々のスキルで扱います。両方が同じ設計資料を参照し、機械で判定できる構文だけをRuboCop・ERB Lintで検査します。

GitLabの公開コードと37signalsの一次資料を読み、単純なCRUD、振る舞いを持つモデル、必要なPOROを使い分ける方針にしました。特定企業の階層やライブラリを一式コピーするものではありません。[調査根拠と採用判断](skills/tsurakunai-rails/references/daily-design.md#調査から採用したこと)

[導入と使い方](docs/installation.md) · [既存アプリへの導入・更新](docs/adoption.md)

## 使うスキル

| 入口 | 役割 |
| --- | --- |
| [tsurakunai-rails-implement](skills/tsurakunai-rails-implement/SKILL.md) | 利用者の操作から、入口・責務・保存失敗・テストを組み立てる |
| [tsurakunai-rails-review](skills/tsurakunai-rails-review/SKILL.md) | 境界・状態・副作用が崩れる経路を、編集せず根拠付きで確認する |
| [tsurakunai-rails](skills/tsurakunai-rails/SKILL.md) | 既存の呼び出し名。依頼に合う実装・レビュー手順へ案内する |

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

- **標準の設計7 cop**: modelのHTTP状態参照、default_scope、validationを省略する更新、enumのDB値、保存結果、関連削除、一意indexを検査。業務上の例外は許可名・対象範囲・個別OFFで調整する
- **補助の事故防止8 cop**: AR API上書き、関連・commit callback・enumの重複、migrationの誤指定、HTTP本文の不整合を検査する
- **RSpec7 cop**: specファイルのstub・double・期待・setupの誤りを補助検査する。RSpec本体の導入やMinitestの変更は要求しない
- **ERB**: `erb_lint ~> 0.9`と`install-view-lint`の設定を導入し、`check --views -- <テストコマンド>`で入力と構文を検査する。`--views`なしでは未検査
- **任意のControllerCallbacks**: callback全面禁止を選ぶ場合だけON。標準では、単純なlifecycle処理と隠れた業務フローをスキルで区別する

推奨するlintは標準ON、不要なcopは`.rubocop.yml`で個別OFFにできます。旧`config/policies.yml`はcallback全面禁止を含む厳格presetとして残しています。[全cop・制限・例外](docs/rules.md)。自動修正は無効です。

## ドキュメント

- [導入と更新](docs/installation.md) / [既存アプリでの確認](docs/adoption.md)
- [実Railsアプリの検証と限界](docs/acceptance.md)
- [開発とテスト](docs/development.md) / [設計判断の評価](docs/design.md)
- [リリース手順](docs/releasing.md)

Ruby 3.0以上、RuboCop 1.74.0以上・2未満に対応。RubyGemsには未公開です。[MIT License](LICENSE)
