# netoviz2 データ形式・API 仕様

> 状態: **netomox-exp 側は実装済み (ブランチ `feature/netoviz2`)、netoviz2 側は MVP 実装済み (`repos/netoviz2`)**。属性・support 内の差分 (4.4) は netomox gem の修正 (ブランチ `fix/attribute-diff-state`、未リリース) が必要。計画は [docs/work/plans/netoviz2_requirements.md](work/plans/netoviz2_requirements.md) を参照。
> 実装: netomox-exp (`lib/netoviz2/`, `lib/api/helpers_netoviz2.rb`, `lib/api/topologies/network/snapshot/netoviz2_api.rb`)。利用側: netoviz2 (フロントエンド)。
> `schema_version`: `"1"`

netoviz2 が必要とするトポロジ情報を、netomox-exp が RFC8345-based topology JSON (`topology.json`) から整形して返す REST API の仕様。
フロントエンドは本仕様の JSON のみに依存し、生の RFC8345 JSON や `mddo-topology:*` 属性の個別スキーマを知らない。

## 0. 位置づけ: ユースケース非依存の汎用トポロジビューワー

netoviz2 は特定のユースケース (refocus_topology など) 専用ではなく、**mddo-pj の任意のユースケース・ネットワークのトポロジを表示する汎用ビューワー**である。本仕様は、`topologies/` 配下と netoviz / netomox-exp のテスト fixture を含む 53 個の `topology.json` (mddo-fw, mddo-bgp, mddo-mregnw, mddo-ospf, batfish-test-topology, pushed_configs, sample-network など) を横断して確認した事実に基づく (12 参照)。

* フロントエンドはユースケース名・ネットワーク名・レイヤの種類 (`kind`) に依存する分岐を持たない。未知の `kind`、未知の属性キーも汎用の表示にフォールバックする。
* 属性のユースケース固有の見せ方が必要な場合は、**属性キー名 (`mddo-topology:...-attributes` など) をキーとするオプションの表示拡張**として後から足す。拡張が無くても汎用ツリーで必ず表示できること。
* バックエンドも `mddo-topology:*` の個別属性スキーマを解釈しない (gem が保持する属性を `attribute.to_data` のまま返す)。

## 1. 基本方針

* 構造 (ID・親子・接続・support・diff 状態) と、属性 (`attributes` ほか) を分ける。属性は ID を指定して遅延取得する (想定規模: 100 ノード × 数十〜100 TP)。
* 配列はフラットにし、オブジェクト間は ID で参照する。
* 元データに無い情報を推測で補わない。解決できない参照は捨てずに `warnings` に載せる。
* 本 API は読み取り専用。

## 2. ID の規則

元データの `node-id` / `tp-id` / `link-id` には `/` や `,` が含まれる (例: node `Seg_172.32.0.0/30`、tp `ge-0/0/0.0`、link `Seg_172.32.0.0/30,site-a-br-1_ge-0/0/0.0,site-a-br-1,ge-0/0/0.0`)。区切り文字による結合では曖昧になるため、**各セグメントをパーセントエンコード (`A-Z a-z 0-9 _ . -` 以外を %XX。`~` もエンコードする) して `/` で連結**する。`~` をエンコードするのは、link の ID に使うマーカー `~link` が、エンコード後のセグメントと決して一致しないようにするため。

| 種別 | ID の形 | 例 |
|---|---|---|
| layer (network) | `<network-id>` | `layer3` |
| node | `<network>/<node>` | `layer3/Seg_172.32.0.0%2F30` |
| tp | `<network>/<node>/<tp>` | `layer3/site-a-br-1/ge-0%2F0%2F0.0` |
| link | `<network>/~link/<link-id>` (link-id 全体を 1 セグメントとしてエンコード) | `layer3/~link/Seg_172.32.0.0%2F30%2Csite-a-br-1_ge-0%2F0%2F0.0%2Csite-a-br-1%2Cge-0%2F0%2F0.0` |

