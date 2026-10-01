# つらくないRails

Railsアプリ向けのRuboCopルールと、Codex / Claude Codeで使う実装・レビュースキルです。認可漏れ、保存失敗の見落とし、意図しないデータ変更を見つけることを目的にしています。

[導入と使い方](docs/installation.md) · [既存アプリへの導入](docs/adoption.md)

## スキル

| スキル | できること |
| --- | --- |
| [tsurakunai-rails](skills/tsurakunai-rails/SKILL.md) | lintとテストを実行し、認可・DB更新・ビューなどの変更を呼び出し元まで確認する |

実装・レビューの具体例は[レビューガイド](skills/tsurakunai-rails/references/review.md)を参照してください。

## ルール

### 標準で有効

| ルール | 確認すること |
| --- | --- |
| Rails/ActiveRecordOverride | Active Recordの標準メソッドを上書きしていないか |
| Rails/DuplicateAssociation | 同じ名前の関連を重複して定義していないか |
| Rails/AfterCommitOverride | 同じメソッドのcommit callbackを重複登録していないか |
| Rails/EnumUniqueness | enumの異なる値に同じDB値を割り当てていないか |
| Rails/AddColumnIndex | 列の追加時に、無効な方法でindexを指定していないか |
| Rails/DangerousColumnNames | 列名がActive Recordのメソッドと衝突しないか |
| Rails/NotNullColumn | 既存データがあるテーブルへNOT NULL列を追加していないか |
| Rails/UnusedRenderContent | 応答本文を返せないHTTP statusでrenderしていないか |

### チームで選んで有効化

| ルール | 確認すること |
| --- | --- |
| TsurakunaiRails/ControllerCallbacks | controllerでcallbackを使っていないか |
| TsurakunaiRails/ModelRequestContext | modelがparamsやcurrent_userなどへ依存していないか |
| TsurakunaiRails/DefaultScope | default_scopeを使っていないか |
| TsurakunaiRails/ValidationBypass | validationを実行しない更新メソッドを使っていないか |
| Rails/EnumHash | enumのDB値を明示しているか |
| Rails/SaveBang | 保存結果を無視していないか |
| Rails/HasManyOrHasOneDependent | 親を削除するときの関連データの扱いを指定しているか |
| Rails/UniqueValidationWithoutIndex | 一意性validationに対応するunique indexがあるか |

このセットは初期無効です。callbackなどには正当な使い方もあるので、チームで採用した方針だけを有効にします。

### RSpec向け

| ルール | 確認すること |
| --- | --- |
| RSpec/AnyInstance | 特定しないinstanceをまとめてstubしていないか |
| RSpec/MessageChain | メソッドチェーンをstubしていないか |
| RSpec/SubjectStub | テスト対象そのものをstubしていないか |
| RSpec/VerifiedDoubles | 実際のメソッド定義と照合するdoubleを使っているか |
| RSpec/UnspecifiedException | 期待する例外の種類を指定しているか |
| RSpec/OverwritingSetup | 同じ名前のsetupを上書きしていないか |
| RSpec/VoidExpect | expectにmatcherを書き忘れていないか |

RSpecセットは明示的な導入が必要です。ERB向けには、partialの入力と構文を確認する[追加設定](docs/view-inputs.md)もあります。

各ルールの設定、検出できないケース、例外の扱いは[ルールの詳細](docs/rules.md)にまとめています。自動修正は無効です。

## ドキュメント

- [導入と使い方](docs/installation.md)
- [既存アプリへの段階導入](docs/adoption.md)
- [実際のRailsアプリを使った検証](docs/acceptance.md)
- [開発とテスト](docs/development.md)
- [ルールを追加する基準](docs/design.md) / [リリース手順](docs/releasing.md)

Ruby 3.0以上、RuboCop 1.74.0以上・2未満に対応。RubyGemsには未公開です。[MIT License](LICENSE)
