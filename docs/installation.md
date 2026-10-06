# 導入と使い方

Ruby 3.0以上、RuboCop 1.74.0以上 / 2未満が必要です。Railsの起動には依存しません。RuboCopの下限は、Rails拡張の設定を断続的に誤検出する不具合が修正された1.74.0です（[修正内容](https://github.com/rubocop/rubocop/commit/f24b7873569dda34c97924ca9d8ca48b8fdee377)）。CIはRuby 3.0・3.1・3.2・3.3・3.4・4.0とRuboCopの下限で検証します。

まだRubyGemsには公開していません。GitHubから導入できます。チームではレビュー済みのcommit SHAを `ref:` に指定し、Gemfile.lockをコミットしてください。

```ruby
# Gemfile
group :development, :test do
  gem "rubocop-tsurakunai-rails",
      git: "https://github.com/s4na/tsurakunai-rails.git",
      branch: "main", require: false
end
```

`.rubocop.yml`に次のplugin設定を追加します。設定ファイルがなければ、この内容で作成できます。Rails Omakase等の別のルールセットは必要ありません。既存の設定がある場合は、その内容を残して追加してください。

```yaml
# .rubocop.yml
plugins:
  - rubocop-tsurakunai-rails
# Railsのバージョンを推定できない構成では、実際の対象版を明示する。
# AllCops:
#   TargetRailsVersion: 7.1
```

```sh
bundle install
bundle exec tsurakunai-rails init-policy
# プロジェクト内へ配置する。必要なクライアントだけ実行する。
bundle exec tsurakunai-rails install-rules --target codex
# 表示した共通ルールを、有効なプロジェクト指示へ手動で統合する。
bundle exec tsurakunai-rails install-skill --target codex
# Claude Codeを使う場合
bundle exec tsurakunai-rails install-rules --target claude
bundle exec tsurakunai-rails install-skill --target claude
```

Codexでは`.agents/skills/`、Claude Codeでは`.claude/skills/`配下に、`tsurakunai-rails`・`tsurakunai-rails-implement`・`tsurakunai-rails-review`の3フォルダを配置します。共通資料は`tsurakunai-rails/references/`に一度だけ置き、他の2つが参照します。`--project PATH`で別のプロジェクトを指定できます。配置したファイルをコミットすればチームで共有できます。いずれかの既存フォルダがあれば、全体の配置を始めず終了します。既存ファイルは上書きしません。更新時はGem同梱の`skills/`の3フォルダと比較し、ローカル変更を保全してから入れ替えてください。更新・アンインストールは3フォルダを一組として扱います。旧版の1フォルダだけを残すと、新しい相互参照は使えません。アンインストール時はGem・plugin設定も取り除きます。

`init-policy`はRAILS_TEAM_POLICY.mdと.rubocop-tsurakunai.ymlを生成します。どちらかが既存なら配置前に終了し、上書きしません。既存.rubocop.ymlへ次を追加します。既存inherit_fromがある場合はリストへ加えます。

```yaml
inherit_from:
  - .rubocop-tsurakunai.yml
```

必須の認証hook名と理由・代替保証を生成ファイルへ登録してから検査してください。

## AIが常時読むルールを配置する

`install-rules`は`RAILS_TEAM_POLICY.md`があるプロジェクトで[共通ルール](../config/agent_rules.md)を提供します。ルールには「必須の形を満たす」「禁止形を使わない」を実装とレビューの両方に課し、具体的なT01〜T09は規約の正本を参照します。スキルが未導入でも同じ規約を使います。

**Codexは共通ルールを標準出力へ表示し、指示ファイルを作成しません。** 実際に有効なプロジェクト指示へ、他の内容を残して手動で統合してください。AGENTS.override.md、AGENTS.md、[独自名のfallback](https://learn.chatgpt.com/docs/agent-configuration/agents-md#customize-fallback-filenames)のどれを読むかは、[管理設定](https://learn.chatgpt.com/docs/enterprise/managed-configuration#locations)や[クラウド設定を含む優先順位](https://learn.chatgpt.com/docs/config-file/config-basic#configuration-precedence)に依存します。別のインストーラから全設定を確実に観測できないため、ファイル名を推測しません。設定と読み込んだ指示を確認してから統合します。表示コマンドの成功だけでは導入完了ではありません。

Claude Codeは`.claude/rules/tsurakunai-rails.md`へ配置します。[公式のルール読み込み](https://code.claude.com/docs/en/memory)に従い、paths指定のないMarkdownなので特定ファイルを開いたときだけのルールにはしません。配置先が既存、または指示ディレクトリがsymlinkなら上書きせず終了するため、既存の有効な指示へ手動で統合してください。既存CLAUDE.md、グローバル設定、チーム規約は変更しません。

AIへの指示は実装・レビューの基準であり、意味的な設計を自動的に強制するlintではありません。

統合・配置後は新しいエージェントセッションを開始し、読み込んだ指示のソースを確認します。Codexでは読み込んだ指示の列挙を依頼し、Claude Codeでは`/context`で確認できます。下位の指示やクライアント設定の除外も確認してください。配布物からの共通ルール表示とClaudeの配置は検証していますが、各クライアントの実セッションでの自動読み込みはこのリポジトリのCIでは検証していません。

更新時は共通ルール、3スキル、チーム規約をそれぞれ新しい同梱版と比較し、チームの変更を残して統合します。アンインストールでは統合したルールの該当部分だけを取り除き、他の指示を消しません。Claudeの専用ファイルも、ローカル追記がないか確認してから取り除きます。

## 使う

既存アプリへの段階導入は[導入ガイド](adoption.md)、具体的に何を検出できたかは[実用検証](acceptance.md)を参照してください。

```sh
# Minitest。プロジェクトで実際に使っているテスト入口を指定する。
bundle exec tsurakunai-rails check -- bin/rails test
# RSpec
bundle exec tsurakunai-rails check -- bundle exec rspec
# RuboCopだけを実行する場合
bundle exec rubocop --only TsurakunaiRails,Rails,RSpec
```

`check`はこのpluginを明示的に読み込み、lintが失敗してもテストを実行します。両方成功なら0、どちらか失敗なら1、引数や導入先が不正なら2を返します。テストコマンドはシェル展開せず実行するため、パイプやリダイレクトは使えません。

Ruby lint・View lint・Testsごとの結果を表示します。`View lint: SKIPPED`は未検査を表し、成功には数えません。viewを含む検査が必要なら、任意ERBセットを導入して`--views`を指定します。

実装するときはCodexで`$tsurakunai-rails-implement この変更を実装してください`、レビューでは`$tsurakunai-rails-review この変更を編集せず確認してください`と呼びます。Claude Codeは先頭を`/`にします。既存の`tsurakunai-rails`も両手順へ案内する入口として残ります。

実装スキルは必須の入口・状態・失敗契約を作り禁止形を避ける手順、レビュースキルは必須条件の欠落と禁止形の使用を両方確認する手順です。[共通資料](../skills/tsurakunai-rails/references/daily-design.md)を共有します。**CLIの成功は文脈レビューの完了ではありません。** CIはAIの判断を自動実行しません。

## 標準方針を調整する

pluginを追加すると、設計方針11ルールと事故防止8ルール、RSpec7ルールが有効になります。以前のバージョンから更新すると新しい指摘が出るため、[更新時の確認](adoption.md)を先に読んでください。ControllerCallbacksとModelCallbacks、ImplicitContext、Concernも標準ONです。旧config/policies.ymlは互換用です。

明示的なチームの決定としてlintをoverrideできます。理由と代替保証をRAILS_TEAM_POLICY.mdへ揃え、移行中の機能は対象を狭く限定します。既存の明示OFFは再有効化しません。

```yaml
TsurakunaiRails/ControllerCallbacks:
  Enabled: false
```

実装・レビューでは[共通の設計判断](../skills/tsurakunai-rails/references/daily-design.md#導入先に合わせる)を標準で使います。AGENTS.md等の既存規約や方針をOFFにする指示を優先します。RuboCopの設定とは別です。

## RSpecとERB

RSpec7ルールはplugin導入で有効になります。対象はRSpecのspecファイルで、RSpec本体をアプリへ追加したり、Minitestを置き換えたりはしません。`rubocop-rspec`は従来からこのGemの依存です。既存の`config/rspec.yml`読み込みも互換のため維持しますが、指定は不要です。

```yaml
RSpec/AnyInstance:
  Enabled: false
```

ERBを使うアプリでは、[ERB用の標準設定](view-inputs.md)と`erb_lint`を導入し、`check --views -- <テストコマンド>`を使います。`--views`なしでは設定があっても未検査です。strict localsは対応するRailsで選べます。ERBを使わないプロジェクトにこの依存は不要です。

各ルールの対象・設定・例外は[ルールの詳細](rules.md)を参照してください。書式やDSLの好みに関するルールは一括で有効にしません。

## 例外と段階導入

callback制限は標準ONです。認証基盤などで必要なhookは、全actionでの停止・拒否を確かめ、事前に許可名で残します。

```yaml
TsurakunaiRails/ControllerCallbacks:
  Enabled: true
  AllowedMethods:
    - authenticate_user! # 認証基盤の必須hook。request testで未認証拒否を検証。
```

複数のcallbackを同時登録した場合、すべてが許可名でなければ検出します。ブロック・動的な登録は許可名で見逃しません。認証の明示呼び出しへの移行では、redirect後の停止と全actionの認可を必ず確認してください。

個別の保守処理では理由と代替保証をコメントし、該当行または狭い範囲だけ `rubocop:disable` を使えます。既存アプリでは既存規約と新しい標準方針の違いを確認し、合わない項目をOFFにできます。機械的な全件置換は行わず、具体的な問題に関係する機能を最小限に修正・検証します。
