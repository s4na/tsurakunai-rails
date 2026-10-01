# ルール設計

## 機械と文脈の境界

「決定的に構文から判定できるか」をRuboCopとスキルの境界にする。RuboCopは違反構文の検出を保証する。業務上の安全性や設計の正しさを保証するものではない。スキルは根拠と失敗シナリオを追い、実際のテストで保証を補う。

標準16ルールは、独自4ルールとRuboCop Railsの重要な12ルールで構成する。RSpecは明示導入の7ルール、意味的レビューは18領域を扱う。詳細は[ルール一覧](rules.md)にまとめる。書式やDSL表現などの上流ルールをすべて有効にせず、保存契約・データの意味・失敗の放置・削除の方針・migrationの事故を優先する。全controller callback禁止はRailsの制約ではなく、このパッケージの初期ポリシーである。認証基盤などの正当な例外を許可名・狭い無効化範囲で管理する。Active Recordの全callback禁止、全モデルへのサービス層要求、文字数・命名などの好みは導入しない。

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
| 認証基盤のcallbackを許可し、request testで保証 | 禁止を理由に削除を要求しない |
| uniqueness validationだけで競合を防ぐ | schemaのindexと衝突時の挙動を確認する |
| DB制約と冪等処理があるbulk update | 個別updateへの機械的変換を要求しない |
| rollback前に外部課金する | rollbackと二重実行時の失敗を説明する |
| 取引のない表示変更 | outboxや新しいサービス層を要求しない |
| service呼び出ししかassertしない認可変更 | 他ユーザーのrequestと状態不変のテストを要求する |
| 公開APIの状態・失敗をテスト済み | private methodの呼び出し検証を要求しない |

スキル文面の構造検証とGem同梱・配置のテストは決定的なCIで行う。AIの判断品質は、実際の差分への独立レビューで確認する。AIを実行しないCIを「意味的レビュー済み」と称しない。導入先の実コードで誤検出・見逃しが観測されたら、この表と根拠を更新する。

## 公式仕様

- [RuboCop plugin API](https://docs.rubocop.org/rubocop/latest/plugin_migration_guide.html)
- [Rails controller callbacks](https://guides.rubyonrails.org/action_controller_overview.html#controller-callbacks)
- [Rails validationの省略](https://guides.rubyonrails.org/active_record_validations.html#skipping-validations)
- [Rails transaction callbacks](https://guides.rubyonrails.org/active_record_callbacks.html#transaction-callbacks)
- [Claude Code Skills](https://code.claude.com/docs/en/skills)

対象バージョンの仕様を確認して判断する。ドキュメント内の例は実アプリの認証・スキーマ・決済要件を置き換えない。
