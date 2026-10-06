# 既存Railsアプリへ段階導入する

現在の標準は[チーム規約T01〜T09](../skills/tsurakunai-rails/references/team-policy.md)です。以前のcallback・Current・Concernの自由な使い分けから、チームで決めた限定へ変わります。plugin導入で設計11、事故防止8、RSpec7 copが有効になります。新しい指摘は動作不良とは限りません。

## 既存契約を保って始める

1. [導入手順](installation.md)でGem、`init-policy`の規約と設定、`install-rules`のAIルール、3スキルを導入します。Codexの共通ルールは実際に有効な指示へ手動で統合します。既存ファイルは保全し、生成した設定を既存.rubocop.ymlへinheritします。
2. controllerの基盤hookを列挙します。認証等で必要な名前をAllowedMethodsへ登録し、RAILS_TEAM_POLICY.mdに対象・理由・未認証拒否の保証を残します。承認済みhookをactionから呼び直して二重実行しません。
3. 既存model callback/Concern/Current/partialの暗黙入力を棚卸しします。保存・通知等の契約と呼び出し元を確認し、既存機能を保持したまま今回の変更対象から標準へ寄せます。未移行範囲は理由付きの狭いExclude・行単位disable等で残します。全体OFFにして新規利用まで自由にしない方針を規約へ明記します。
4. lintの実効設定、実リクエスト・保存・描画を確認し、規約と許可設定を同じ変更でレビューします。

```sh
bundle exec rubocop --show-cops TsurakunaiRails/ControllerCallbacks TsurakunaiRails/ModelCallbacks TsurakunaiRails/ImplicitContext TsurakunaiRails/Concern
bundle exec rubocop --only TsurakunaiRails,Rails,RSpec
bundle exec tsurakunai-rails check -- bin/rails test
# ERB設定を導入済みなら check --views -- ...
```

`DisabledByDefault: true`、既存override、Include/Excludeで無効になる検査を確認します。Ruby/View/TestsのPASSと未検査を分けて読み、lint失敗後もテストが実行されることを使って動作の退行を調べます。

## callbackの移行

対象ロードはactionで明示します。認証の必須hookは許可して残し、全actionの未認証・別tenant・権限不足を検証します。modelの状態遷移は業務名メソッドへ置き、全呼び出し元がそこを通ることと、直接保存の不変条件を確認します。

通知をcallbackからsaveの次へ移すだけでは、外側transactionのrollbackや送信失敗を扱えません。必要な配信保証に応じ、利用中のRails/queueのcommit連携や永続送信記録と冪等性を設計します。明示的な局所hookが必要なら登録種類と名前をAllowedCallbacksへ事前許可できます。本体と適用範囲はlintでは保証できません。

```yaml
# 同種・同名の全model hookに適用される点に注意。
TsurakunaiRails/ModelCallbacks:
  AllowedCallbacks:
    before_validation: [normalize_email]
```

一箇所だけの既存通知契約は狭いExcludeや行単位disableを使います。基盤の保証を壊してまで規約へ合わせず、対象・理由・代替保証を記録してチームの例外にします。

## バージョン更新

旧スキル名は互換入口として維持します。Gem同梱の3フォルダを一組で比較し、ローカル変更を保全して更新します。既存フォルダが一つでもあるとinstallerは上書きしません。RAILS_TEAM_POLICY.md、生成した設定、AIの有効な指示へ配置・統合した共通ルールも、新しい標準との差分を確認します。既存の明示OFF・許可名は勝手に消しません。

旧config/policies.ymlは互換用に残します。ControllerCallbacksを明示OFFにした設定は新しい標準へ自動復帰しません。文書の採用方針と実効lintが違う場合は、それを見えるようにしてチームで調整します。

## 最初の変更で価値を確かめる

属性編集・状態遷移・複数集約の変更を選び、実装担当とレビュースキルが同じ規約ID・置き場所・失敗契約へ辿り着くかを確認します。規約違反はIDと修正先、不具合は入力と状態・応答の差を求めます。指摘数や全項目の報告書を増やしません。

必要な確認は、拒否された更新がDBを変えないこと、保存失敗の入力/errorsが表示へ残ること、request外のmodel操作、外側transactionと送信、全partial呼び出し元のlocalsです。変更に関係するものを選びます。

数件の実例で、流儀の選択や暗黙依存を探す負担が減ったか、誤検出と例外の管理がそれを上回らないかを確認します。既存RuboCopだけで同じ結果が得られるなら独自検査を残す理由を問い直します。[改善フローと評価記録](improvement.md)に結果を戻します。
