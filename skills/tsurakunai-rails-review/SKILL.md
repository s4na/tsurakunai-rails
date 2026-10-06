---
name: tsurakunai-rails-review
description: Review Rails changes for missing required team contracts, prohibited forms and concrete failures without editing code.
---

# Railsの変更をレビューする

[チーム規約](../tsurakunai-rails/references/team-policy.md)を読み、T01〜T09を基準にする。対象base/head・未コミット差分、導入先の `RAILS_TEAM_POLICY.md`・明示規約・実効lint設定・既存結果を確認する。読み取り専用で進め、編集・投稿・pushは別途依頼がない限り行わない。

## 二つの観点で確認する

**規約の両方向を満たすか。** 変更した処理のT01〜T09を選び、必須の形・契約があることと、禁止形を使っていないことを別々に確認する。必須条件の欠落も規約違反として報告する。「どうあるべきか」を実装者への任意の助言にしない。禁止構文がなくても、状態遷移の条件がcontroller/jobへ分散する、薄いCRUD Serviceを新設する、新規APIの成功値・失敗契約が揃わない場合は通さない。lint成功を規約適合と読み替えない。

動作していても、未許可のcallback・Current・Concern・partialの暗黙入力は規約違反である。既存の明示許可とframework内部は尊重し、単にコードが以前からあることを許可と混同しない。許可hookの本体が業務手順を増やしていないか、文書とlintが一致するかを確認する。必要な根拠が足りなければ未確認とし、禁止を見つけられなかったことだけで合格にしない。

**結果が壊れる経路があるか。** 全入口の認可とtenant、保存失敗と部分commit、外側transactionと外部副作用、再実行、描画時の取得と更新、テストのstubで消された保証を追う。model/operationが存在するだけで状態・認可が守られるとしない。

- [責務](../tsurakunai-rails/references/responsibilities.md): T01/T02/T04/T05/T08、状態操作の入口と失敗契約
- [状態とDB](../tsurakunai-rails/references/data.md): T09、直接更新・競合・migration
- [権限と副作用](../tsurakunai-rails/references/boundaries.md): T03/T09、別入口・commit・送信
- [取得と描画](../tsurakunai-rails/references/views.md): T06/T07、全render入口・件数・状態不変
- [テスト](../tsurakunai-rails/references/testing.md): 正常・拒否・失敗の公開結果

## 根拠を報告する

1. 関係する規約と呼び出し元・許可・既存の防御を確認して候補を反証する。未変更領域の全改修を要求しない。
2. 導入済みlintと該当テストを実行、または同じheadの結果を確認する。未実行を明記し、構文検査と意味の判断を区別する。
3. 規約違反は **ID・ファイル/行・欠けた必須条件または禁止形・標準の置き換え先**、不具合は **発生条件・期待と実際・影響・最小修正**を示す。両方あれば区別して示す。好みの改善は必須修正へ格上げしない。未計測の性能や脆弱性を断定しない。
4. 問題がなければ、適用した規約の必須条件と禁止形の両方を確認した範囲、実行結果、重要な未確認事項を簡潔に報告する。指摘数や全項目の定型報告書を埋めない。[共通の対例](../tsurakunai-rails/references/team-policy.md#禁止構文がなくても合格にしない例)と[具体例](../tsurakunai-rails/references/review.md)も利用できる。

規約はRailsの一般的な禁止事項ではない。不具合がなくても、このチームが選んだ制限は適用する。既存の明示OFFだけではAIが新しい例外を増やす理由にならない。認可漏れ・データ破損は規約の許可があっても確認する。
