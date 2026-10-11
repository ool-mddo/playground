# Plan: VRRP/HSRP 情報を layer3 termination-point attribute (`fhrp`) として扱う

(状態: Step 1 (batfish-wrapper)、Phase A (netomox)、Phase B (ローカル bind mount での取り込み)、Phase C (netomox-exp)、Phase D (名前空間変換での保持の確認)、Phase E (model-conductor の conduit 生成)、Phase F (netoviz の tooltip 表示)、Phase G (結合確認・canonical definition・netomox 公開・イメージ更新) は実施済み)

## 目的

configs 内の VRRP/HSRP 設定を Batfish で解析し、トポロジモデルの
`mddo-topology:l3-termination-point-attributes` に FHRP (First Hop Redundancy Protocol) 情報として持たせる。
HSRP は現状の configs に実データがなく直接は使わないが、スキーマ上は VRRP と同様に扱えるようにしておく。

## Step 1: batfish-wrapper にクエリ追加 (実装済み)

[repos/batfish-wrapper/src/bfwrapper/bf_query_thrower.py](../../../repos/batfish-wrapper/src/bfwrapper/bf_query_thrower.py)
の `BF_QUERY_DICT` に追加:

```python
"vrrp_props": lambda bf: bf.q.vrrpProperties(),
"hsrp_props": lambda bf: bf.q.hsrpProperties(),
```

- 結果は `queries/<nw>/<ss>/vrrp_props.csv`, `hsrp_props.csv` に保存される (CSV は 2 本、`queries/` はコミット対象外)。
- `POST /queries/<nw>[/<ss>]` と `cli_exec_queries.py` の `--query` 指定は辞書参照のため変更不要。
- 動作確認済み: `21_generate_conduit.sh` 実行後、`queries/mddo-fw/original_asis/` に両 CSV が生成される。
  - `vrrp_props.csv`: 12 行 (mddo-fw)。mddo-mregnw でも 16 行取得できる。
  - `hsrp_props.csv`: ヘッダのみ (configs に HSRP 設定なし)。実データでの検証はしない。

### 調査結果 (Batfish が返す情報)

- `interfaceProperties` の `VRRP_Groups` / `HSRP_Groups` は group id のみで不十分。`namedStructures` にも定義は含まれない。
- 専用 question `vrrpProperties` / `hsrpProperties` は共通の 7 列を返す:
  `Interface, Group_Id, Virtual_Addresses, Source_Address, Priority, Preempt, Active`
  - `Interface` は `node[ifname]` 形式 (既存 CSV と同じ)。
  - `Virtual_Addresses` は配列の文字列表現 (`['192.168.101.1']`)。
  - `Group_Id` / `Priority` は CSV 上は数値文字列。

## Step 2: データモデル

`mddo-topology:l3-termination-point-attributes` に `fhrp` キーを追加する。
VRRP と HSRP でパラメータに差がないため、protocol を要素内のフィールドとして統合する。

```json
"mddo-topology:l3-termination-point-attributes": {
  "description": "...",
  "ip-address": ["192.168.101.2/24"],
  "flag": [],
  "fhrp": [
    {
      "protocol": "vrrp",
      "group-id": 1,
      "virtual-address": ["192.168.101.1"],
      "priority": 150,
      "preempt": true,
      "source-address": "192.168.101.2/24",
      "active": true
    }
  ]
}
```

| key | 型 | 元の CSV 列 | 備考 |
|---|---|---|---|
| `protocol` | string (`"vrrp"` / `"hsrp"`) | 由来した CSV | マージ時に付与 |
| `group-id` | integer | `Group_Id` | 文字列 → 整数 |
| `virtual-address` | array of string | `Virtual_Addresses` | 文字列表現 → 配列。IPv4/IPv6 混在可 |
| `priority` | integer | `Priority` | |
| `preempt` | boolean | `Preempt` | |
| `source-address` | string | `Source_Address` | 任意。TP の `ip-address` のどれに属するグループかを示す |
| `active` | boolean | `Active` | |

方針:

