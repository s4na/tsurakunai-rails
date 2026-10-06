# つらくないRails

**経験や好みの違う人が増えても、同じ変更を同じ場所へ書けるRailsチーム規約と検査ツールです。** 入力・実行順序・責務を隠す便利な機能を制限し、その中で業務を自由に表現します。熟練者が毎回「今回は例外でよい」と判断する運用を標準にしません。

[なぜ作るか](docs/purpose.md) · [チーム規約 T01〜T09](skills/tsurakunai-rails/references/team-policy.md) · [現行→あるべき姿→差分と改善フロー](docs/improvement.md)

## 書き方を揃える

- 属性編集は **controller→modelの直接CRUD**。保存結果で成功／失敗を分岐します。
- レコードとその明細の状態遷移は **modelの業務名メソッド**。条件・transaction・失敗をここへ揃えます。
- 独立した集約や外部I/Oの調整だけ **operationのcall**。全CRUDのService化や共通result frameworkは導入しません。
- 対象取得と操作はactionで見せ、actor・tenant等は明示入力にします。業務callback、業務Concern、model/job等のCurrentを標準では使いません。
- 取得条件は明示scope、partialは単一action用もlocals。既存UI基盤へ揃えます。

認証基盤の必須hookや既存の保存契約には例外が必要です。対象・理由・代替保証をチーム規約とlint設定へ残し、変更ごとに許容基準が変わらないようにします。Railsや37signalsの使い方が誤りだと主張するものではありません。[採用理由と調査記録](docs/purpose.md#37signalsdhhとの関係)

## 導入する

Gem・ルール・スキルの[導入手順](docs/installation.md)に従い、チームの規約と設定を生成します。

```sh
bundle exec tsurakunai-rails init-policy
bundle exec tsurakunai-rails install-rules --target codex
# 表示した共通ルールを、有効なプロジェクト指示へ手動で統合する。
bundle exec tsurakunai-rails install-skill --target codex
# Claude Codeを使う場合は --target claude
```

`init-policy`は `RAILS_TEAM_POLICY.md` と `.rubocop-tsurakunai.yml` を作ります。既存ファイルは上書きしません。生成した設定を既存 `.rubocop.yml` のinherit_fromへ追加し、必要な認証hookを許可してから検査します。[既存アプリの段階導入と更新](docs/adoption.md)

```sh
bundle exec tsurakunai-rails check -- bin/rails test
# RSpecなら: check -- bundle exec rspec
# ERBを使う場合: install-view-lint後に check --views -- ...
```

`install-rules`は同じ規約を読む[共通ルール](config/agent_rules.md)を提供します。Codexは表示したルールを有効なプロジェクト指示へ手動で統合し、Claude Codeは`.claude/rules/tsurakunai-rails.md`へ配置します。既存の指示を保全する[手順と読み込み確認](docs/installation.md#aiが常時読むルールを配置する)も行います。

## 実装とレビューを同じ基準にする

- [tsurakunai-rails-implement](skills/tsurakunai-rails-implement/SKILL.md): T01〜T09の必須条件を実装し、禁止形を避け、両方を検証します。
- [tsurakunai-rails-review](skills/tsurakunai-rails-review/SKILL.md): 必須条件の欠落と禁止形の使用を同じIDで検査し、具体的な不具合とは分けて根拠と修正先を示します。
- [tsurakunai-rails](skills/tsurakunai-rails/SKILL.md): 既存名の互換入口です。

Codexでは `$tsurakunai-rails-implement` / `$tsurakunai-rails-review`、Claude Codeでは `/` を使います。導入先の明示規約を優先し、lintを通すための勝手なOFF・許可追加はしません。

ルールも両スキルも「どうあるべきか」と「どうでないべきか」で拘束します。**禁止に触れないことと、必要な形・契約があることの両方が合格条件です。** [ルールとスキルの対応](docs/rules.md) · [lintが通っても不合格になる対例](skills/tsurakunai-rails/references/team-policy.md#禁止構文がなくても合格にしない例)

## 自動検査の範囲

独自7 cop、選択したRuboCop Rails 12 cop、RSpec 7 copが標準ONです。callbackの登録、Currentという定数参照、ActiveSupport::Concernの宣言、default_scope、validation bypass、保存APIやDB関連の構文を検出します。自動修正は無効です。[全ルール・対象・例外・限界](docs/rules.md)

ERBは別のERB Lint設定でpartialのinstance variableを検査します。`--views`なしでは未検査です。認可・transactionの意味、動的な定義、別名のglobal、外部送信保証はlintだけでは分かりません。**CLI成功と文脈レビューの完了は別です。**

[実用検証と限界](docs/acceptance.md) · [開発とテスト](docs/development.md) · [リリース](docs/releasing.md) · [MIT License](LICENSE)
