---
name: tsurakunai-rails-review
description: Review Rails changes for broken boundaries, hidden business flows, and observable failures without editing code.
---

# Railsの変更をレビューする

[共通の設計判断](../tsurakunai-rails/references/daily-design.md)を基準に、期待する状態から外れる経路を探す。読み取り専用で実施し、コード編集・投稿・pushは別途依頼がない限り行わない。対象のbase/headと未コミット差分、導入先の規約、既存の検証結果を先に確認する。

## 問題状態から追う

- **HTTP処理に業務判断が埋まる**: controller/concern内の料金計算や承認条件を追う。単純CRUDと応答分岐は許容し、privateへ移しただけの業務ロジックを見落とさない。[責務](../tsurakunai-rails/references/responsibilities.md)
- **入口によって守る条件が変わる**: controllerだけのvalidation・認可、job/consoleから迂回できる状態遷移、別tenantの取得を確認する。modelメソッド・concern・POROの存在自体は問題にしない。[状態とDB](../tsurakunai-rails/references/data.md)、[権限](../tsurakunai-rails/references/boundaries.md)
- **一部だけ保存される、失敗が成功になる**: 保存の戻り値、例外、transaction範囲、呼び出し元の応答を追う。課金や通知がrollbackで戻ると仮定していないか確認する。[保存結果](../tsurakunai-rails/references/data.md)、[外部I/O](../tsurakunai-rails/references/boundaries.md)
- **副作用と実行順序が隠れる**: validation・描画・callbackから別の業務や外部通信が起動する経路、再実行時の重複を追う。単純な正規化・lifecycle付随処理・認証hookを全面禁止しない。[外部I/O](../tsurakunai-rails/references/boundaries.md)
- **描画するほどqueryや状態変更が増える**: helper/componentの内部、collectionの関連参照、scope・ページング・入力値を確認する。partialかcomponentかだけで性能を判定しない。[取得と描画](../tsurakunai-rails/references/views.md)
- **分離しても理解する場所が増えるだけ**: 一度のsaveを転送するだけのクラス、仕事の不明なManager/Utils、HTTP objectをそのまま渡すserviceを確認する。既存の公開APIやframework規約に理由があれば維持する。[責務](../tsurakunai-rails/references/responsibilities.md)
- **テストが問題を隠す**: 委譲だけで終わる認可変更、テスト対象の重要処理をstubした結果、失敗後のDB状態や描画を見ないassertを確認する。正当な境界stubや別テストでの保証は尊重する。[テスト](../tsurakunai-rails/references/testing.md)

## 確かめて報告する

1. 関係する項目だけ選び、入力・呼び出し元・既存の防御・テストを追って候補を反証する。差分だけで断定しない。
2. 導入済みのlintと該当テストを実行、または同じheadでの結果を確認する。未実行は明記する。RuboCopの構文検出と、この文脈レビューを区別する。
3. 不具合はファイル/行、発生条件、期待と実際の差、影響、最小の修正を示す。設計上の指摘は方針と具体的な保守負担を示し、動作不良と混同しない。未計測の性能・脆弱性を断定しない。
4. 指摘がなければ確認した範囲と重要な未検証事項を報告する。指摘数を埋めず、全項目の定型報告書も作らない。改善の参考例は[具体例](../tsurakunai-rails/references/review.md)を使う。

lintで機械判定できるのは宣言・呼び出し等の構文まで。PORO、concern、callback、partial、componentの有無を一律の合否条件にしない。個別OFFや既存規約は尊重するが、認可漏れ・データ破損の具体的な経路は確認する。
