# usecases/refocus_topology

`refocus_topology` ユースケース固有のデータと、それを扱うためのツールを置くディレクトリ。

## ディレクトリ構成

```
usecases/refocus_topology/
├── <network>/
│   └── <snapshot>/
│       ├── topology-def.yaml   # 人が書く簡略トポロジ定義 (このディレクトリでのみ使用)
│       └── topology.json       # RFC8345 形式の blueprint topology (topology-def.yaml から生成)
└── topology_def_to_blueprint.py  # topology-def.yaml → topology.json 変換スクリプト
```

パスパターンは `usecases/<usecase>/<network>/<snapshot>/topology.json` に従う
（`<usecase>` = `refocus_topology` はこのディレクトリ自体が対応）。

### blueprint snapshot とは

`<network>/<snapshot>/topology.json` は、`topologies/<network>/<snapshot>/topology.json`
（Batfish から自動生成された実際のトポロジ）を基準に、どのノード群をどう集約・抽象化するかを
定義する **blueprint snapshot** データ。`generate_conduit_topology`（土管化トポロジ生成、
`demo/candidate_model_ops/21_generate_conduit.sh` の一部）がこれを読み込み、
`original_asis_conduit*` スナップショットを生成する際の集約ルールとして使う。

現在のターゲット: `network=mddo-fw`, `snapshot=original_asis_blueprint`
（`usecases/refocus_topology/mddo-fw/params.yaml` の設定に対応）。

## topology-def.yaml フォーマット

`topology.json` (RFC8345) は複雑かつ blueprint 定義には不要な attribute を多く持つため、
人が直接編集する代わりに、簡略化した `topology-def.yaml` を書いて
`topology_def_to_blueprint.py` で変換する。

```yaml
zooms:
  - network: zoom0-layer3      # このズームレベルの network-id
    supports: layer3           # 直下のレベルの network-id。最下層は固定文字列 "layer3"
                                # (topologies/<network>/<snapshot>/topology.json の layer3 network を指す)
    nodes:
      site-b-fw:
        supports: [site-b-fw-1, site-b-fw-2]   # このノードが集約する、直下レベルのノードID一覧
        tps: [eth2]                            # (任意) リンクを持たない追加 termination-point
      site-b-wan-zone-rt:
        supports: [site-b-br-1, site-b-br-2]
    links:
      - endpoints: ['site-b-fw:eth1', 'site-b-wan-zone-rt:eth2']  # 'node:tp' 形式。片方向記述で
                                                                    # RFC8345 の双方向 link 2本を生成

  - network: zoom1-layer3
    supports: zoom0-layer3     # 2段目以降は、直前に定義した zoom の network 名を参照
    nodes:
      site-b-fw:
        supports: [site-b-fw]  # 1:1 で素通しする場合も supports は必須
        tps: [eth2]
      wan-zone-rt:
        supports: [site-a-wan-zone-rt, site-b-wan-zone-rt]  # 複数ノードを1つに集約
    links:
      - endpoints: ['site-b-fw:eth1', 'wan-zone-rt:eth2']
```

- `zooms` は最下層（`supports: layer3`）から順にリストで並べる。2段目以降の `supports` は
  直前の zoom の `network` 名と一致していなければならない。
- 各ノードの `supports` は、直下レベルのノードID（最下層の場合は実トポロジの layer3 ノードID）
  への参照。存在しない参照はエラーになる（最下層の参照先は外部データのため検証しない）。
- `tps` は省略可。`links` の端点として現れない termination-point（外部ネットワークへの
  境界インタフェースなど）を追加したい場合に使う。
- ノード属性・TP 属性（IPアドレス等）や実際のリンク構成の詳細は blueprint の集約ルールには
  使われないため、変換後の `topology.json` には出力されない。

## topology_def_to_blueprint.py の使い方

`usecases/refocus_topology` ディレクトリで実行する。Python 3 標準ライブラリに加えて
[PyYAML](https://pyyaml.org/) が必要。

```sh
cd usecases/refocus_topology
python3 topology_def_to_blueprint.py [-n NETWORK] [-s SNAPSHOT] [-t TOPOLOGY_DEF_FILE]
```

| オプション | デフォルト | 説明 |
|---|---|---|
| `-n`, `--network` | `mddo-fw` | ネットワーク名 |
| `-s`, `--snapshot` | `original_asis_blueprint` | スナップショット名 |
| `-t`, `--topology-def` | `topology-def.yaml` | 入力ファイル名 |

- 入力: `<network>/<snapshot>/<topology-def-file>`
- 出力: `<network>/<snapshot>/topology.json`（ファイル名固定、常に上書き）

実行例（デフォルト値の場合）:

```sh
cd usecases/refocus_topology
python3 topology_def_to_blueprint.py
# usecases/refocus_topology/mddo-fw/original_asis_blueprint/topology-def.yaml を読み、
# usecases/refocus_topology/mddo-fw/original_asis_blueprint/topology.json を生成
```

### エラー時の挙動

以下の場合、原因（どのファイル・zoom・ノード・参照が問題か）を含むメッセージを標準エラーに出力し、
非ゼロで終了する。

- 入力ファイルが存在しない
- 入力ファイルが YAML としてパースできない
- 想定フォーマット（`zooms` / `network` / `supports` / `nodes` / `links` など）に沿っていない
- ノード・リンクの参照先識別子が見つからない、または不整合（例: 未定義ノードの参照、
  最下層以外での `supports` 参照切れ、同一 TP が複数リンクの端点として重複使用、等）