- 1 TP 内で `(protocol, group-id)` が一意。VRRP と HSRP の併存も配列の別要素で表現できる。
- FHRP を持たない TP には `fhrp` キー自体を付けない (既存 topology.json との差分を出さない)。
- キー名は kebab-case (既存の `ip-address` に合わせる)。
- HSRP 固有パラメータ (version 等) が必要になったら、該当要素にだけ任意キーとして追加する。

## Step 3: マージ処理 (未着手・要調査)

CSV (`vrrp_props.csv` / `hsrp_props.csv`) → layer3 TP の `fhrp` 配列へ変換してマージする。
`protocol` 付与と型変換 (整数・bool・配列) をここで行う。

要調査 (実装前に決める):

- **マージ担当:** batfish-wrapper の `model_merge` (ospf 用 attribute を Jinja テンプレートでマージしている:
  [merge.py](../../../repos/batfish-wrapper/src/model_merge/merge.py)) に入れるか、
  netomox-exp 側で `queries` の CSV を読んで layer3 TP に付けるか。現状のパイプラインでは netomox-exp 側が自然に見えるが未確認。
- **付与対象:** layer3 の TP のみでよいか。VLAN インタフェース (mregnw の Arista `Vlan10` 等) が layer2 側にも現れる場合の扱い。
- **Interface 名の対応:** `node[ifname]` と TP-id (`ge-0/0/2.0` 等、node 名の大文字小文字含む) の対応付け。
- **IPv4/IPv6 混在:** mregnw の `vrrp_props.csv` で `Virtual_Addresses` に v4/v6 が混在するか (Arista は `vrrp 1 ipv4` / `vrrp 1 ipv6` を同一 group に設定)。
- **`source-address` の要否:** 冗長なら削る。

## Step 4: 周辺の対応 (未着手)

- **netomox gem:** `l3-termination-point-attributes` の定義に `fhrp` を追加する (未知キーを落とす場合は必須)。
- **ns_convert / conduit:** `original_asis` → `emulated_asis` / `original_asis_conduit*` で TP 名が変換されても `fhrp` 属性が保持されるか確認する。
- **netoviz:** tooltip 等での表示は今回は対象外 (必要になったら別途)。
- **ドキュメント:** FW 属性 ([firewall_node_attributes.md](../../firewall_node_attributes.md)) と同様に、
  スキーマの canonical definition を `docs/` に追加する。
- **コミット:** `repos/batfish-wrapper` は別リポジトリ。submodule 側でコミットしてから playground 側の参照を更新する。

## 検証方法

1. `cd demo/candidate_model_ops && source demo_vars && ./21_generate_conduit.sh` を実行する。
2. `queries/mddo-fw/original_asis/vrrp_props.csv` (12 行) と `hsrp_props.csv` (ヘッダのみ) を確認する。(Step 1 で確認済み)
3. (Step 3 以降) 生成された `topologies/mddo-fw/original_asis/topology.json` の layer3 TP に `fhrp` が付くことを確認する。
   例: `site-b-cr-1` の `ge-0/0/2.0` に `protocol: vrrp, group-id: 1, virtual-address: ["192.168.101.1"], priority: 150`。
4. `emulated_asis` / conduit snapshot でも `fhrp` が保持されることを確認する。

---

# 実装計画 (モジュール単位の段階実装)

## ゴールとスコープ

- **今回のゴール:** configs → `emulated_asis` / `emulated_asis_conduit*` トポロジの layer3 TP に `fhrp` 属性が載り、
  生成・変換・保存の各段階で失われないところまで。
- **スコープ外:** `fhrp` 属性から VRRP/HSRP の config を生成する処理 (最終ゴールだが次フェーズ)。
- 各 Phase は単独でテスト・動作確認ができる単位に分け、前の Phase の確認が済んでから次に進む。
- 対象リポジトリは Phase ごとに異なる (netomox は playground の外: `/home/hagiwara/ool-mddo/netomox`)。

## 調査で分かった前提

