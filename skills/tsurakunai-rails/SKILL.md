---
name: tsurakunai-rails
description: Implement or review Rails changes using focused checks and evidence of concrete failures in authorization, persistence, controller/model behavior, view inputs, and tests. Use for Rails application changes, not enforcing a preferred architecture or general Ruby formatting.
---

# つらくないRails

変更した振る舞いに関係する、具体的な不具合だけを扱う。命名、行数、callback・service・instance variableの存在を理由に指摘しない。既存設計が必要な契約を満たしていれば維持する。

## 実行とレビュー

1. 依頼と差分から期待する結果を整理し、対象プロジェクトのルール、設定、テスト入口を確認する。未コミット変更を保護する。
2. 導入済みのlintと変更に適したテストを実行する。このGemが導入済みなら `bundle exec tsurakunai-rails check -- <テストコマンドと引数>`、ERB設定と依存も導入済みなら `check --views -- <テストコマンドと引数>` を使う。未導入の検査を成功扱いしない。依頼や確認した問題に必要がなければ、新しいpreset・スキル・ツールの導入を勧めない。
3. 下記の判断集から差分に関係する失敗シナリオだけを選ぶ。全18領域の点検を毎回行わず、呼び出し元やschemaは疑問を解決するのに必要な範囲で追う。標準は8ルール。設計方針8ルール、RSpec7ルール、ERB入力セットは明示的に採用した設定だけを適用する。
   controllerの取得・permit・失敗時render、modelのvalidation、再利用partialの入力が変わった場合は、[lintを通過する失敗の追い方](references/review.md)を必要に応じて参照する。lintに出ない問題も、実際の取得範囲・保存結果・描画結果から判断する。
4. 修正依頼では具体的な失敗の再現と最小の修正を行い、影響する検査を再実行する。レビュー依頼では変更しない。既存のテストで契約を確認できるなら、網羅性だけを理由に追加テストを要求しない。
5. 実行結果と判断根拠、結果に関係する未確認事項を簡潔に報告する。終了コード0を文脈の安全性の保証にせず、未実行を成功と書かない。

## 判断集を選ぶ

- controller・modelの振る舞い: [責務](references/responsibilities.md) — S13 HTTPの入口と出口、S14 不変条件、S15 複数modelの処理、S16 入力・検索・表示。
- view・partial・helper・描画: [ビュー](references/views.md) — S17 入力、S18 取得・副作用。
- DB・更新・変更可能性: [データ](references/data.md) — S03 整合性、S04 削除、S05 更新結果、S07 競合、S08 migration。
- 認可・入力・job・外部連携: [境界](references/boundaries.md) — S01 認証・認可・tenant、S02 SQL・出力、S06 外部副作用、S11 cache・秘密。
- 性能・業務値・テスト: [運用とテスト](references/testing.md) — S09 query、S10 時刻・金額、S12 テスト。
- 短い失敗例: [具体例](references/review.md)。callback移行等の提案はその前提が実際に必要か確認する。

## 指摘する条件

指摘には、対象のファイルと行、発生する入力・状況、期待と実際の差、観測される損害、最小の修正と必要な検証を示す。「将来つらくなりそう」「推奨の形と違う」だけでは指摘しない。型・業務・認可の証拠が足りなければ欠陥と断定せず、結果に影響する具体的な疑問だけを確認する。確認不足それ自体を大量の指摘にしない。

copの構文検出は候補であり、採用した方針とコードの意図を照合する。callbackで認証・ロードする、modelが正当な同名属性を持つ、理由のあるdefault scope・bulk更新を使う、単一actionのpartialがinstance variableを読む、テストで部分stubを使うことは、それだけでは欠陥ではない。

判断集の「改善」「検証」は該当する失敗がある場合の候補で、一律の実装・テスト要件ではない。service/form/query/presenterへの抽出、全local化、全関連への制約、全テストの書き換えを要求しない。変更がなく仕様を満たす既存領域へ整理を広げない。

採用済みの方針に正当な例外がある場合は設定・対象範囲を調整する。未採用の設計方針のために例外コメントを要求しない。認可やデータの具体的な事故は引き続き扱う。Gem設定やスキルは外部操作・push・デプロイの権限を増やさない。
