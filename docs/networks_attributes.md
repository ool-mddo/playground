# networks アトリビュート (`mddo-topology:networks-attributes`) JSON スキーマ

複数リポジトリをまたがる **正規定義 (canonical definition)** として管理する。
スキーマを変更する場合は、このファイルも合わせて更新し、関係するすべてのリポジトリで整合性を確認すること。

作業メモ (計画) は [docs/work/plans/conduit_blueprint_flag.md](work/plans/conduit_blueprint_flag.md) を参照。

---

## 目的

トポロジ全体 (RFC8345 の最上位コンテナ `ietf-network:networks`) に対するメタデータを持たせる。
現在の用途は、conduit topology (`original_asis_conduit*` / `emulated_asis_conduit*`) が
**どの blueprint snapshot から生成されたか** の記録。blueprint1 から作っても blueprint2 から作っても
conduit の snapshot 名は同じになるため、データ上で生成元を区別できるようにする。

## スキーマ

```json
{
  "ietf-network:networks": {
    "mddo-topology:networks-attributes": {
      "flag": ["blueprint=original_asis_blueprint1"]
    },
    "network": [ { "network-id": "layer3", "...": "..." } ]
  }
}
```

| キー | 型 | 内容 |
|---|---|---|
| `flag` | `Array<String>` | `key=value` 形式の文字列 (既存の `region=<name>` `ebgp-peer=...` と同じ流儀) |

### `flag` の値

| 値 | 意味 |
|---|---|
| `blueprint=<blueprint snapshot 名>` | conduit topology の生成元 blueprint (例: `blueprint=original_asis_blueprint2`) |

* `ietf-network:networks` コンテナは RFC8345 では leaf を持たない。そのため素の `flag` は置かず、
  名前空間付きの独自拡張 (`mddo-topology:`) とする。
* `flag` が空のときは `mddo-topology:networks-attributes` 自体を出力しない。
  conduit 以外のトポロジ (`original_asis` / `emulated_asis` など) には付かない。
* 内部実装 (Ruby) では `flags`、JSON では `flag`。

## データフロー

```
POST /conduct/<nw>/original_asis/conduit_topology { usecase, blueprint_snapshot }
  │  model-conductor: ConduitTopologyGenerator が flag "blueprint=<blueprint_snapshot>" を付ける
  ▼
topologies/<nw>/original_asis_conduit<N>/topology.json
  │  netomox-exp: namespace 変換 (NamespaceConverterBase#copy_networks_attribute で引き継ぐ)
  ▼
topologies/<nw>/emulated_asis_conduit<N>/topology.json
```

## 実装箇所

| リポジトリ | 内容 |
|---|---|
| netomox | `Topology::MddoNetworksAttribute` / `Topology::Networks#attribute` / `DSL::MddoNetworksNWAttribute` / `DSL::Networks#attribute` / `PseudoDSL::PNetworks#attribute` |
| netomox-exp | `NamespaceConverterBase#copy_networks_attribute` (`NamespaceConverter#convert`, `UpperLayer3Filter#filter`) |
| model-conductor | `ConduitTopologyGenerator` (第 3 引数 `blueprint_snapshot`)、`conduit_topology` API |
| netoviz | `GET /api/models/attributes?file=<nw>/<ss>/<file>` (`APIBase#getNetworksAttributes`)、`NetworksFlags.vue` が visualizer ページ最上部に flag を chip 表示 |

netomox の `Networks` の diff (`Networks#diff`) は、この attribute を対象にしていない。
