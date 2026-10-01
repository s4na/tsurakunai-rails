# つらくないRailsスキル

Railsの実装・レビューで、RuboCopと実際のテストを実行し、認可・整合性・副作用・振る舞いの保証を確認します。一般的な書式や設計の好みは指摘しません。

Gem同梱CLIの `tsurakunai-rails install-skill --target codex` または `--target claude` でプロジェクトへ導入できます。Codexでは `$tsurakunai-rails`、Claude Codeでは `/tsurakunai-rails` で呼び出します。手順と判断基準は `SKILL.md` を参照してください。

自動のlint・テスト成功だけで意味的レビュー完了とは扱いません。未実行・不明な仕様は明示し、導入先のルールと依頼範囲を守ります。