* ID は不透明な文字列として扱う。フロントは ID を分解せず、必要な構成要素は各オブジェクトのフィールド (`layer`, `node`, `name`) から得る。
* 同じ元データからは常に同じ ID が得られる (安定)。
* **ID の最初のセグメントは、そのオブジェクトが属する layer の ID** (node / tp / link の ID は `<layer ID>/` で始まる)。クライアントは、ID のそれ以外の部分を解釈せずに、ID から layer を特定できる (例: support の参照先がまだ読み込んでいない layer にあるとき)。
* **型が異なる ID は決して一致しない**: layer は 1 セグメント、node は 2 セグメント、tp は 3 セグメント、link は 3 セグメントで 2 番目が必ず `~link` (node や tp の名前が `~link` でも、`~` はエンコードされて `%7Elink` になるため衝突しない)。
* ID は URL セーフな文字だけでできているが、`%` を含むため、URL のパスやクエリに載せる際は **ID 全体をさらにエンコードする** (例: クエリ `?sel=layer3%2Fr1`、パス `layers/ospf_area0`)。サーバはパスパラメータを 1 回デコードしてから ID として扱う。

## 3. 元データとの対応

| netoviz2 | 元データ (RFC8345 + mddo 拡張) |
|---|---|
| layer | `ietf-network:networks.network[]` (`network-id`) |
| layer の `kind` | `network-types` のキー (例: `mddo-topology:l3-network`) |
| layer の `supports` | network の `supporting-network[].network-ref` |
| node | `network[].node[]` |
| tp | `node[].ietf-network-topology:termination-point[]` |
| link | `network[].ietf-network-topology:link[]` (`source.source-node/source-tp`、`destination.dest-node/dest-tp`) |
| node support | `node[].supporting-node[]` (`network-ref`, `node-ref`) |
| tp support | `tp.supporting-termination-point[]` (`network-ref`, `node-ref`, `tp-ref`) |
| link support | `link.supporting-link[]` (`network-ref`, `link-ref`。現行データに実例なし。9 参照) |
| `flags` | `ietf-network:networks.mddo-topology:networks-attributes.flag` ([networks_attributes.md](networks_attributes.md)) |
| `diff` / `diff_state` | 各オブジェクトの `_diff_state_` |

注意:
* link の宛先キーは `destination-node` ではなく **`dest-node` / `dest-tp`** (元データの実表記)。
* ブループリント fixture 等 (`netomox-exp/spec/fixtures/usecases/...`) には node に `supports` という別形式の参照が見られる。これは netomox gem が扱わない形式で、本仕様の対象は gem が扱う `supporting-*` 形式のみとする。

## 4. API

ベースパス: `/topologies/:network/:snapshot/netoviz2` (api-proxy 経由では `http://localhost:15000/topologies/...`)。
全レスポンスは `Content-Type: application/json`。
GET の各エンドポイントは `ETag` を返し、`If-None-Match` に一致すれば `304` (本文なし) を返す。`ETag` の値はファイルの更新と `schema_version` から作る (例: `v1-1746506244000000000-423283`)。POST (`attributes`) は ids によって応答が変わるため、`ETag` も `304` も扱わない。

### 4.1 `GET .../netoviz2/summary`

スナップショットの概要。画面表示の起点、および自動リロードの変更検知 (etag ポーリング) に使う。

```json
{
  "schema_version": "1",
  "network": "mddo-fw",
  "snapshot": "original_asis",
  "etag": "v1-1746506244000000000-297863",
  "flags": ["blueprint=original_asis_blueprint1"],
  "has_diff": false,
  "layers": [
    {"id": "layer1", "name": "layer1", "kind": "mddo-topology:l1-network", "supports": [], "rank": 0,
     "counts": {"nodes": 30, "tps": 102, "links": 90}},
    {"id": "layer2", "name": "layer2", "kind": "mddo-topology:l2-network", "supports": ["layer1"], "rank": 1,
     "counts": {"nodes": 84, "tps": 96, "links": 84}},
    {"id": "layer3", "name": "layer3", "kind": "mddo-topology:l3-network", "supports": ["layer2"], "rank": 2,
     "counts": {"nodes": 54, "tps": 144, "links": 132}}
  ],
  "warnings": [],
  "warnings_total": 0
}
```