- netomox の layer3 TP 属性は `MddoL3TPAttribute` (`ATTR_DEFS`: `description`, `ip-address`, `flag`) 。
  Topology 層 (`lib/netomox/topology/tp_attr/mddo.rb`) と DSL 層 (`lib/netomox/dsl/tp_attr/mddo.rb`) の**両方**に実装する規約
  (netomox/CLAUDE.md)。入れ子の配列要素は `SubAttributeBase` 継承クラスにする
  (参考: `MddoOspfNeighbor` = `tp_attr/mddo_ospf_neighbor.rb`、Topology/DSL 両方にある)。
- `ATTR_DEFS` の `ext:` は JSON キー名と完全一致が必須。不一致だと `convert_namespace` で属性が消える (netomox/CLAUDE.md)。
- `lib/netomox/convert_attr.rb` の `PLURAL_ATTR_KEY_TABLE` は、配列値のキーの ext → 内部名変換表。
  `virtual-address` (配列) 等は登録しないと DSL 側の名前が揃わない可能性がある。
- netomox のバージョンは現在 0.13.0 (`lib/netomox/version.rb`)。netomox-exp / model-conductor の Gemfile は
  `gem 'netomox', '>= 0.13.0'` (GitHub Packages)。コンテナでは bind mount されるのは各リポジトリの `lib` 等のみで、
  gem 自体はイメージ内にインストール済み。netomox の変更を試すには gem の差し替え手順が必要。
- netomox-exp:
  - queries CSV → layer3 は [l3_data_builder.rb](../../../repos/netomox-exp/lib/topology_builder/l3_data_builder.rb) の
    `add_l3_tp` が TP 属性 (`ip_addrs`, `description`) を設定する。
  - CSV の読み込みは `lib/topology_builder/csv_mapper/*_table.rb` (`TableBase` / `TableRecordBase`)。
    `Interface` 列 (`node[ifname]`) は `EdgeBase` で node/interface に分解、bool は `true_string?`、
    配列文字列は `parse_array_string` で変換できる。VRRP の `Interface` は TP-id (`ge-0/0/2.0`) と同形式。
  - namespace 変換は `lib/convert_namespace/namespace_converter.rb` が netomox gem のオブジェクトを走査する。
    `fhrp` 内に node 名・TP 名は含まれないので名前変換は不要。gem が属性を保持すれば通る想定。
- model-conductor:
  - [layer3_conduit_builder.rb:218](../../../repos/model-conductor/lib/generate_conduit_topology/layer3_conduit_builder.rb)
    `build_router_conduit_tp` が、conduit TP を `{'ip-address'=>..., 'flag'=>[]}` だけで**新規構築**している。
    ここは `fhrp` が落ちる箇所の筆頭 (一方、同ファイル L187 は `tp[L3_TP_ATTR].dup` で丸ごと保持)。
  - `router_node_attr_merger.rb` (L56 で `ip-address` を集約) と `splice_topology/topology_splicer.rb` も TP 属性を扱うため、
    取りこぼしがないか確認が必要。

## Phase 一覧

| Phase | 対象 | 内容 | 確認方法 |
|---|---|---|---|
| A | netomox | `fhrp` を扱えるようにする (Topology/DSL) | netomox の rspec |
| B | netomox-exp / model-conductor | 新 netomox を gem として組み込む | 両サービスの起動・既存 spec |
| C | netomox-exp | queries から layer3 TP に `fhrp` を付与 | rspec + `original_asis` の topology.json |
| D | netomox-exp | ns_convert 等で `fhrp` を保持 | `emulated_asis` の topology.json |
| E | model-conductor | splice / conduit 生成で `fhrp` を保持 | `original_asis` / `*_conduit*` の topology.json |
| F | netoviz | layer3 TP のマウスオーバー (tooltip) に `fhrp` を表示 | netoviz の vitest + ブラウザでの表示確認 |
| G | playground | 結合確認とドキュメント | `21_generate_conduit.sh` 一式 |

### Phase A: netomox で fhrp attribute を扱えるようにする

対象: `/home/hagiwara/ool-mddo/netomox` (playground 外・別リポジトリ)。

