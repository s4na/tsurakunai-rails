---
name: tsurakunai-rails-implement
description: Implement Rails changes by satisfying required team contracts and avoiding prohibited forms for flow, responsibilities, inputs and failures.
---

# Railsの変更を実装する

[チーム規約](../tsurakunai-rails/references/team-policy.md)を読み、T01〜T09を標準にする。導入先の `RAILS_TEAM_POLICY.md` と明示規約・lint設定を先に確認し、既存の合意を優先する。同じ仕事を同じ形に揃え、個人の好みや近隣コードの存在だけで許可を増やさない。

適用する規約の**必須条件を実装し、禁止形を使わないこと**を同時に満たす。「どうあるべきか」を任意の設計案、「どうでないべきか」をレビュースキルだけの仕事にしない。lintが通る代案でも、必須の責務・入力・失敗契約が欠ければ採用しない。

## 実装する

1. route/action/jobから対象の操作と既存の公開APIを追う。関係するT01〜T09について、必要な形・契約、避ける形、既存の明示例外を対で確認する。利用者、許可入力、認可済みscope、成功・拒否・保存失敗後の結果を決める。未コミット変更を保護する。
2. **属性編集なら直接CRUD、集約の状態遷移ならmodelの業務名メソッド、別集約・外部I/Oの調整ならoperation**へ置く。新規operationは普通のclassの `call` を使う。既存の置き場所・API契約が明示されていれば揃える。一回のsaveを転送する層は作らない。
3. T01〜T04に従い、actionの対象取得・操作を見せ、業務callback/Concernを追加しない。actor・tenant・必要な時刻は引数へ。認証等の承認済みhookは維持し、変更時には全actionの停止・拒否を確認する。許可名へ業務処理を紛れ込ませない。
4. T08〜T09に従い、不変条件・保存結果・transactionと応答を作る。CRUDは更新結果で分岐、modelの状態遷移はbang名の公開API、operationはcallと内部のbang保存を使う。成功値・業務拒否・保存失敗を規約の契約へ揃え、既存の明示契約は維持する。外部処理があれば外側transaction・commit・送信失敗・再実行を確認し、callbackをsave直後へ移すだけで済ませない。
5. T06〜T07に従い、取得scope・並び・ページング・関連を描画前に決め、全partialへlocalsを渡す。既存UI基盤を使い、入力を渡すだけのcomponentやformを増やさない。保存失敗の再描画でも入力とerrorsを保つ。
6. 変更に関係する公開結果を実行で確かめる。正常・拒否・保存失敗後のDB/応答/描画、必要なrequestなしのmodel/job実行を確認する。既存の保証を重複させず、再試行やquery数は変更に関係するとき検証する。
7. 導入済みGemでは `bundle exec tsurakunai-rails check -- <実際のテスト入口>`、ERBセット導入済みなら `check --views -- ...` を使う。lint失敗時は規約IDと置き換え先で修正し、通すためのOFF・例外追加はしない。[レビュースキル](../tsurakunai-rails-review/SKILL.md)で、必須条件の充足と禁止形の不使用をそれぞれ最終確認する。lint成功だけで完了にせず、規約と実行結果の根拠、重要な未確認事項を簡潔に報告する。全IDの定型報告書は作らない。

例外が今回必要なら、対象・理由・代替保証を具体化してチームの決定にする。既存の明示許可は再承認しない。変更していない領域の一括整理、未承認の公開・デプロイは行わない。セルフレビューと独立レビューを区別する。

## 関係する詳細だけ読む

- [責務と公開API](../tsurakunai-rails/references/responsibilities.md): model/operation/query/formの境界
- [状態とDB](../tsurakunai-rails/references/data.md): 保存、競合、migration
- [権限と副作用](../tsurakunai-rails/references/boundaries.md): 認可、外部I/O、commit
- [取得と描画](../tsurakunai-rails/references/views.md): render入口・locals・失敗時表示
- [テストと運用](../tsurakunai-rails/references/testing.md): 公開結果、件数、時刻、再実行