| フィールド | 説明 |
|---|---|
| `etag` | ファイルの mtime (ns) と size から生成。HTTP の `ETag` ヘッダ値と同じ (ヘッダでは引用符付き) |
| `flags` | networks-attributes の `flag`。属性が無い、または空なら `[]` |
| `has_diff` | `diff` が `added` / `deleted` / `changed` のオブジェクトが 1 つでもあるか (network / node / tp / link のいずれか)。`_diff_state_` が全て `kept` なら `false`。フロントは diff UI (凡例・フィルタ) の出し分けに使う。**`_diff_state_` の存在だけでは判定しない** (7 参照) |
| `layers[].name` | 元データの `network-id` (表示用。`id` は URL エンコード済みのため、通常は同じ文字列) |
| `layers[].kind` | `network-types` の最初のキー。`network-types` が空なら `null`。複数あれば `kinds` (配列) も併記 |
| `layers[].supports` | 当該レイヤが支持される (依存する) 下位レイヤの ID。**network の `supporting-network` と、node / tp / link の support が実際に指している network の和集合** (存在する network のみ)。理由は下記 |
| `layers[].rank` | 下位から上位への順序。`supports` を持たないレイヤが 0、以降は最長経路で上位ほど大きい。**同じ rank のレイヤは並べて表示してよい**。循環があれば、その循環に含まれるレイヤと、循環に依存するだけのレイヤは `null` にして `warnings` に載せる |
| `layers[].counts` | 件数 (表示負荷の判断に使う) |
| `warnings` | 8 参照 (最大 100 件) |
| `warnings_total` | 検出した警告の総数 (`warnings` は先頭から最大 100 件) |

`layers[].supports` を和集合にする理由 (実データで確認): `supporting-network` の宣言と実際の node/tp の support が一致しない。
* 実際は支持しているのに宣言が無い: 15 network (例: `batfish-test-topology/l3_sample1a` の `bgp_proc` は `supporting-network` が空だが node は `layer3` を支持。`mddo-mregnw` の `bgp_proc` も同様)。
* 宣言があるのに参照先 network が存在しない: 3 件 (`mddo-fw/emulated_asis` などは `layer3` が `layer2` を宣言するが、emulated 環境のトポロジに `layer2` は含まれない)。この場合 `supports` には含めず、`warnings` に `dangling_layer_support` (severity: info) を載せる。
* 宣言があるが実際には使われていない: 8 network (そのまま `supports` に含める)。

また `kind` は `mddo-topology:l1-network` / `l2-network` / `l3-network` / `ospf-area-network` / `bgp-proc-network` / `bgp-as-network` のほか、`ietf-l2-topology:l2-network` / `ietf-l3-unicast-topology:l3-unicast-topology` が実在する。フロントは `kind` の文字列を表示ラベルや色の割り当てに使うのみで、意味による分岐をしない。

`layers` の順序は `rank` 昇順 (`null` は最後)、同順位は `id` 昇順。

### 4.2 `GET .../netoviz2/layers/:layer`

当該レイヤの**構造のみ** (属性なし)。

```json
{
  "layer": "layer3",
  "etag": "...",
  "nodes": [
    {"id": "layer3/Seg_172.32.0.0%2F30", "name": "Seg_172.32.0.0/30", "kind": "segment", "tp_count": 2}
  ],
  "tps": [
    {"id": "layer3/Seg_172.32.0.0%2F30/site-a-br-1_ge-0%2F0%2F0.0", "node": "layer3/Seg_172.32.0.0%2F30",
     "name": "site-a-br-1_ge-0/0/0.0"}
  ],
  "links": [
    {"id": "layer3/~link/Seg_172.32.0.0%2F30%2Csite-a-br-1_ge-0%2F0%2F0.0%2Csite-a-br-1%2Cge-0%2F0%2F0.0",
     "name": "Seg_172.32.0.0/30,site-a-br-1_ge-0/0/0.0,site-a-br-1,ge-0/0/0.0",
     "src": "layer3/Seg_172.32.0.0%2F30/site-a-br-1_ge-0%2F0%2F0.0",
     "dst": "layer3/site-a-br-1/ge-0%2F0%2F0.0"}
  ]
}
```