1. **Topology 層 (サブ属性)**: `lib/netomox/topology/tp_attr/mddo_fhrp.rb` を新規作成 (`SubAttributeBase` 継承)。

   | int | ext | default |
   |---|---|---|
   | `protocol` | `protocol` | `''` |
   | `group_id` | `group-id` | `-1` |
   | `virtual_addresses` | `virtual-address` | `[]` |
   | `priority` | `priority` | `0` (要検討) |
   | `preempt` | `preempt` | `false` |
   | `source_address` | `source-address` | `''` |
   | `active` | `active` | `false` |

2. **Topology 層 (L3 TP)**: `MddoL3TPAttribute` の `ATTR_DEFS` に `{ int: :fhrp, ext: 'fhrp', default: [] }` を追加し、
   `initialize` で `MddoFhrp` の配列に変換 (`MddoOspfAreaTPAttribute#convert_neighbors` と同じ要領)。
   既存の `description` / `ip_addrs` / `flags` の挙動は変えない。
3. **DSL 層**: `lib/netomox/dsl/tp_attr/mddo_fhrp.rb` を新規作成 (keyword 引数 + `topo_data` / `empty?`)。
   `MddoL3TPAttribute` (DSL) に `fhrp: []` 引数を追加し、`topo_data` に `'fhrp'` を出力。
   **`fhrp` が空のときはキー自体を出力しない** (既存 topology.json に差分を出さない)。`empty?` も `fhrp` を考慮。
4. **`convert_attr.rb`**: `PLURAL_ATTR_KEY_TABLE` に必要な項目を追加
   (`virtual_address: :virtual_addresses` 等。`fhrp` 自体は配列でも同名のまま扱うか、`fhrp: :fhrps` にするか要決定)。
   `convert_attr_topo2dsl` 経由で Topology → DSL の往復が壊れないことを確認する。
5. **バージョン**: `lib/netomox/version.rb` を 0.14.0 に上げる (Phase B で使用)。
6. **テスト** (機能ごとに専用ファイルを作る方針):
   - `spec/topology/tp_attr_mddo_fhrp_spec.rb`: JSON → Topology オブジェクト、`fhrp` 無しの TP、複数要素 (VRRP+HSRP 併存)、
     `to_data` 往復で `fhrp` が保持されること。
   - `spec/dsl/tp_attr_mddo_fhrp_spec.rb`: DSL → `topo_data`、空のとき `fhrp` キーが出ないこと。
   - `spec/topology/convert_attr_fhrp_spec.rb`: `convert_attr_topo2dsl` の往復。
7. **確認**: `bundle exec rspec` 全体が通ること。`bundle exec rubocop`。

Phase A の完了条件: netomox 単体で `fhrp` 付き topology.json の読み書き (Topology / DSL / 変換) が通ること。

### Phase B: netomox gem を netomox-exp / model-conductor に組み込む

1. 取り込み方式の決定 (要確認):
   - (a) 0.14.0 を GitHub Packages に公開し、Gemfile を `gem 'netomox', '>= 0.14.0'` + `bundle update netomox`
     (`Gemfile.lock` 更新、イメージ再ビルド)。公開は外部サービスへの発行なので、実行前に確認を取る。
   - (b) 公開前の開発用に、ローカルでビルドした `.gem` を `gem install` する、または Gemfile を一時的に
     `path:` / ローカル gem 指定にしてコンテナで検証する。
2. netomox-exp / model-conductor の `Gemfile` / `Gemfile.lock` を更新。
3. 両サービスのコンテナで新 netomox が読み込まれること (`bundle exec ruby -e 'require "netomox"; puts Netomox::VERSION'`) を確認。
4. 既存の spec (`bundle exec rspec`) と、`21_generate_conduit.sh` を実行して**従来どおり動く**こと (回帰なし) を確認。
   この時点では `fhrp` はまだ出力されない。

### Phase C: netomox-exp: queries から layer3 TP に fhrp を付与

