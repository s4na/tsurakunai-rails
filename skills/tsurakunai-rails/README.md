# つらくないRailsスキルセット

- [実装](../tsurakunai-rails-implement/SKILL.md): 利用者の操作から入口・状態・失敗・テストを組み立てる
- [レビュー](../tsurakunai-rails-review/SKILL.md): 規約違反と不具合の経路を分けて編集せず確認する
- [チーム規約T01〜T09](references/team-policy.md): 同じ仕事の書き方と例外の基準
- [共通の設計判断](references/daily-design.md): 調査の背景と規約の使い方

`bundle exec tsurakunai-rails install-skill --target codex`または`--target claude`で3つの入口をまとめて配置します。既存の`$tsurakunai-rails`・`/tsurakunai-rails`も依頼に合う手順へ案内します。

導入先のRAILS_TEAM_POLICY.mdと明示規約を優先します。規約とlintの例外はチームで揃え、実装者が勝手にOFFへ変更しません。