| フィールド | 説明 |
|---|---|
| `nodes[].name` / `tps[].name` / `links[].name` | 元データの `node-id` / `tp-id` / `link-id` (表示用の生の名前) |
| `nodes[].kind` | 元データの `*-node-attributes` に `node-type` があればその値。無ければキー自体を出さない。**実データで `node-type` を持つのは l3 (`node` / `segment` / `endpoint`) と ospf-area (`segment` / `ospf_proc`) のみ**で、l1 / l2 / bgp-proc / bgp-as や ietf 標準型には無い。フロントは `kind` が無くても同じ見た目で表示できること。値の意味による分岐はせず、色・形の割り当てに使うだけ |
| `nodes[].tp_count` | その node の TP 数 (TP を展開する前に規模を判断するため) |
| `links[].src` / `links[].dst` | 端点の **tp ID**。端点の node は tp ID の親 (`tps[].node`) から得る。端点の node/tp が存在しない場合は 8 参照 |
| `diff` | `added` / `deleted` / `changed` のオブジェクトにのみ付与 (7 参照)。`kept`・`_diff_state_` なしの場合はキー自体を出さない (キー無し = 変化なし) |

* リンクは元データどおりに返し、**向きの異なる 2 本のリンクを 1 本にまとめない** (現行データでは双方向が別エントリ)。束ね表示はフロントの責務。
* 配列の順序は元データの出現順。

### 4.3 `GET .../netoviz2/supports`

全レイヤのオブジェクト間 support を 1 つの配列で返す。

```json
{
  "etag": "...",
  "supports": [
    {"kind": "node", "from": "layer3/Seg_172.32.0.0%2F30", "to": "layer2/site-a-br-1_ge-0%2F0%2F0.0"},
    {"kind": "tp", "from": "layer3/Seg_172.32.0.0%2F30/site-a-br-1_ge-0%2F0%2F0.0",
     "to": "layer2/site-c-br-1_ge-0%2F0%2F1.0/ge-0%2F0%2F1.0"}
  ]
}
```

* `from` = 支持される側 (上位)、`to` = 支持する側 (下位)。向きは常にこの一方向で、逆引き索引はフロントが作る。
* `kind` は `node` / `tp` / `link`。フロントのトレース処理は `kind` に依存しない。
* **サイズ:** 想定規模で数千〜数万件。レイヤ単位の取得が必要になった場合は `?layer=<id>` (from 側のレイヤで絞り込み) を追加する余地を残す (初期は全体のみ)。
* 参照先が存在しない support は含めず、`warnings` に載せる。

### 4.4 `POST .../netoviz2/attributes`

指定オブジェクトの属性・差分詳細を返す。ID が多数になりうるため、URL 長の制限を避けて POST とする (読み取りのみで副作用はない)。

リクエスト: `{"ids": ["layer3/site-a-br-1", "layer3/site-a-br-1/ge-0%2F0%2F0.0", "layer3"]}` (文字列の配列、1〜200 件。それ以外は `422`)。成功時のステータスは `200`。

```json
{
  "etag": "...",
  "objects": {
    "layer3/site-a-br-1": {
      "type": "node",
      "attributes": {
        "mddo-topology:l3-node-attributes": {"node-type": "node", "prefix": [], "flag": []}
      },
      "supporting": {"supporting-node": [{"network-ref": "layer2", "node-ref": "site-a-br-1_ge-0/0/0.0"}]},
      "diff_state": {"forward": "kept", "backward": "changed", "pair": ""}
    }
  },
  "not_found": []
}
```