(実装済み。詳細・結果は `repos/netomox-exp/docs/plans/fhrp_termination_point_attribute.md`。
決定: CSV が無ければ空扱い、TP は `(node, interface)` で引く、`(protocol, group_id)` でソート。
`emulated_asis` でも `fhrp` が保持されることを確認済み (Phase D の先取り)。`*_conduit*` は未対応 (Phase E))

1. **CSV マッパ追加**: `lib/topology_builder/csv_mapper/vrrp_props_table.rb` / `hsrp_props_table.rb`
   (または共通クラスに `protocol` を渡す形。両 CSV は同一スキーマなので共通化を推奨)。
   - `Interface` → node / interface (`EdgeBase`)。`Group_Id` / `Priority` → Integer。
   - `Virtual_Addresses` → `parse_array_string` で配列、`Preempt` / `Active` → `true_string?`。
   - `find_records_by_node_intf(node, intf)` のように (node, interface) で複数グループを引ける検索メソッド。
   - **CSV が存在しない (古い queries) 場合の挙動を決める**: 空として扱う (後方互換)。
2. **L3 データビルダ**: `L3DataBuilder#add_l3_tp` (または別メソッドを `make_networks` に追加) で、TP の
   `l3_tp.attribute` に `fhrp: [...]` を追加する。VRRP と HSRP の両方を `protocol` 付きで 1 つの配列にまとめる。
   - FHRP が無い TP には `fhrp` キーを付けない。
   - 論点: VRF 付き (`l3_node_name` が `node_vrf`) や Vlan インタフェース (mregnw) でも `rec.interface` と
     `fhrp` の Interface が一致するか。LAG 親経由 (`ip_rec_by_l2_node`) で別名のインタフェースになる場合の扱い。
   - 論点: `source-address` を残すか (複数 IP の TP でどれに属するかの確認に使える)。
3. **テスト**: `spec/topology_builder/` に専用 spec を追加。`spec/fixtures/queries/mddo-fw/original_asis/` に
   `vrrp_props.csv` (実データから抜粋) と `hsrp_props.csv` (ヘッダのみ) を追加。
   - CSV マッパの型変換、(node, intf) 検索、CSV 欠落時の挙動。
   - レイヤ3ビルダの出力に `fhrp` が付くこと、付かない TP にキーが出ないこと。
4. **動作確認**: `21_generate_conduit.sh` を実行し、`topologies/mddo-fw/original_asis/topology.json` の layer3 で
   - `site-b-cr-1` の `ge-0/0/2.0` に `fhrp: [{protocol: vrrp, group-id: 1, virtual-address: ["192.168.101.1"], priority: 150, ...}]`
   - FHRP の無い TP には `fhrp` が無いこと (差分が FHRP 追加分のみ)
   を `jq` で確認。(mddo-mregnw は対象外)

   (注: ライブ開発で `repos/netomox-exp/lib` は bind mount されるが、Phase B の gem 差し替えは別途必要)

### Phase D: netomox-exp: ns_convert 等で fhrp を取りこぼさない

(実施済み。lib の変更は不要で、spec 追加 5 件と README の注記のみ。詳細は `repos/netomox-exp/docs/plans/fhrp_termination_point_attribute.md`)

1. `original_asis` → `emulated_asis` の namespace 変換 (`NamespaceConverter` / `UpperLayer3Filter` 周辺) で、
   layer3 TP の `fhrp` が保持されることを確認 (Phase A で gem が保持できていれば変更不要の想定)。
2. netomox-exp 内で TP 属性を再構築している箇所を洗い出す (`grep` で `ip_addrs` / `l3-termination-point-attributes` を
   扱う箇所: `namespace_converter.rb`, `usecase_deliverer/*`, `static_verifier/layer3_verifier.rb` 等) 、
   TP 属性を新規 Hash で作り直していて `fhrp` が落ちる箇所があれば修正。
3. **テスト**: `spec/convert_namespace/` に `fhrp` 付き fixture を使った専用 spec (変換前後で `fhrp` が同一)。
4. **動作確認**: `emulated_asis/topology.json` の同じ TP に `fhrp` が残っていること。
   (`ns_convert_table` の保存仕様は変更しない)

