# ルール設計

## 機械と文脈の境界

「決定的に構文から判定できるか」をRuboCopとスキルの境界にする。RuboCopは違反構文の検出を保証する。業務上の安全性や設計の正しさを保証するものではない。スキルは根拠と失敗シナリオを追い、実際のテストで保証を補う。

主軸は[日常の設計方針](../skills/tsurakunai-rails/references/daily-design.md)。処理の内容で判断するPORO・純粋関数・ViewComponent・命名はスキルが標準で確認する。設計方針8 copも標準ONとし、個別OFFや許可名で調整できる。既存の事故防止8 copは補助として維持する。RSpec7ルールも標準ON。ERB入力セットはERB利用アプリで設定と依存を導入し、`--views`付きで検査する。

設計方針からの逸脱と不具合を区別する。設計上の指摘は動作不良の証明を必須にせず、該当する処理・方針・例外・最小の改善を示す。不具合や性能の断定には発生条件と実際の影響が必要。変更していない領域の一括改修、全modelメソッドの移動、計測なしの高速化を要求しない。

## ルールを追加する条件

- 実際の保守コストまたは不具合と、再現可能な悪い例がある。
- 良い例と境界例を説明でき、重要性が指摘・修正の負担を上回る。
- 対象パス・構文・型推論の限界が明確で、動的な部分はスキルへ回す。
- 誤検出、見逃し、例外、通常のplugin導入経路をテストできる。
- 自動修正で意味・セキュリティ・性能が変わる可能性があるなら修正を実装しない。

## スキルの品質を評価する

指摘数を品質指標にしない。少なくとも次の対になる例で判断を確認する。

| ケース | 期待する判断 |
| --- | --- |
| controller callbackを消し、認証を呼び忘れる | 未認証の更新経路を根拠付きで指摘する |
| 認証・ロードのcallbackで契約を満たす | AllowedMethodsや個別OFFを案内し、認証を壊す削除を要求しない |
| uniqueness validationだけで競合を防ぐ | schemaのindexと衝突時の挙動を確認する |
| DB制約と冪等処理があるbulk update | 個別updateへの機械的変換を要求しない |
| rollback前に外部課金する | rollbackと二重実行時の失敗を説明する |
| 単一actionのpartialが用意済みのinstance variableを読む | locals化やstrict locals導入を要求しない |
| modelのrequest属性はHTTPとは無関係 | 名前だけで設計違反と指摘しない |
| 複数入口でpartialの表示対象が食い違う | 具体的なrenderと出力を根拠に修正を検討する |
| 取引のない表示変更 | outboxや新しいサービス層を要求しない |
| service呼び出ししかassertしない認可変更 | 他ユーザーのrequestと状態不変のテストを要求する |
| 公開APIの状態・失敗をテスト済み | private methodの呼び出し検証を要求しない |

スキル文面の構造検証とGem同梱・配置のテストは決定的なCIで行う。AIの判断品質は、実際の差分への独立レビューで確認する。AIを実行しないCIを「コードレビュー済み」と称しない。導入先の実コードで誤検出・見逃しが観測されたら、この表と根拠を更新する。

## 公式仕様

- [RuboCop plugin API](https://docs.rubocop.org/rubocop/latest/plugin_migration_guide.html)
- [Rails controller callbacks](https://guides.rubyonrails.org/action_controller_overview.html#controller-callbacks)
- [Rails validationの省略](https://guides.rubyonrails.org/active_record_validations.html#skipping-validations)
- [Rails transaction callbacks](https://guides.rubyonrails.org/active_record_callbacks.html#transaction-callbacks)
- [Claude Code Skills](https://code.claude.com/docs/en/skills)

対象バージョンの仕様を確認して判断する。ドキュメント内の例は実アプリの認証・スキーマ・決済要件を置き換えない。
