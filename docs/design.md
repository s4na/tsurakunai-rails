# ルール設計

## 機械と文脈の境界

「決定的に構文から判定できるか」をRuboCopとスキルの境界にする。RuboCopは違反構文の検出を保証する。業務上の安全性や設計の正しさを保証するものではない。スキルは根拠と失敗シナリオを追い、実際のテストで保証を補う。

主軸は実装手順とレビュー手順を分け、[共通の設計判断](../skills/tsurakunai-rails/references/daily-design.md)を共有すること。GitLabと37signalsの実コード・一次資料から、domain APIと必要な協力オブジェクトを使い分ける。各社の全体構造をそのまま輸入しない。

実装は入口・状態・保存失敗・取得/表示・テストを作る。レビューは別入口の迂回、部分commit、隠れた副作用、過剰な抽象化などを具体的に追う。設計上の指摘は保守負担、不具合の指摘は発生条件と影響を示す。

機械検査は設計7 cop、事故防止8 cop、RSpec7 copが標準ON。callback全面禁止だけは文脈で区別できないので標準OFFとし、旧厳格presetを残す。ERB利用アプリは設定と依存を導入し、`--views`付きで検査する。POROやcomponentの有無をhardな合否にしない。

## ルールを追加する条件

- 実際の保守コストまたは不具合と、再現可能な悪い例がある。
- 良い例と境界例を説明でき、重要性が指摘・修正の負担を上回る。
- 対象パス・構文・型推論の限界が明確で、動的な部分はスキルへ回す。
- 誤検出、見逃し、例外、通常のplugin導入経路をテストできる。
- 自動修正で意味・セキュリティ・性能が変わる可能性があるなら修正を実装しない。

## スキルの品質を評価する

実装では「タイトル編集は直接CRUD」「自然な集約の確定はmodel API」「外部決済を含む調整は必要なPORO」「単純scopeと複雑Finderを使い分ける」「明示localsで足りるpartialを残す」を選べることを確認する。レビューでは同じ題材の認可漏れ・部分保存・二重送信・query増加を根拠付きで見つける。技巧の有無や指摘数は合否にしない。

CLIの導入テストでは、両クライアントへ3つのskillと共通参照が配置されること、一つでも既存なら全体を上書きしないことを確認する。配布Gemからも同じ検証を行う。これは配布構造の検査で、AI判断の正解率を証明するものではない。


指摘数を品質指標にしない。少なくとも次の対になる例で判断を確認する。

| ケース | 期待する判断 |
| --- | --- |
| controller callbackを消し、認証を呼び忘れる | 未認証の更新経路を根拠付きで指摘する |
| 認証・ロードのcallbackで契約を満たす | 標準では許容し、全面禁止の採用時だけ許可名を案内する |
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
