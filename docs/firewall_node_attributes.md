# FW ノードアトリビュート JSON スキーマ

複数リポジトリをまたがる **正規定義 (canonical definition)** として管理する。
いずれかのリポジトリでスキーマを変更する場合は、このファイルも合わせて更新し、
関係するすべてのリポジトリで整合性を確認すること。

---

## データフロー

```
firewall-policy-parser
  POST /fw_policy/<nw>/<ss>/parsed_result  → ttp_output/<nw>/<ss>/<node>.json (per-node)
  POST /fw_policy/<nw>/<ss>/topology       → model-conductor (集約 + 転送)
    → POST /conduct/<nw>/<ss>/topology/layer3/policies
      → netomox-exp: RFC8345 topology.json に FW アトリビュートをマージ・保存
        → netomox gem: topology.json をパース → MddoL3Firewall オブジェクトとして保持
```

---

## スキーマ定義

### 1. per-node JSON (`ttp_output/<network>/<snapshot>/<node>.json`)

firewall-policy-parser が各 FW ノードごとに生成する JSON:

```json
{
  "node": "site-a-fw-1",
  "pair": {
    "primary": {
      "name": "site-a-fw-1",
      "atypical_interfaces": [
        { "name": "fab0",     "role": "fabric",  "fabric_options": { "member_interfaces": ["ge-0/0/0"] } },
        { "name": "eth0",     "role": "control" }
      ]
    },
    "secondary": {
      "name": "site-a-fw-2",
      "atypical_interfaces": [
        { "name": "fab1",     "role": "fabric",  "fabric_options": { "member_interfaces": ["ge-7/0/0"] } },
        { "name": "eth0",     "role": "control" }
      ]
    }
  },
  "zones": [
    { "name": "WAN", "interfaces": ["ge-0/0/1.0", "ge-7/0/1.0"] },
    { "name": "LAN", "interfaces": ["ge-0/0/2.0", "ge-7/0/2.0"] }
  ],
  "policies": [
    {
      "from_zone": "LAN",
      "to_zone": "WAN",
      "rules": [
        {
          "name": "DEFAULT",
          "action": "permit",
          "application": "any",
          "source_address": "any",
          "destination_address": "any"
        }
      ]
    }
  ]
}
```

### 2. topology エンドポイント payload (model-conductor への転送形式)

`POST /fw_policy/<network>/<snapshot>/topology` が model-conductor に送るデータ。
per-node JSON が `firewall` キーにそのまま埋め込まれる。
`"flag": ["firewall"]` は netomox-exp の FW ノード判定 (名前空間変換テーブル生成) に使用される:

```json
{
  "node": [
    {
      "node-id": "site-a-fw-1",
      "mddo-topology:l3-node-attributes": {
        "firewall": { ...per-node JSON と同じ内容... }
      },
      "flag": ["firewall"]
    }
  ]
}
```

### 3. topology.json 内の配置 (RFC8345 形式)

netomox-exp が保存するトポロジ JSON の L3 ノードアトリビュート内:

```json
{
  "node-id": "site-a-fw-1",
  "mddo-topology:l3-node-attributes": {
    "node-type": "node",
    "flag": ["firewall"],
    "prefix": [],
    "static-route": [],
    "firewall": {
      "node": "site-a-fw-1",
      "pair": { ... },
      "zones": [ ... ],
      "policies": [ ... ]
    }
  }
}
```

---

## フィールド説明