| フィールド | 説明 |
|---|---|
| `type` | `layer` / `node` / `tp` / `link` |
| `attributes` | netomox gem が保持する属性 (`attribute.to_data`) を**そのまま**返す (キー名は `mddo-topology:...-attributes` などの表記。値の変換・整形・補完はしない)。layer ID の場合は network レベルの属性 |
| `supporting` | gem の support オブジェクトの `to_data` (`supporting-*` 配列)。diff 時に support 要素の `_diff_state_` を表示するため |
| `diff_state` | そのオブジェクトの `_diff_state_` 全体 (`forward` / `backward` / `pair` / `diff_data` があればそれも)。**`kept` で `diff_data` も無い場合はキー自体を出さない** (gem は `_diff_state_` が無いことと `kept` を区別しないため、`diff` と同じ基準にする) |
| `not_found` | 存在しなかった ID |

* `attributes` の内容は **netomox gem が保持している属性に限る** (11 参照)。gem が未宣言のキーを捨てるため、例えば mddo-fw の FW ノードの node 直下の `flag: ["firewall"]` は現状では含まれない。必要なら gem 側に属性を追加して対応する (netoviz2 側では補完しない)。
* 属性が全く無いオブジェクトも実在する (ietf 標準型の fixture など)。その場合 `attributes` は `{}`。
* 属性・support の内部に埋め込まれた `_diff_state_` (例: `pair: "attribute"` / `"support"` と `diff_data`) は `to_data` に含まれ、フロントが属性パネルで差分強調に使う。**この復元には netomox gem の修正が必要** (gem 0.15.0 は読み込み時に属性・support の `_diff_state_` を捨てる。修正は netomox の `fix/attribute-diff-state` ブランチ。リリースされるまでは、オブジェクト自体の `diff` は得られるが、属性内の差分は得られない)。**diff でないトポロジでも `_diff_state_` は `kept` で埋め込まれている** (gem が常に出力する) ため、フロントは `kept` の `_diff_state_` を属性ツリーに表示しない (または既定で折りたたむ)。

### 4.5 既存 API の利用

network / snapshot の一覧は既存の `GET /topologies/index` を利用する。

## 5. エラー

| ステータス | 条件 |
|---|---|
| `404` | network / snapshot / `topology.json` / layer が存在しない |
| `422` | `ids` が配列でない・文字列でない要素を含む・空・上限超過 |
| `500` | 元データが読み込めない (`Invalid topology data: ...`)、または整形処理の不具合 (`Internal error: ...`)。本文は `{"error": "..."}`。詳細はサーバのログに残る |

構造の不整合 (参照切れ・循環) はエラーにせず、`warnings` で伝える (7 参照)。

## 6. 自動リロード

* フロントは `GET .../summary` を `If-None-Match` 付きでポーリングし、`304` なら何もしない。`200` で `etag` が変わっていたら、表示中のレイヤ構造を再取得する。
* `etag` はファイルの変更 (mtime と size) とスキーマ版を検知するためのもので、内容のハッシュではない。スキーマ版を含むのは、サーバの更新で応答形式が変わったとき、クライアントが古い応答を使い続けないため。

## 7. diff

* 各オブジェクトの `_diff_state_` から状態を導出し、`added` / `deleted` / `changed` の場合のみ `diff` を付与する (`kept` と `_diff_state_` なしはキー無し)。
  * 判定は現行 netoviz と同じ: `forward` が `added` または `deleted` ならその値、`forward` か `backward` が `changed` なら `changed`、それ以外は `kept`。
  * `backward` は `null` のことがある (実データ確認済み)。`null` は `kept` 相当として扱う。
