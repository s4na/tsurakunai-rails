# ビューの変数と描画の境界

変更に関係する項目だけを確認してください。[日常の設計方針](daily-design.md)は標準で適用し、このガイドでは正しさと例外を確認します。変更していない実装や、必要な動作を確認できているテストまで書き換える必要はありません。

[共通の設計判断](daily-design.md#callbackcurrent表示)に沿って、明示入力のpartialや既存component基盤を選びます。ViewComponentは振る舞い・再利用・独立テストの利益がある場合の選択肢です。以下はどの表示方式にも必要な確認です。

このパッケージでは、変数の数や命名より、どの入口から描画しても必要な入力・認可・表示結果が保たれることを重視します。トップレベルのviewへcontrollerから渡す `@invoice` 等はRailsの通常の使い方です。一律に禁止せず、再利用するpartialの隠れた入力と、失敗時に欠ける変数を追います。例は部分例であり、認可・schema・失敗応答は実アプリに合わせて確認します。

<a id="s17-ビューとpartialの入力を明示する"></a>

## ビューとpartialへ渡す値

**起きやすい問題**: `_invoice.html.erb` が `@invoice` と `@can_edit` を暗黙に読み、一覧・詳細・Turbo更新で別の値を表示する。controllerの成功経路だけが変数を用意し、validation失敗後の `render :new` では選択肢が消える。`defined?` / nil判定 / `local_assigns` による救済が、必須入力の渡し忘れを隠す。

**確認すること**: トップレベルのviewはactionとの契約としてinstance variableを使ってよい。異なる呼び出し元で対象や表示条件が食い違うなら、locals等の明示的な入力を候補にする。単一action専用のpartialが用意済みのinstance variableを読むだけなら欠陥としない。入力を渡すためだけに大量のpresenterやcomponentを作る必要はない。既存のcomponentを使うならその入力契約を同様に確認する。

```erb
<%# 問題候補: partialが特定controllerの暗黙の状態へ依存する %>
<%= @invoice.number %>
<% if @can_edit %>
  <%= link_to "編集", edit_invoice_path(@invoice) %>
<% end %>
```

```erb
<%# 呼び出し側: 対象と表示条件を明示する %>
<%= render partial: "invoices/invoice",
           locals: { invoice: @invoice, can_edit: @can_edit } %>
```

```erb
<%# _invoice.html.erb: 対応するRailsではstrict localsも選べる %>
<%# locals: (invoice:, can_edit: false) %>
<%= invoice.number %>
<% if can_edit %>
  <%= link_to "編集", edit_invoice_path(invoice) %>
<% end %>
```

ここでは `invoice` が必須、`can_edit` は省略時に非表示という意図を持つ任意入力です。必要な権限判定を忘れたのに `false` で隠れる設計なら、`can_edit` も必須にする。strict localsは導入先のRailsとtemplate engineの対応を確認して選び、非対応環境へ必須導入しない。collection renderでは `as:` / 規約上のlocal名も含めて契約を揃える。Railsが用意するcounter・iteration local等を未知の依存と決めつけない。

**actionの全経路**: new/editだけでなく、create/updateのvalidation失敗、別format、Turbo Stream、mailer、layoutからの呼び出しも確認する。失敗後のformはerrorsと入力した値を持つ対象を使い、別のnew/findで置き換えて消さない。選択肢などは失敗時にも同じ認可範囲で用意する。準備処理は既存のcallbackでも局所的なメソッド呼び出しでもよい。必要な経路を覆い、入力とerrorsを保つことを確認し、方式だけを理由に変更しない。

**optionalとnil**: 値がなくてもよい仕様ならfallbackは正当。必須データの欠落を `@invoice&.number` や空文字で隠して完了扱いにしない。optionalな装飾と、存在しなければ操作できない業務データを分ける。

**認可**: `can_edit` などは表示条件であり、更新actionの認可を代替しない。ボタンを隠すだけで権限が守られると扱わず、直接requestでも拒否されることを確認する。user/tenant別の表示をcacheする場合は[キャッシュとログ](boundaries.md#s11-cacheログ秘密)のkey・失効も追う。

**例外**: layoutの共通設定、既存の認証helper、Railsのform builder等は、それだけでlocals化を要求しない。移行では変更したpartialと呼び出し元を対象にし、全viewのinstance variableを機械的に置換しない。

**検証**: 同じpartialを異なるrecordや権限条件で描画して表示対象・ボタンを確認する。validation失敗のrequestでerrors・入力値・選択肢が残ることを確認する。strict localsを選んだ場合は必須入力の欠落が見逃されないことも確認し、`assigns` の存在やpartialへの引数だけで最終表示の保証を終えない。

<a id="s18-描画で業務処理とデータ取得を隠さない"></a>

## ビューやhelper内のDBアクセスと更新

**起きやすい問題**: view/helperから `Invoice.find(params[:id])` してtenantの取得範囲を失う。各行のhelperが関連を取得してN+1を作る。表示のたびに `update!`、メール送信、外部APIを実行し、preview・再描画・cache missが業務を変える。表示用の変数へ代入したつもりが共有modelを変更し、後続partialの表示が変わる。

**確認すること**: view/helperは渡されたデータを表示へ変換する。認可対象の取得、取得計画、業務状態の変更はcontroller/query/modelの適切な境界へ置く。複雑な表示はhelper/presenter/component等を候補にするが、短い表示条件・ループ・日付の整形はviewにあってよい。DBを読むメソッドか純粋な値かは名前では判定せず、関連・helper・presenterの実装まで追う。

**query**: Active Recordのrelationは遅延評価されるため、渡したrelationの最初の列挙でSQLが走ること自体を違反にしない。必要なtenant scope・pagination・関連の取得計画を描画前の境界で決める。`each` 内のassociation参照やhelperが増やすqueryを[クエリとページング](testing.md#s09-query一覧バッチ)と合わせて確認する。全relationの無条件 `to_a`、全associationのpreload、query数の固定値だけのテストを要求しない。

**値の扱い**: 表示用の文字列やフラグの局所変数は正当。元recordの属性へ表示文字列を代入したり、渡された配列を `sort!` 等で変更し他の描画へ影響させたりしない。変更を必要とする仕様では所有者と影響を明示し、必要なら新しい値を作る。viewのlocalは安全でも、その参照先objectの変更が無害とは限らない。

**出力**: 入力値を `raw` / `html_safe` へ流す、文脈の異なるHTML/JavaScript/URLへそのまま埋め込む問題は[入力値とSQL・HTML](boundaries.md#s02-入力sql出力)を確認する。業務上の表示条件とescapingは別に検証する。

**例外**: 読み取り専用の既存helper等は呼び出すだけで欠陥としない。取得範囲・件数・実行回数に問題がある、または描画が状態変更を起こす具体的な証拠を示す。表示の副作用を「GETだから安全」「cacheで回数が減る」で正当化しない。

**検証**: 関連を含む複数件で表示とqueryの増え方を確認する。再描画時にもDB状態や入力objectが意図せず変わらず、外部副作用が起きないことを確認する。cache hitだけでなくmissの経路を必要に応じて確認する。

## 機械と判断の分担

このGemのRuboCop pluginはERB/Haml/Slimを解析するtemplate linterではありません。Rubyのlint成功だけでviewを検査済みと扱わない。Gemに同梱したERB Lint設定を導入済みなら `check --views -- <実際のテストコマンド>` で実行する。設定は `.erb_lint.yml` と `.erb_linters/tsurakunai_partial_inputs.rb`、依存は `erb_lint ~> 0.9`。導入を依頼された場合や入力の不一致を確認した場合は `install-view-lint`、対応環境では `--strict-locals` を候補にできる。既存設定は上書きせず必要な項目をマージする。HTML ERB以外は既存のtemplate linterがあれば実行し、入力契約・呼び出し元・helper内部・失敗時の描画はスキルと実際の描画テストで確認します。同梱のTsurakunaiPartialInputsはpartialのRuby tokenだけを検査する。通常のviewと文字列・コメントは許容し、動的参照やhelper内部を検査済みと扱わない。

## 仕様を確認する資料

- [Rails Action View: locals・collection・strict locals](https://guides.rubyonrails.org/action_view_overview.html)
- [Rails layouts and rendering: action・layout・partial](https://guides.rubyonrails.org/layouts_and_rendering.html)
