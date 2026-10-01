---
name: tsurakunai-rails-implement
description: Build Rails changes from a user operation through domain APIs, explicit boundaries, and observable tests.
---

# Railsの変更を実装する

[共通の設計判断](../tsurakunai-rails/references/daily-design.md)を使い、動作するコードの置き場所を決める。クラスの種類を揃えることより、一つの利用者操作を少ない場所で理解・変更できる形を作る。導入先の規約と今回の依頼範囲を優先する。

## 作る順序

1. **一つの操作を追う。** route、controller/job、model、近隣のテストを読み、利用者・入力・成功結果・失敗結果を決める。既存の公開APIを使えるか確認し、未コミット変更を保護する。
2. **入口を決める。** controllerは認証、対象の認可、入力の取り出し、HTTP応答を担当する。jobにも必要なactor・対象・権限の前提を渡す。単純なCRUDならcontrollerからmodelを直接呼ぶ。
3. **状態を守る場所を決める。** レコードや自然な集約の不変条件・状態遷移はmodelの業務名メソッドへ置く。関連更新があるだけでserviceへ移さない。凝集したdomain traitは既存のconcernへまとめてもよい。
4. **独立した仕事だけ分ける。** 外部I/O、独立計算、複数集約を調整する手順は、必要なら名前付きPOROへ分ける。model配下のPOROへの委譲も選べる。値だけで済む計算は明示入力と戻り値にし、不要なDB・時刻・共有状態に依存させない。クラスや関数の形は仕事に合わせる。
5. **失敗の境界を先に作る。** 一緒に成功すべきDB変更をtransactionへまとめ、保存失敗を呼び出し元へ伝える。外部副作用はrollbackできないので、commit、送信失敗、再実行の扱いを決める。単純なlifecycle callbackと複雑な業務フローを区別する。
6. **取得と表示の契約を作る。** 認可済みscope、並び順、ページング、必要な関連取得を先に決める。複雑になった検索だけFinder/query objectへ分ける。partialは明示入力で使い、振る舞い・再利用・描画テストの利益があるUIは既存component基盤やViewComponentへまとめる。
7. **結果で確かめる。** 成功、保存失敗、認可拒否を公開入口とDB・描画結果で確認する。外部処理や再試行がある変更では二重実行も確認する。既存テストが保証する部分を重複させない。性能変更は件数とquery数等で比較する。
8. **検査し、レビューへ渡す。** 導入済みのlintと実際のテストを実行する。Gem導入済みなら`bundle exec tsurakunai-rails check -- <テストコマンド>`、ERB検査を導入済みなら`check --views -- <テストコマンド>`を使う。[レビュースキル](../tsurakunai-rails-review/SKILL.md)の観点で最終差分を確認し、実行結果・未確認事項を報告する。独立レビューを行ったと偽らない。

## 判断に迷ったら

- [業務の入口と責務](../tsurakunai-rails/references/responsibilities.md): controller、model、PORO、concernの選択
- [状態とDB](../tsurakunai-rails/references/data.md): 不変条件、保存結果、競合
- [権限と外部I/O](../tsurakunai-rails/references/boundaries.md): actor、tenant、commitと送信
- [取得と描画](../tsurakunai-rails/references/views.md): query、partial、component、入力
- [テストと運用](../tsurakunai-rails/references/testing.md): 結果の保証、件数、時刻、再実行

命名は対象と仕事が分かる業務語を選ぶ。`Service`等の接尾辞や行数だけで良し悪しを決めない。変更していないコードの一括整理、未承認の依存追加・公開・デプロイは行わない。
