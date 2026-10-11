# FHRP (VRRP/HSRP) TP アトリビュート JSON スキーマ

複数リポジトリをまたがる **正規定義 (canonical definition)** として管理する。
いずれかのリポジトリでスキーマを変更する場合は、このファイルも合わせて更新し、
関係するすべてのリポジトリで整合性を確認すること。

FHRP (First Hop Redundancy Protocol) = VRRP / HSRP。インタフェースに設定されたグループ情報を、
layer3 の term-point (TP) のアトリビュート `fhrp` として持たせる。

作業メモ (計画・調査) は [docs/work/plans/fhrp_termination_point_attributes.md](work/plans/fhrp_termination_point_attributes.md) を参照。

---

## データフロー

```
configs/<network>/<snapshot>/configs/*.config   (VRRP/HSRP 設定)
  │
  ▼ batfish-wrapper: POST /queries/<nw>/<ss>  (Batfish の vrrpProperties / hsrpProperties)
queries/<nw>/<ss>/vrrp_props.csv, hsrp_props.csv
  │
  ▼ netomox-exp: POST /topologies/<nw>/<ss>/topology  (TopologyBuilder: L3DataBuilder)
topologies/<nw>/<ss>/topology.json   ← layer3 TP の mddo-topology:l3-termination-point-attributes.fhrp
  │
  ├─ netomox-exp: namespace 変換 (original_asis → emulated_asis)        … fhrp を保持 (TP 名は変換される)
  ├─ model-conductor: conduit topology 生成 (original_asis_conduit*)    … 冗長を維持できるか否かで扱いが変わる (後述)
  ├─ model-conductor: splice 等のトポロジ操作                           … netomox 経由で保持
  └─ netoviz: マウスオーバー (tooltip) に表示
```

fhrp から VRRP/HSRP の config を生成する処理は未実装 (次フェーズ)。

---

## スキーマ定義

### 1. 入力: Batfish クエリ結果 (`queries/<nw>/<ss>/vrrp_props.csv`, `hsrp_props.csv`)

`vrrp_props` (Batfish `vrrpProperties`) と `hsrp_props` (`hsrpProperties`) は同一スキーマ。1 行が「インタフェース × グループ」。

| 列 | 例 | 説明 |
|---|---|---|
| `Interface` | `site-b-cr-1[ge-0/0/2.0]` | `node[interface]` 形式 |
| `Group_Id` | `1` | グループ ID |
| `Virtual_Addresses` | `['192.168.101.1']` | 仮想 IP アドレスの配列 (文字列表現) |
| `Source_Address` | `192.168.101.2/24` | インタフェース自身の IP アドレス/プレフィックス長 |
| `Priority` | `150` | 優先度 |
| `Preempt` | `True` | プリエンプト |
| `Active` | `True` | グループが有効か |

HSRP の設定が無いネットワークでは `hsrp_props.csv` はヘッダのみ。

### 2. topology.json 内の配置 (RFC8345 形式)

layer3 ネットワークの TP アトリビュート (`mddo-topology:l3-termination-point-attributes`) に `fhrp` (配列) を持つ:

```json
{
  "tp-id": "ge-0/0/2.0",
  "mddo-topology:l3-termination-point-attributes": {
    "description": "to_site-b-seg1",
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
}
```

---

## フィールド説明

| フィールド | 型 | CSV の列 | 説明 |
|---|---|---|---|
| `fhrp` | Array | - | FHRP グループのリスト。**FHRP を持たない TP には `fhrp` キー自体を出力しない** (既存の topology.json との差分を出さない) |
| `fhrp[].protocol` | String | (CSV ファイル名) | `'vrrp'` または `'hsrp'`。`vrrp_props.csv` / `hsrp_props.csv` のどちらから来たか |
| `fhrp[].group-id` | Integer | `Group_Id` | グループ ID。文字列で来ても整数に変換する |
| `fhrp[].virtual-address` | Array[String] | `Virtual_Addresses` | 仮想 IP アドレス |
| `fhrp[].priority` | Integer | `Priority` | 優先度。文字列で来ても整数に変換する |
| `fhrp[].preempt` | Boolean | `Preempt` | プリエンプトの有無 |
| `fhrp[].source-address` | String | `Source_Address` | グループを持つインタフェースの IP アドレス/プレフィックス長 (TP の `ip-address` のうちどれに属するかを示す) |
| `fhrp[].active` | Boolean | `Active` | グループが有効か |