| フィールド | 型 | 説明 |
|---|---|---|
| `node` | String | FW ノード名 |
| `pair` | Object | HA クラスタのペア情報 |
| `pair.primary` | Object | プライマリ FW ノード情報 |
| `pair.primary.name` | String | プライマリ FW ノード名 |
| `pair.primary.atypical_interfaces` | Array | 非典型インタフェースリスト |
| `pair.secondary` | Object | セカンダリ FW ノード情報 (primary と同構造) |
| `atypical_interfaces[].name` | String | インタフェース名 |
| `atypical_interfaces[].role` | String | `'fabric'` または `'control'` |
| `atypical_interfaces[].fabric_options` | Object | `role == 'fabric'` のときのみ存在 |
| `atypical_interfaces[].fabric_options.member_interfaces` | Array[String] | メンバーインタフェース名リスト |
| `zones` | Array | セキュリティゾーンのリスト |
| `zones[].name` | String | ゾーン名 |
| `zones[].interfaces` | Array[String] | ゾーン所属インタフェース名リスト |
| `policies` | Array | ゾーン間セキュリティポリシーのリスト |
| `policies[].from_zone` | String | 送信元ゾーン名 |
| `policies[].to_zone` | String | 宛先ゾーン名 |
| `policies[].rules` | Array | ルールのリスト |
| `policies[].rules[].name` | String | ルール名 |
| `policies[].rules[].action` | String | `'permit'` または `'deny'` |
| `policies[].rules[].application` | String | アプリケーション識別子 (例: `'any'`, `'http'`) |
| `policies[].rules[].source_address` | String | 送信元アドレスまたは `'any'` |
| `policies[].rules[].destination_address` | String | 宛先アドレスまたは `'any'` |

---

## キー命名規則

出力 JSON はすべて **snake_case + 複数形** を使用する。
過去の設計では RFC8345 スタイルのハイフン区切り・単数形が混在していたが、
v0.12.2 以降は以下の表の「正しい」形式に統一されている:

| ✓ 正しい (現行) | ✗ 誤り (旧設計の残滓) |
|---|---|
| `zones` | `zone` |
| `policies` | `policy` |
| `interfaces` | `interface` |
| `rules` | `rule` |
| `from_zone` | `from-zone` |
| `to_zone` | `to-zone` |
| `source_address` | `source-address` |
| `destination_address` | `destination-address` |
| `atypical_interfaces` | `atypical-interface` |
| `pair` | `cluster-firewall-pair` |

---

## クロスリポジトリ整合性制約

**重要**: 以下のリポジトリが同じスキーマを参照している。いずれかを変更する際は全リポジトリの整合性を確認すること。

| リポジトリ | 役割 | 参照箇所 |
|---|---|---|
| `repos/firewall-policy-parser` | **スキーマの生成元** (正規) | `src/parse_fw_policy.py` (`_build_output`, `collect_node_fw_attributes`) |
| `netomox` | **スキーマのパーサー** | `lib/netomox/topology/node_attr/mddo_l3_firewall*.rb` の `ATTR_DEFS[ext:]` |
| `repos/netomox-exp` | 保存・名前空間変換 (netomox gem 経由) | `lib/convert_namespace/` (FW ノード判定: `flag: ["firewall"]`) |
| `repos/model-conductor` | 中継・conduit 生成 | `lib/generate_conduit_topology/` (FW ノード識別: `flag: ["firewall"]`) |

### 最も壊れやすいポイント

`netomox` の `ATTR_DEFS[ext:]` の値が firewall-policy-parser の出力 JSON キー名と
**完全一致しない**場合、`convert_namespace` 実行時に `firewall` アトリビュートが消失する。
これは netomox の `SubAttributeBase#select_child_attr` が ext キーでデータを読み書きするため。

**キー名変更時は必ず両リポジトリを同時に更新すること。**

### FW ノード識別フィールドの二重構造

FW ノードは 2 つの方法で識別される:

| フィールド | 場所 | 用途 |
|---|---|---|
| `flag: ["firewall"]` | RFC8345 ノードのトップレベル | netomox-exp / model-conductor での FW ノード判定 |
| `firewall` アトリビュート | `mddo-topology:l3-node-attributes` 配下 | FW 設定情報本体 |

`node.attribute.firewall` は非 FW ノードでも常に non-nil (`MddoL3Firewall` オブジェクトが空で生成される)。
そのため FW ノードの識別には `flag: ["firewall"]` を使うこと (`node.attribute.firewall` を使わない)。