* snapshot 名など外部の情報では判定しない。`_diff_state_` を持つオブジェクトと持たないオブジェクトが混在してよい。
* **`_diff_state_` は diff でないトポロジにも入っている。** netomox gem の `to_data` が常に出力するため、実データ (`topologies/mddo-bgp/original_asis`) では 1,372 個のオブジェクトに `forward=kept` で存在し、diff は無い。したがって `has_diff` を「`_diff_state_` の存在」で決めると常に真になる。`has_diff` は導出した状態が `kept` 以外のものがあるかで決める。`kept` を `diff` として出さないのは、応答サイズを抑えるためでもある。
* `has_diff` は `summary` に載せる (4.1)。詳細 (`diff_data`、属性内の `_diff_state_`) は 4.4 で遅延取得する。
* 4.4 の `diff_state` は、`kept` で `diff_data` も無い場合は出さない。gem は「`_diff_state_` が無い」ことと「`kept`」を区別できないため、`diff` と同じ基準にしている。

## 8. warnings

`summary.warnings` に、整形時に検出した不整合を載せる。API は失敗させず、表示は継続する。

```json
{"code": "dangling_support", "severity": "warn", "kind": "tp", "from": "ospf_area0/rt2/eth1.0", "ref": "layer3/rt2/eth1.9", "message": "supporting-termination-point target not found"}
```

| `code` | `severity` | 内容 |
|---|---|---|
| `dangling_support` | warn | node / tp の support の参照先が存在しない (4.3 から除外)。実例: `mddo-ospf/emulated_tobe` の tp `eth1.0` が存在しない `eth1.9` を指す |
| `dangling_layer_support` | info | network の `supporting-network` が、トポロジ内に存在しない network を指す (emulated 環境のトポロジなどで想定内) |
| `dangling_link_endpoint` | warn | link の端点 node/tp が存在しない (当該 link は返し、`src`/`dst` を `null` にする)。調査した 53 ファイルでは 0 件 |
| `layer_support_cycle` | warn | レイヤ間の support に循環があり `rank` を決められない (`layers` に循環に含まれるレイヤだけを載せる)。同 0 件 |
| `duplicate_id` | warn | 同一 ID が重複 (最初のものを採用)。同 0 件 |

* フロントは `info` を既定で非表示 (件数のみ)、`warn` を目立つ形で表示する。

警告が多数の場合は先頭から最大 100 件とし、総数を `summary.warnings_total` に載せる。

## 9. link の support / attributes (将来拡張の枠)

* 現行データに `supporting-link` の実例はなく、link の `attributes` の利用実績もない。
* スキーマは最初から `supports[].kind: "link"` と、4.4 の `type: "link"` を許容する。
* バックエンドの support 抽出は kind (`node` / `tp` / `link`) を共通の仕組みで扱い、`link` の support (`supporting-link`) も実装済み (実データが無いため、単体テストのみで検証)。link の attributes も `attributes` API で同様に返せる。レスポンス形式の変更は不要。

## 10. 互換性

* `schema_version` は破壊的変更時に上げる。フィールドの追加は互換変更とみなし、フロントは未知のフィールドを無視する。
* フロントは `summary.schema_version` を確認し、未対応なら画面にその旨を表示する。

## 11. 実装上の注意 (netomox-exp)

**整形処理は netomox gem のオブジェクトモデル (`Netomox::Topology::Networks`) を使って実装する。** データの整合性と一貫性を gem に任せ、保守性と可読性を優先する。生の Hash を直接操作する実装は採らない (キー名の知識を netomox-exp 側に二重に持たないため)。

