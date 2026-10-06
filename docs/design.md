# ルール設計

## 機械と文脈の境界

「決定的に構文から判定できるか」をRuboCopとスキルの境界にする。RuboCopは設定した対象パスの該当構文を検出する。業務上の安全性や設計の正しさを保証するものではない。スキルは根拠と失敗シナリオを追い、実際のテストで保証を補う。

主軸は[趣旨](purpose.md)と[チーム規約T01〜T09](../skills/tsurakunai-rails/references/team-policy.md)を固定し、実装とレビューの判断を揃えること。各社の実装・一次資料は背景として読み、本パッケージでの採用判断を分ける。現行ルール・スキル、あるべき姿、差分は[改善フロー](improvement.md)へ記録する。

各ルールに必須の形・契約と禁止形を定め、実装とレビューの両スキルに両方を適用する。実装は満たすべき責務・入力・公開結果を作って禁止形を避け、レビューは必須条件の存在と禁止形の不使用を独立に確認する。禁止構文のない薄いCRUD Serviceや、bang名だがbooleanを返す新規APIも、合意した規約を満たさなければ修正対象になる。規約違反はIDと欠落・禁止形、不具合は発生条件と影響を示す。

機械検査は設計11 cop、事故防止8 cop、RSpec7 copが標準ON。動くコードにも適用する制限を規約として定め、callback・Current・Concernの該当構文を拒否する。必要なhookは名前・対象・代替保証で事前許可する。ERBは別設定と依存を導入して検査する。POROやcomponentの有無、行数だけで合否を決めない。

## ルールを追加する条件

- 実際の保守コストまたは不具合と、再現可能な悪い例がある。
- 良い例と境界例を説明でき、重要性が指摘・修正の負担を上回る。
- 対象パス・構文・型推論の限界が明確で、動的な部分はスキルへ回す。
- 誤検出、見逃し、例外、通常のplugin導入経路をテストできる。
- 自動修正で意味・セキュリティ・性能が変わる可能性があるなら修正を実装しない。

## スキルの品質を評価する

実装とレビューの両方で「タイトル編集は直接CRUD」「自然な集約の確定はmodel API」「外部決済を含む調整はoperation」「単純scopeと複雑queryを使い分ける」「partialの全入口に必須localsを渡す」を必須条件として確認する。同時に禁止形を採用しないこと、認可漏れ・部分保存・二重送信・query増加の具体的な経路を確認する。技巧の有無や指摘数は合否にしない。

CLIの導入テストでは、両クライアントへ規約の正本を読むAIルール、3つのskillと共通参照が配置されること、一つでも既存なら全体を上書きしないことを確認する。配布Gemからも同じ検証を行う。これは配布構造の検査で、AI判断の正解率を証明するものではない。


指摘数を品質指標にしない。少なくとも次の対になる例で判断を確認する。

| ケース | 期待する判断 |
| --- | --- |
| controller callbackを消し、認証を呼び忘れる | 未認証の更新経路を根拠付きで指摘する |
| 認証hookが事前許可され、契約を満たす | 維持する。認証を削除・二重実行しない |
| 動作している対象ロード・業務更新callback | T01/T02の規約違反と標準の修正先を示す |
| callback・Current・Concernを使わない薄いCRUD Serviceを新設 | T05の直接CRUDへ揃える。lint成功を規約適合としない |
| 状態遷移の条件・明細更新がaction/jobへ分散している | T02/T05のmodel公開操作へ揃える。禁止構文がなくても必須条件の欠落を指摘する |
| 新規confirm!がbooleanを返すが現状のテストは通る | 既存の明示契約がなければT08の対象戻り値・業務例外・AR例外へ揃える |
| uniqueness validationだけで競合を防ぐ | schemaのindexと衝突時の挙動を確認する |
| DB制約と冪等処理があるbulk update | 個別updateへの機械的変換を要求しない |
| rollback前に外部課金する | rollbackと二重実行時の失敗を説明する |
| 単一actionのpartialが用意済みのinstance variableを読む | T07としてlocalsへ。トップレベルviewは対象外 |
| 新しいConcernやmodel/jobのCurrent | T03/T04として明示入力と協力objectへ |
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