### Phase E: model-conductor: splice / conduit 生成で fhrp を取りこぼさない

(実装済み。詳細・結果は `repos/model-conductor/docs/plans/fhrp_termination_point_attribute.md`)

- 調査: 属性を落とす箇所は `Layer3ConduitBuilder` (Router グループの conduit TP を `ip-address`/`flag` のみで新規構築) だけ。
  Firewall グループ・splice・ospf conduit・merger は影響なし。
  さらに、VRRP を持つ cr の TP (`ge-0/0/2.0`, `ge-0/0/3.0`) はセグメントに接続していない unlinked TP で、
  Router グループの「外部 TP のみ残す」ルールでは `fhrp` の引き継ぎだけでは足りないことが分かった。
- 決定した仕様 (エッジセグメントのエンドポイントのデフォルトゲートウェイを変えない):
  - 冗長を維持できる (同じ FHRP グループのメンバーが、blueprint に含まれる範囲で 2 つ以上の別 conduit ノードにいる):
    `fhrp` を残す (ip-address も元のまま)。
  - 維持できない (畳んだ / パートナーが blueprint に無い): `fhrp` は付けず、virtual-address を IP (source-address のプレフィックス長) にする。
  - 1 conduit ノード・1 FHRP グループにつき TP は 1 つ。代表は Master/Active に選ばれるメンバー
    (VRRP/HSRP 共通: priority 最大、同値なら source-address の数値が最大。VRRP の 255 が最優先・0 が最後)。
  - 外部 TP の `fhrp` は IP を変えず、冗長を維持できるときだけ引き継ぐ。Firewall グループは現行どおり属性ごと保持。
  - 現行の blueprint (cr を含まない) の出力は変わらない。cr を含む blueprint の作成は後回し。

### Phase F: netoviz: fhrp attribute の tooltip 表示

(実装済み。詳細・結果は `repos/netoviz/docs/plans/fhrp_termination_point_attribute.md`)

- `MddoFhrp` (`tp-attr/mddo-fhrp.js`) を新規作成し、`MddoL3TermPointAttribute` に `fhrp` を追加 (`FHRP:` の下に 1 グループ 1 行)。
  `fhrp` が無い TP のツールチップは従来と同一。diff 表示用に `DiffState#diffDataForArrayElement` を追加。
- npm test 142 passed (従来 109 + 33)、実環境の API と実ブラウザ (Playwright) で `site-b-cr-1` の `ge-0/0/2.0` のツールチップに `FHRP:` が出ることを確認。

### Phase G: 結合確認とドキュメント

#### 結合確認の結果 (2026-10-11。ローカルの netomox を bind mount した状態)

- 各リポジトリ (netomox `v0.14.0-dev` / netomox-exp `v1.20.0-dev` / model-conductor `v1.18.0-dev` / batfish-wrapper `v1.2.0-dev` / netoviz `v0.10.0-dev`)
  の自動テストと lint:
  - netomox: 332 examples, 0 failures、rubocop 違反なし
  - netomox-exp: 168 examples, 0 failures、rubocop 違反なし
  - model-conductor: 102 examples, 0 failures、rubocop 違反なし
  - netoviz: 142 tests passed、lint は既存の警告 1 件のみ
  - batfish-wrapper: 変更は 2 行 (クエリ追加) で、構文確認と実環境で確認 (自動テストなし)
- `21_generate_conduit.sh` (blueprint1) を通し実行: 正常終了。queries は Batfish から再生成され (`vrrp_props.csv` 12 行 / `hsrp_props.csv` ヘッダのみ)、
  `original_asis` / `emulated_asis` の layer3 に `fhrp` を持つ TP が 12 個、`*_conduit1/2` は 0 個 (現行 blueprint は cr を含まないため)。
  全 6 snapshot で、実行前 (Phase E 以降の状態) と topology.json が同一。blueprint2 でも Phase E の確認で同一。