- 1 つの TP 内で `(protocol, group-id)` は一意 (VRRP と HSRP の併存は配列の別要素)。一意性の検証は行っていない。
- 配列の並びは `(protocol, group-id)` の昇順 (Batfish の行順に依存しない)。
- VRRP と HSRP でパラメータに差が無いため、キーを分けず `fhrp` に統合し、`protocol` で区別する。

---

## キー命名規則

FHRP のキーは layer3 TP アトリビュートの既存キー (`ip-address`, `flag`) に合わせて **kebab-case** (ハイフン区切り)。

- FW ノードアトリビュート ([firewall_node_attributes.md](firewall_node_attributes.md)) は snake_case + 複数形で、規約が異なる。混同しないこと。
- netomox gem 内部 (PseudoDSL / DSL) では、配列の `virtual-address` は `virtual_addresses` に変換される
  (`Netomox::PLURAL_ATTR_KEY_TABLE`)。`fhrp` 自体は複数形に変換しない。
- `ATTR_DEFS[ext:]` の値は JSON キー名と**完全一致**させる (不一致だと `convert_namespace` で属性が消える)。

---

## conduit topology での扱い (model-conductor)

conduit topology (`original_asis_conduit*`) は blueprint に基づいてノードを抽象化する。
**目的は、エッジセグメント (エンドポイントがいるセグメント) のエンドポイントのデフォルトゲートウェイ設定が変わらないこと。**

- **Firewall グループ** (top-level `flag` に `"firewall"`): 全 TP を属性ごと保持 (`fhrp` も保持)。
- **Router グループ** (blueprint で 1 つのノードに集約):
  - 通常は「外部セグメント (他グループとの間のセグメント) に接続する TP」だけを `eth1, eth2, ...` として残す。
  - 例外: `fhrp` を持つ **unlinked TP (セグメントに接続していない TP = エッジ)** は、外部 TP の連番に続けて `ethN+1...` として残す。
    その扱いは「冗長を維持できるか」で決まる。
    - **冗長を維持できる** (同じ FHRP グループ `(protocol, group-id, virtual-address)` のメンバーが、blueprint に含まれるノードの範囲で
      2 つ以上の別の conduit ノードにいる): `ip-address` と `fhrp` を元の TP のまま引き継ぐ。
    - **冗長を維持できない** (1 つの conduit ノードに畳まれた / パートナーが blueprint に無い): `fhrp` は付けず、
      `ip-address` を **virtual-address + source-address のプレフィックス長** (例: `192.168.100.1/24`) にする。
    - 1 conduit ノード・1 FHRP グループにつき TP は 1 つ。代表は Master/Active に選ばれるメンバー
      (**priority 最大、同値なら source-address の数値が最大**。VRRP の 255 (address owner) が最優先、0 が最後。VRRP/HSRP 共通)。
  - 外部 TP が `fhrp` を持つ場合: IP は変えず、冗長を維持できるときだけ `fhrp` を引き継ぐ。
  - `fhrp` を持たない unlinked TP は従来どおり残らない。
- 現行の blueprint (`original_asis_blueprint1` / `blueprint2`) は cr ノード (VRRP を持つ) を含まないため、conduit に `fhrp` は現れない。

---

## netoviz での表示

layer3 TP のマウスオーバー (tooltip) に `FHRP:` の項目を表示する (1 グループ 1 行)。`fhrp` が無い TP の tooltip は変わらない。

```
FHRP:
  - VRRP group 1: Virtual Address: 192.168.101.1, Priority: 150, Preempt: true, Source Address: 192.168.101.2/24, Active: true
```

