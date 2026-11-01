# netomox gem: FW policy rule の application / source_address / destination_address 配列対応 plan

状態: **netomox 側は実装済み (ブランチ v0.15-dev、未コミット)。決定: gem 更新する / 空文字は [] / 0.15.0 / DSL も Array 化**
関連: [fw_policy_application_list.md](fw_policy_application_list.md) (Step 0 / Step 3 の詳細)

## Step 0 の結果

netomox 0.14.1 (インストール済み gem、`netomox-exp/Gemfile.lock` と同じ版) に対し、配列値を渡して実行確認した。

```ruby
d = {'name'=>'r','action'=>'permit','application'=>['a','b'],'source_address'=>['any'],'destination_address'=>['any']}
Netomox::Topology::MddoL3FirewallPolicyRule.new(d, 'rules')
```

| 項目 | 結果 |
|---|---|
| 値の保持 (`#application` 等) | 配列のまま保持される |
| `#to_data` (RFC8345 出力) | 配列のまま出力される |
| DSL `MddoL3FirewallPolicyRule#topo_data` | 配列のまま出力される |
| ログ | **`ERROR -- netomox: Attribute type mismatch: key=application, default=``(String), value=`["a", "b"]`(Array)` が 3 項目分出る** |

原因: `topology/attr_base.rb` の `members_value_type_check` が、`ATTR_DEFS` の `default` (`''`) のクラスと値のクラスを比較し、
String/Integer 同士以外の不一致を `Netomox.logger.error` に出す。値は破棄されず、そのまま代入される。

## 結論: netomox の更新は「機能上は必須ではないが、行うべき」

- 配列を通すだけなら動作する (保持・出力とも問題なし)。
- ただし、このまま運用すると **ポリシ 1 ルールごとに ERROR ログが 3 行** 出る (topology のロード毎)。
  エラー扱いのログが常時出ると本物のエラーを見逃すため、`default` を `[]` に直して型を正すのが妥当。
- 型の canonical 定義 (`docs/firewall_node_attributes.md`) を配列にするなら、gem の YARD / DSL の型記述も揃えるべき。
- 本調査では、netomox 内に application / source_address / destination_address (FW rule) を参照する他のコード (diff、to_s 等) は見つからなかった
  (tp_attr の `mddo_fhrp.rb` の `source_address` は別物で対象外)。

(これは netomox-exp / model-conductor 側の修正が不要という意味ではない。model-conductor `firewall_policy_patcher.rb` は属性を丸ごとコピーするだけなので修正不要の見込みだが、gem 更新後に結合確認する。)

## 変更内容 (リポジトリ: https://github.com/ool-mddo/netomox 、gem 内パスは `lib/netomox/` 起点)

### 1. `topology/node_attr/mddo_l3_firewall_policy.rb` — `MddoL3FirewallPolicyRule`

- YARD: `application` / `source_address` / `destination_address` の `@return [String]` を `@return [Array<String>]` に変更。
- `ATTR_DEFS` を次のように変更:

```ruby
ATTR_DEFS = [
  { int: :name, ext: 'name', default: '' },
  { int: :action, ext: 'action', default: '' },
  { int: :application, ext: 'application', default: [], convert: ->(v) { Array(v) } },
  { int: :source_address, ext: 'source_address', default: [], convert: ->(v) { Array(v) } },
  { int: :destination_address, ext: 'destination_address', default: [], convert: ->(v) { Array(v) } }
].freeze
```

- `convert: ->(v) { Array(v) }` は旧形式 (String のまま保存された既存 topology JSON) を読んだ際に `['any']` に正規化するための互換措置。
  `convert` は `members_value_type_check` より前に適用されるため、旧データでもエラーログは出ない。
  - 旧データの `application: ''` (空文字) は `['']` になる点に注意。気になる場合は `v.to_s.empty? ? [] : Array(v)` のようにする (要判断)。
  - 互換が不要なら `convert` は付けず `default: []` のみでもよい (その場合、旧 String データはエラーログ付きでそのまま String で通る)。

### 2. `dsl/node_attr/mddo_l3_firewall_policy.rb` — DSL `MddoL3FirewallPolicyRule`

- YARD の型と `@param` を `Array<String>` に変更。
- `initialize` の既定値を `application: [], source_address: [], destination_address: []` に変更。
- `topo_data` は変更不要 (値をそのまま出力)。DSL 利用側が String を渡した場合に備えて `Array(application)` で包むかは要判断 (推奨: 包む)。

### 3. テスト / ドキュメント / バージョン

- netomox の spec (`spec/` ディレクトリは配布 gem には含まれていない。リポジトリ側を確認してから) に、配列値・旧 String 値・未指定の 3 ケースを追加:
  - 配列入力で `ERROR` ログが出ないこと、`to_data` が配列で往復できること。
  - String 入力が `[value]` に正規化されること (convert を採用する場合)。
  - キー未指定で `[]` になること。
- `docs/` 内に FW node attribute の記述があれば更新 (未確認)。
- バージョンは `0.14.1` → `0.15.0` を提案 (属性の型が変わる互換性影響のある変更のため minor を上げる)。要判断。
- 公開手順: playground `docs/design_notes/development.md` の「netomox (gem) の修正を伴う開発」に従い、
  ローカル netomox を `docker-compose.override.yaml` で netomox-exp / model-conductor に bind mount して先に動作確認し、その後リリースする
  (リリースは `release-submodule` 系のフロー。netomox は playground のサブモジュールではない点に注意)。
- 公開後、netomox-exp の `Gemfile` / `Gemfile.lock` (`netomox (>= 0.14.1)` を新版へ) と model-conductor 側の gem 依存も更新が必要。

## 実施順序への影響

親 plan の Step 順は次の通り調整する。

1. **netomox gem の修正を先に行う** (ローカル bind mount で検証可能。公開は後でもよい)。
2. firewall-policy-parser の TTP / 正規化 (Step 1) — gem に依存しないので並行可能。
3. docs 更新 (Step 2)、j2 更新 (Step 4)。
4. gem 公開 → netomox-exp / model-conductor の依存更新 → 結合確認 (Step 6)。

gem を公開せずにローカル bind mount のみでデモ検証し、本番反映は通常リリースに合流させる運用も可能。

## 判断をお願いしたい点

1. gem の更新を行うか (推奨: 行う。理由は ERROR ログ回避と型の一貫性)。
2. 旧 String データへの互換 (`convert: Array(v)`) を入れるか (推奨: 入れる。空文字の扱いは `[]` にする)。
3. バージョンを 0.15.0 (minor) にしてよいか。
4. DSL 側で String 入力を `Array()` で包むか (推奨: 包む)。