- `22_up_conduit.sh -s emulated_asis -d` / `-s emulated_asis_conduit1 -d`: 正常終了。生成された `demo/candidate_model_ops/clab` の全ファイル (58 件) のハッシュが実行前と同一
  (`fhrp` の config 生成は次フェーズなので差分なしが期待どおり)。
- netomox-exp API: `emulated_asis` の `layer3/interfaces?node_name=site-a-cr-1` で `eth3.0` (元 `ge-0/0/2.0`) / `eth4.0` (元 `ge-0/0/3.0`) に `fhrp`、
  `config_params` は 200。VRRP/HSRP の CSV が無い古い queries (`mddo-ospf`) からのトポロジ生成も正常 (CSV 欠落は空扱いで info ログのみ、`fhrp` なし)。
- netoviz (実ブラウザ。Playwright + Chrome): `original_asis` の `site-b-cr-1[ge-0/0/2.0]`、`emulated_asis` の `site-b-cr-2[eth3.0]` の
  ツールチップに `FHRP: VRRP group 1: …` が表示され、`fhrp` が無い TP や conduit のツールチップは従来どおり。ブラウザのエラーなし。
- 未実施 (上記のローカル確認時点): 他のシナリオ (`00_run_phase.sh`、mddo-bgp 系 usecase) の通し実行、cr を含む blueprint での conduit の実環境確認 (blueprint 作成は後回し)、
  netoviz の diff 表示の実環境確認 (unit test のみ)。

1. `cd demo/candidate_model_ops && source demo_vars && ./21_generate_conduit.sh` を通しで実行し、
   - `original_asis`, `emulated_asis`, `original_asis_conduit*`, `emulated_asis_conduit*` の各 `topology.json`
   - netoviz の index / 表示に影響が出ていない (既存の動作が壊れていない。`fhrp` の tooltip 表示は Phase F)
   を確認。`22_up_conduit.sh -s emulated_asis -d` も回帰確認。
2. ドキュメント:
   - `fhrp` スキーマの canonical definition を `docs/` に追加 (`firewall_node_attributes.md` と同様の位置づけ)。
   - `docs/architecture.md` の関連記述、`CLAUDE.md` の必要箇所を更新。
   - netomox 側の `docs/` にも属性の説明を追記。
3. コミット順序 (複数リポジトリ): netomox → (gem 公開) → netomox-exp / model-conductor (Gemfile.lock 含む) →
   batfish-wrapper (Step 1) → netoviz → playground (submodule 参照更新 + docs)。

## 決定済み事項

- 属性クラス名は `MddoFhrp` (netomox の Topology/DSL 両層、netoviz のサブ属性クラスも同名の方針)。
- `source-address` は一旦残す。
- mddo-mregnw は今回は対象外 (Phase C の `vrrp_props.csv` 調査も含めて行わない)。
- netomox gem の取り込み方式 (Phase B) は Phase A 実装後に指示を受ける。それまで Phase B は着手しない。
- conduit TP の `fhrp` の扱い (Phase E) は、conduit でのトポロジ操作の内容に依存するため、Phase E の実装時に詳細を決める。
  それまでは「`build_router_conduit_tp` が `fhrp` を落とす」という事実の記録に留める。

## 未決事項

- `PLURAL_ATTR_KEY_TABLE` での `fhrp` の内部名 (`fhrp` のまま配列で扱うか、`fhrps` 等に変換するか)。Phase A で決める。

### mddo-mregnw について (対象外・参考情報)

決定: 今回は対象外。以下は将来対応する場合の参考として残す。

- `configs/mddo-mregnw` は複数リージョン (RegionA/B...) のマルチリージョン網のサンプルで、現在のターゲット (`mddo-fw`、Juniper SRX FW HA) とは別の網。
  CE ルータ (RegionA-CE01/02 等) 間で VRRP を使っている。`queries/mddo-mregnw/` は旧データで、`vrrp_props.csv` はまだ無い (Step 1 以前に生成されたため)。