スナップショット差分 (diff) 表示では、値の変更・グループの追加/削除・`fhrp` 全体の追加/削除を既存の色分けで示す。

---

## クロスリポジトリ整合性制約

**重要**: 以下のリポジトリが同じスキーマを参照している。いずれかを変更する際は全リポジトリの整合性を確認すること。

| リポジトリ | 役割 | 参照箇所 |
|---|---|---|
| `repos/batfish-wrapper` | **データの生成元** (CSV) | `src/bfwrapper/bf_query_thrower.py` (`BF_QUERY_DICT` の `vrrp_props`, `hsrp_props`) |
| `netomox` | **スキーマのパーサー / ジェネレータ** (Topology / DSL) | `lib/netomox/{topology,dsl}/tp_attr/mddo_fhrp.rb` (`MddoFhrp`)、`mddo.rb` (`MddoL3TPAttribute#fhrp`)、`lib/netomox/convert_attr.rb` (`virtual_address` → `virtual_addresses`) |
| `repos/netomox-exp` | CSV → topology の変換、保存・名前空間変換 | `lib/topology_builder/csv_mapper/fhrp_props_table.rb`、`lib/topology_builder/l3_data_builder.rb` (`l3_tp_attribute`) |
| `repos/model-conductor` | conduit topology 生成 | `lib/generate_conduit_topology/fhrp_gateway_resolver.rb`、`layer3_conduit_builder.rb` (`build_router_conduit_tp`) |
| `repos/netoviz` | tooltip 表示 | `server/graph/rfc-model/tp-attr/mddo-fhrp.js` (`MddoFhrp`)、`mddo.js` (`MddoL3TermPointAttribute#fhrp`)、`server/graph/common/diff-state.js` (`diffDataForArrayElement`) |

### 最も壊れやすいポイント

1. **`netomox` の `ATTR_DEFS[ext:]` と JSON キー名の不一致**: `fhrp` / `group-id` / `virtual-address` / `source-address` 等が
   netomox-exp の出力と一致しないと、`convert_namespace` 等で属性が消える。キー名変更時は全リポジトリを同時に更新すること。
2. **netoviz のサブ属性クラスは kebab-case / camelCase の両方を受け付ける**: サーバーで生成した属性は JSON として図データに載り、
   ブラウザで再構築されるため (入れ子の値は camelCase のプロパティ名になっている)。
3. **layer3 TP の属性を新しく作り直す処理** (conduit の `build_router_conduit_tp` など) は、`fhrp` を明示的に引き継がないと落ちる。
   TP 属性を追加する場合は、netomox-exp / model-conductor 内で TP 属性を新規構築している箇所を確認すること。
4. **古い queries との互換**: `vrrp_props.csv` / `hsrp_props.csv` が無い queries (本機能より前に生成したもの) でも、
   netomox-exp は空として扱い、`fhrp` なしのトポロジを生成する。

### バージョン対応

| コンポーネント | `fhrp` に対応するバージョン |
|---|---|
| netomox | v0.14.0 以降 |
| netomox-exp | v1.20.0 以降 (`netomox >= 0.14.0`) |
| model-conductor | v1.18.0 以降 (`netomox >= 0.14.0`) |
| batfish-wrapper | v1.2.0 以降 |
| netoviz | v0.10.0 以降 |

### 現時点の制約 (未対応)

- `fhrp` から VRRP/HSRP の config を生成する処理 (エミュレーション環境へ反映する処理) は未実装。
- mddo-mregnw (Arista の Vlan インタフェース、IPv4/IPv6 混在の VIP) は対象外。Batfish の `vrrpProperties` が IPv6 の VIP を返すかは未確認。
- `(protocol, group-id)` の一意性、`protocol` の値 (`vrrp` / `hsrp`) の検証は行っていない。
- conduit で、1 つの TP が「冗長を維持できるグループ」と「維持できないグループ」の両方を持つ場合は、維持できるグループの `fhrp` と元の IP を残し、
  維持できないグループは落とす (警告ログ)。現行データには該当なし。
