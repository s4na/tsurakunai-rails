---
name: tsurakunai-rails
description: Implement or review Rails changes using focused RuboCop checks and evidence-based review of authorization, data integrity, controller/model responsibilities, view inputs, side effects, and behavioral tests. Use for Rails application changes, not general Ruby formatting.
---

# つらくないRails

変更範囲の重大な問題だけを扱う。命名、好み、メソッドの長さ、サービスクラスの有無を理由に指摘しない。Rails自体の正誤ではなく、変更で起こる具体的な失敗と修正の根拠を示す。

## 実行とレビューを両方行う

1. 依頼と差分から期待する振る舞いを整理し、対象プロジェクトのルール、Gemfile、RuboCop設定、テスト入口を読む。未コミット変更を保護する。
2. `rubocop-tsurakunai-rails`が設定されているか確認する。導入済みなら `bundle exec tsurakunai-rails check -- <実際のテストコマンドと引数>` でRuboCopと変更に適したテストを実行する。未導入なら導入手順を案内し、既存のlint・テストを実行する。未導入を検査済みと扱わない。RSpecなら `inherit_gem: rubocop-tsurakunai-rails: config/rspec.yml` に相当する設定の有無も確認し、未導入なら任意の7ルールセットを案内する。未導入のセットを検査済みと扱わず、既存の方針を勝手に上書きしない。
3. 対象差分と必要な呼び出し元、認可、スキーマ、ジョブ、テストを追う。下記の該当項目を確認する。構文検査は標準16ルール、RSpec向け7ルールの選択セットがある。文脈の判断は以下の18領域から変更に関係するものを選ぶ。
4. 修正依頼では再現または振る舞いのテストと最小の修正を行い、関連するチェックを再実行する。レビュー依頼では勝手に変更しない。仕様が決められないときは根拠と選択肢を示す。
5. 完了報告に「実行したコマンドと結果」「意味的レビューの根拠」「未検証・要判断」を分けて記録する。チェックの終了コード0は設計レビューの完了を意味しない。未実行を成功と書かない。

## 重要な判断を選ぶ

- controller・modelの実装や置き場所を変更する場合は、まず[責務の判断集](references/responsibilities.md)を読む: **S13 controllerの入口と出口、S14 modelの不変条件、S15 複数modelの業務処理、S16 入力・検索・表示の境界**。通常のCRUD・局所的なcallback・純粋なmodelの計算を正当なケースとして扱い、業務条件の重複やHTTPへの暗黙依存、失敗時の不整合があるときに具体的な移動先を検討する。

- view・partial・helper・描画経路の変更では[ビューの判断集](references/views.md)を読む: **S17 ビューとpartialの入力、S18 描画とデータ取得・副作用**。トップレベルviewのinstance variableは認め、再利用partialの暗黙依存、必須入力の不足、validation失敗時の表示、N+1、描画による状態変更を具体的な呼び出し元と結果で判断する。Rubyのlint成功をtemplate検査済みと扱わない。
- DB・model・更新の変更では[データの判断集](references/data.md)を読む: **S03 DB整合性、S04 関連と削除、S05 更新結果・transaction、S07 競合・状態遷移、S08 migrationとdeploy**。
- controller・job・外部連携・cacheの変更では[境界の判断集](references/boundaries.md)を読む: **S01 認証・認可・テナント、S02 入力・SQL・出力、S06 外部副作用・ジョブ、S11 cache・ログ・秘密**。
- 一覧・集計・時刻・金額・テストの変更では[運用とテストの判断集](references/testing.md)を読む: **S09 query・一覧・バッチ、S10 時刻・日付・金額、S12 テストの信頼性**。
- callback移行など短い例が必要なら[既存の具体例](references/review.md)を読む。

各判断集にある失敗シナリオ、改善案、正当な例外、検証を使う。すべての領域を全変更へ要求しない。構文検査だけでは保証できない条件付きindex、戻り値の呼び出し元、動的API、bulk処理、transaction外の副作用を見落とさない。schemaや認可の実装がない場合に想像で安全・危険と断定しない。

## 指摘の基準

指摘はファイルと行、具体的な入力・状況、観測される損害、最小の修正案、検証方法を添える。確認できない仮説は質問・未検証として扱う。RuboCopの構文検出に反応して根拠なく設計違反を増やさない。

例外は対象を絞り、理由とDB制約や代替の保証を記録する。認証フレームワークなどの正当なcallbackを消す、bulk updateを1件ずつ更新に変える、全モデルをサービスに移すといった機械的な改変をしない。Gem設定やスキルは外部操作・push・デプロイの権限を増やさない。
