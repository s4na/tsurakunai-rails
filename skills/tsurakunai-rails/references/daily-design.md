# 共通の設計判断

判断の基準は[チーム規約](team-policy.md)のT01〜T09に統一する。規約の目的は、多様な人が参加しても同じ変更を同じ場所へ書けること。実装とレビューの両方で、必須条件の充足と禁止形の不使用を確認する。必須条件を任意の助言へ弱めず、lintに指摘されない欠落も規約違反として扱う。規約違反と具体的な不具合は別々に報告する。

## 基本の流れ

利用者の操作 → action/jobの明示的な入口 → modelの業務API → 必要な操作object → 保存結果・応答。属性編集は直接CRUD、集約の状態遷移はmodel、独立した集約や外部I/Oの調整はoperationにする。置き場所・公開API・失敗の契約はチーム規約で一つに揃え、好みでService/Concern/commandを選び直さない。

## callback・Current・表示

T01〜T04・T07に従う。callback・Current・ConcernはRailsとして正当でも、このチームでは標準禁止の範囲がある。必要な基盤hookや移行中の既存契約は、明示的な許可と代替保証で残す。partialのlocalsは単一actionでも標準とする。トップレベルviewのinstance variable、通常のvalidation、association、明示scopeは利用する。

## 導入先に合わせる

`RAILS_TEAM_POLICY.md`、AGENTS.md/CLAUDE.md等の明示規約、RuboCopの有効設定を確認する。チームの明示決定は優先するが、既存コードやcopのOFFだけから新しい使い方の許可を推定しない。文書とlintが食い違えば該当差分を示し、合意済み規約のどちらが有効かを確認する。修正を通すための勝手なOFF・許可追加はしない。依頼範囲外の一括改修や依存追加は行わない。

## 調査から採用したこと

以下は設計判断の背景資料であり、標準の許可リストではない。今回、domain API・単純CRUD・具体的な取得量の検証は維持し、callback・Concern・Currentの文脈ごとの自由選択はチーム規約に置き換えた。


以下は2026-10-01の一次資料調査です。実在するコード、各組織の規約、本パッケージでの採用判断を区別します。GitLabの全体構造や37signalsの好みを、そのまま小さなチームへ持ち込みません。

- **GitLabの実コード**: [WebHookの入口](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/app/controllers/concerns/web_hooks/hook_actions.rb)はcreateにservice、updateに直接のmodel更新を使う。[Label](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/app/models/label.rb)は親整合性や削除条件をmodelで扱う。したがって「すべてservice」「modelはデータだけ」とは読まない
- **GitLabの取得と描画**: [LabelsPreloader](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/app/models/preloaders/labels_preloader.rb)と[テスト](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/spec/models/preloaders/labels_preloader_spec.rb)は関連・権限の一括取得とquery数を扱う。[一覧](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/app/views/projects/labels/index.html.haml)はComponentとpartialを併用する。採用するのは取得量と入力契約の明示で、特定のUI方式の全面強制ではない
- **GitLabの規約と実装の差**: [抽象化の再利用](https://github.com/gitlabhq/gitlabhq/blob/6b223d291c2b94388709a3fdce10747c13ade7ed/doc/development/reusing_abstractions.md)は、多機能なFinder等の流用が余分な条件や性能負担を持ち込む例を説明する。大規模組織向けの階層・共通service規約は丸写しせず、低水準のscope等を適切に合成する判断を採る
- **37signalsのdomain model**: [Vanilla Rails is plenty](https://dev.37signals.com/vanilla-rails-is-plenty/)はARとPOROを含むdomain modelの公開APIを重視する。[Good concerns](https://dev.37signals.com/good-concerns/)ではdomain traitのConcernと協力POROを併用する。当時はConcernかcompositionかを一律には選ばなかった。現在は凝集性を保ちつつ、T04で新規業務Concernを明示的な協力objectへ揃える
- **37signalsのcallback**: [Globals, callbacks and other sacrileges](https://dev.37signals.com/globals-callbacks-and-other-sacrileges/)は単純なlifecycle付随処理を認め、複雑なflowを区別する。callbackやCurrentの存在をhard lintで不具合と確定しない
- **Fizzyの公開実装**: [STYLE](https://github.com/basecamp/fizzy/blob/a703bf1de29ab9cc56672f125f25b14f47418f7b/STYLE.md)、[ClosuresController](https://github.com/basecamp/fizzy/blob/a703bf1de29ab9cc56672f125f25b14f47418f7b/app/controllers/cards/closures_controller.rb)、[Card::Closeable](https://github.com/basecamp/fizzy/blob/a703bf1de29ab9cc56672f125f25b14f47418f7b/app/models/card/closeable.rb)はcontroller→model操作とtransactionを示す。一方[メッセージpartial](https://github.com/basecamp/fizzy/blob/a703bf1de29ab9cc56672f125f25b14f47418f7b/app/views/cards/_messages.html.erb)は関連scopeやCurrentも使う。これを「view内DB参照禁止」の根拠にはしない。Fizzyは確認時点のcommitを固定している

この調査は、各社の全コードが同じ規約を守ることや、この方針による性能改善・開発時間削減を実証したものではありません。