* 読み込みは既存の `read_topology_instance` (`lib/api/helpers.rb`) を再利用する。属性は `attribute.to_data`、diff は `diff_state` (`forward` / `backward` / `pair` / `diff_data`) から取得する。
* support の参照先は、gem の support オブジェクトの `to_data` (`network-ref` / `node-ref` / `tp-ref` / `link-ref`) から ID を作り、自前の ID 索引で存在を確認する。参照先が無ければ `dangling_support` を warnings に載せる。**gem の `find_object_by_support` や `ref_node` / `ref_tp` は使わない**: これらは `__` で名前を分割するため、名前に `__` を含むと誤動作し、network が無いと例外になり、線形探索で遅いため。
* 性能は厳密には求めない (本アプリの利用想定では緊急性が低い)。**まず gem の API をそのまま使って実装し、段階 2 で実データと合成フィクスチャを使って計測する。許容できない遅さがあれば、netomox-exp 側で回避せず gem 側を改善する** (索引の追加など。netomox の修正を伴う開発手順は [design_notes/development.md](design_notes/development.md#netomox-gem-の修正を伴う開発) を参照)。
* 同じ node / tp が重複する場合は最初のものを採用し、`duplicate_id` を warnings に載せる (gem は path で同一性を判定する)。
* `network` キーが無いなど gem が読み込めないデータは、`500` (`{"error": ...}`) として返す (5 参照)。

### gem を使うことによる制約 (許容する)

* **属性は gem が保持するもの (`ATTR_DEFS` に宣言されたキー) だけが得られる。** `attributes` は `attribute.to_data` の結果をそのまま返し、netomox-exp 側で整形・補完しない (4.4)。gem が未宣言のキーを捨てるため、次は表示されない。
  * node 直下の `flag` (mddo-fw の FW ノードの `["firewall"]`)。既存の `namespace_converter_base.rb` は同じ理由で生 JSON から復元しているが、netoviz2 ではこの復元を行わない。
  * `ATTR_DEFS` に無い属性を持つ外部形式 (ietf 標準型の属性など)。
* これらが表示すべき情報であれば、**gem 側で `ATTR_DEFS` に追加する** (netomox のリリースが必要)。段階 2 の最初に、53 ファイルを gem で読み込み `to_data` で書き戻して失われるキーを数え、gem 側の修正候補を一覧にする。
* gem の型検査が不一致を警告ログに出す (`attr_base.rb`)。大きなデータでログが増えるため、その点も計測時に確認する。
* コンテナ内の gem は netomox 0.15.0 で、調査したローカル checkout (0.15.0) と同じ版 (段階 2 で確認済み)。

### 実装メモ (段階 2 で確認した事実)

**gem の往復確認** (コンテナ内で、読み込み → `to_data` で失われるキーを数えた。公開されているデータと稼働環境のデータの両方):

| 失われるキー | 件数・範囲 | 対応 |
|---|---|---|
| node 直下の `flag` (`["firewall"]`) | 28 件、6 ファイル (mddo-fw の FW ノード) | gem 側に追加する候補 (本 API では表示されない) |
| 属性・support 内の `_diff_state_` (往復では「失われるキー」として数えない) | diff 付きの実データ (`mddo-ospf/emulated_diff`) で、属性内の差分 1 件、support の `pair` 118 件が失われていた | **gem を修正済み** (netomox `fix/attribute-diff-state`、未リリース)。修正後は復元されることを実データで確認 |
| bgp-proc ノード属性の一部 (`as-path-set[].as-path.*`、`policy[].default.actions[].next`、`policy[].statements[].actions[].type`、`policy[].statements[].conditions[].as-path`、`prefix-set[].prefixes[].length` / `match-type`) | BGP ポリシーを含む 1 ファイル。gem が「Unknown bgp-policy ... keyword」「Attribute type mismatch」のエラーログを出す | gem の bgp-proc 属性定義が、データ生成側 (bgp-policy-parser) の出力に追従していない。gem 側に追加する候補 |
| node の `supports` (別形式) | netomox-exp の blueprint fixture 1 件 | 対象外 (スナップショットの `topology.json` の形式ではない) |
| l3 TP 属性が空 (`{}`) のもの | 1 ファイル 14 件 | 影響なし (空の属性は元から表示対象外) |

読み込みエラー (例外) になったファイルは 0 件。gem は ERROR レベルのログを大量に出す (BGP ポリシーの未知キーなど)。netomox-exp の API では既存のログ設定 (`NETOMOX_LOG_LEVEL`) に従う。

**規模の計測** (合成データ: 3 レイヤ × 100 ノード × 100 TP/ノード = 30,000 TP、リンク 30,000、JSON 7.8MB。netomox-exp コンテナ内、Ruby 3.4):

| 処理 | 時間 | 備考 |
|---|---|---|
| `JSON.parse` | 0.11 秒 | |
| `Netomox::Topology::Networks.new` (gem) | 1.97 秒 | メモリ 約 +150MB |
| `Model.new` (ID 付与・support 解決) | 0.67 秒 | メモリ 約 +35MB |
| 各ビルダー (summary / layer / supports / attributes 200 件) | 0.002〜0.014 秒 | |
| 1 リクエスト (キャッシュなし) | 約 2.8 秒 | |

応答サイズ (合成データ): layer (1 レイヤ、10,000 TP) 2.5MB (gzip で 222KB)、supports (全体、20,000 件) 1.7MB (gzip で 108KB)、attributes (200 件) 72KB (gzip で 2KB)、summary 1KB。

* 想定上限では gem の読み込みがほぼ全体を占めるため、**etag をキーとするモデルのキャッシュを入れた** (`Netoviz2::ModelCache`、直近 2 件の LRU)。キャッシュ後は、ファイルが更新されない限り 2 回目以降のリクエストはモデルを再構築しない。
* 想定上限では gzip が実質必須 (2.5MB → 222KB)。api-proxy (nginx) への `gzip` 設定の追加は、計画の段階 5 で行う。
* 実データ (最大: 全レイヤ 720 TP) では、summary は約 0.1〜0.2 秒、layer は約 0.1 秒、layer3 の応答は 90KB だった。
* 想定上限でのキャッシュなしの遅さは、許容できなければ netomox gem 側で改善する (索引の追加など)。現時点では必要性は低い。

## 12. 規模の目安 (実データ)

調査対象 53 ファイルの横断結果。

| データ | 全レイヤ合計 (nodes / tps / links) | サイズ | 備考 |
|---|---|---|---|
| `mddo-mregnw/original_asis` (最大) | 315 / 720 / 670 | 約 423KB | bgp_proc + ospf_area0 + layer3 + layer2 + layer1 |
| `mddo-fw/original_asis` | 222 / 462 / 426 | 約 298KB | layer1/2/3 + ospf_area0/10/20/30 |

* 1 レイヤあたりの最大は node 140 (mregnw の layer2)、TP 240 (mregnw の layer3)。**1 node あたりの TP 数の最大は 12** (調査した実データ全体で)。
* 現行の実データは、計画の想定上限 (100 ノード × 1 デバイス最大 100 TP = 1 レイヤ最大約 1 万 TP) の **1/10〜1/50 程度**。想定上限は設計の余裕として維持するが、通常の挙動の確認・回帰テストには実データを使い、規模の確認には合成フィクスチャを使う (計画 8 の段階 2)。
* 実データの特徴: `bgp_proc` / `bgp_as` / `ospf_area*` を含むもの、emulated 環境用の `layer1`/`layer2` を持たないもの、ietf 標準型の最小構成 (属性なし) がある。いずれも本仕様で表現できる (3、4.1、4.4、8)。

### 調査で確認した事実 (53 ファイル)

| 項目 | 結果 |
|---|---|
| link の端点キー | 全て `source-node/source-tp`、`dest-node/dest-tp` (`destination-node` 表記は 0 件) |
| `supporting-link` | 0 件 (link の support は未使用) |
| link に属性 | 構造キー以外のキーは 0 件 (`_diff_state_` を除く) |
| network-id に `/` や `%` | 0 件 (ただし ID はエンコードする) |
| node / tp の ID 重複 | 0 件 |
| レイヤ間 support の循環 | 0 件 |
| link 端点の参照切れ | 0 件 |
| node/tp support の参照切れ | 1 件 (`mddo-ospf/emulated_tobe` の `ospf_area0/rt2/eth1.0` → `layer3/rt2/eth1.9`) |
| `supporting-network` と実際の support の不一致 | 宣言なしで支持 15、宣言先が存在しない 3、宣言のみ 8 (4.1 参照) |
| `mddo-topology:networks-attributes` | 5 ファイル |
| `_diff_state_` | 非 diff のトポロジにも `forward=kept` で存在 (7 参照) |