- `mddo-fw` との違いで、`fhrp` のマッピングに影響しうる点:
  - インタフェース名: `mddo-fw` は Juniper の `ge-0/0/2.0` で TP-id と同形式。`mddo-mregnw` は Arista の `Vlan10` (SVI) や
    Juniper の `ae1.1110` (LAG サブインタフェース) があり、L3 TP の名前・親子関係の解決 (`ip_rec_by_l2_node`) が絡む。
  - IPv4/IPv6 の VIP: Arista 設定は `vrrp 1 ipv4 ...` と `vrrp 1 ipv6 ...` を同じ group に書いている。
    ただし先の確認では Batfish の `vrrpProperties` の `Virtual_Addresses` は IPv4 の 1 要素のみで、IPv6 の VIP が
    返ってきているかは未確認 (Batfish が IPv6 VRRP VIP を扱わない可能性がある)。扱いに差が出る場合は `fhrp` の仕様に影響する。
  - VRF: `Vlan110` 等は `vrf1` に属し、L3 ノード名が `node_vrf` になる (`l3_node_name`)。TP の探索は node 名ではなく
    元の node 名 + interface で引く必要がある。
- 現在のゴール (`refocus_topology` / `mddo-fw`) には不要なため対象外とする (調査・検証とも行わない)。

#### リリースと公開イメージでの確認 (2026-10-11)

- canonical definition: [docs/fhrp_termination_point_attributes.md](../../fhrp_termination_point_attributes.md) を追加
  (スキーマ・データフロー・conduit での扱い・netoviz 表示・クロスリポジトリ整合性・バージョン対応)。
  playground の `CLAUDE.md` / `docs/architecture.md`、netomox / netomox-exp / model-conductor の `CLAUDE.md` から参照。
- netomox: バージョンを 0.14.0 にして `v0.14.0-dev` を push (`3a03579`)。CI (Run test and lint / build and push rubygem package) 成功、gem が公開された。
- netomox-exp (`v1.20.0-dev`、`7bf3b39`) / model-conductor (`v1.18.0-dev`、`886473b`): Gemfile を `netomox >= 0.14.0` に更新して push。
  CI (netomox 0.14.0 を使った rubocop + rspec、イメージの build/push) 成功。イメージ: `ghcr.io/ool-mddo/netomox-exp:v1.20.0-dev`、
  `ghcr.io/ool-mddo/model-conductor:v1.18.0-dev`。
- playground: `.env` の `NETOMOX_EXP_IMAGE_TAG=v1.20.0-dev` / `MODEL_CONDUCTOR_IMAGE_TAG=v1.18.0-dev` に変更して `docker compose pull` + `up -d`
  (ローカル netomox の bind mount (`docker-compose.override.yaml`) は使わない)。コンテナ内の netomox は 0.14.0 (`MddoFhrp` あり)。
  `21_generate_conduit.sh` / `22_up_conduit.sh -s emulated_asis -d` / `-s emulated_asis_conduit1 -d` が正常終了し、結果 (topology.json、clab) はローカル確認時と同一。
  netoviz のツールチップ (`emulated_asis` の `site-b-cr-2[eth3.0]`) に `FHRP:` が表示される。
- batfish-wrapper (`v1.2.0-dev`、`6561077`) / netoviz (`v0.10.0-dev`、`cac200f`) も push し、CI 成功。イメージ: `ghcr.io/ool-mddo/batfish-wrapper:v1.2.0-dev`、
  `ghcr.io/ool-mddo/netoviz:v0.10.0-dev` (どちらもイメージ内に変更が入っていることを確認)。`.env` の `BATFISH_WRAPPER_IMAGE_TAG` / `NETOVIZ_IMAGE_TAG` をこれらに変更して
  pull + `up -d`、`21_generate_conduit.sh` / `22_up_conduit.sh -d` が正常終了し、結果 (queries、topology.json、clab) は以前と同一。netoviz のツールチップにも `FHRP:` が表示される。
- playground の `.env` は 4 つのイメージ (netomox-exp / model-conductor / batfish-wrapper / netoviz) の新しいタグを参照する。

