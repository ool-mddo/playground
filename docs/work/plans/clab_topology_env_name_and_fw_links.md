# Plan: containerlab_topology API — 環境名を snapshot 名に / FW クラスタ間 eth2・eth3 直結リンク

(状態: 実装済み・実データで動作確認済み)

## 対象 API

`GET /topologies/:nw/:ss/topology/:layer/containerlab_topology` (netomox-exp)

- API: [convert_layer_topology.rb](../../../repos/netomox-exp/lib/api/topologies/network/snapshot/topology/layer/convert_layer_topology.rb)
- 変換: [containerlab_converter.rb](../../../repos/netomox-exp/lib/convert_topology/containerlab_converter.rb)
- 変更は netomox-exp 内で完結 (model-conductor / shell / playbook の変更は不要)

## 現状

1. 環境名 (`name:`): API の `env_name` パラメータ (grape の `default: 'emulated'`) → converter の
   `@options[:env_name] || 'emulated'`。実質固定値 `emulated`。
2. FW HA ペア間リンク: `fabric_link_data` が primary:**eth3** ↔ secondary:**eth3** のみ自動追加済み
   (`fabric_eth_name` が `'eth3'` 固定)。**eth2 (control) の直結リンクは無い。**

## 変更内容

### 1. 環境名を snapshot 名にする

- API (`convert_layer_topology.rb`):
  - `optional :env_name` から `default: 'emulated'` を削除し、desc を
    「省略時は snapshot 名」に変更。
  - `opts[:env_name] = params[:env_name] || snapshot` として converter に渡す
    (`env_name` 明示指定は上書き用に残す = 確定)。
- converter (`containerlab_converter.rb`):
  - `'name' => @options[:env_name] || 'emulated'` はそのまま (API 経由では常に値が入る。
    converter 単体利用時のフォールバックとして残す)。
- 例: `emulated_asis` snapshot → `name: emulated_asis`、`emulated_asis_conduit1` → `name: emulated_asis_conduit1`。
- 注意: containerlab の lab 名は snapshot 名がそのまま使われる (英数字・`_`・`-` 想定。
  現行 snapshot 名は問題なし)。

### 2. FW cluster pair の eth2 / eth3 直結リンクを固定追加

- `fabric_eth_name(_node)` (単一の `'eth3'`) を、固定 eth 名の配列
  `FIREWALL_PAIR_LINK_ETHS = %w[eth2 eth3].freeze` に置き換える。
- `make_fabric_link(primary_node)` → 複数リンクを返す `make_pair_links(primary_node)` に変更
  (eth ごとに `{ 'endpoints' => ["<primary>:ethN", "<secondary>:ethN"] }` を生成、secondary 未発見なら `[]`)。
- `fabric_link_data` は `flat_map` で全 HA ペア分を連結 (メソッド名は `fw_pair_link_data` 等に改名するか要検討)。
- 出力例 (site-a-fw-1/2):
  ```yaml
  name: emulated_asis
  topology:
    links:
      - endpoints: ['site-a-fw-1:eth2', 'site-a-fw-2:eth2']
      - endpoints: ['site-a-fw-1:eth3', 'site-a-fw-2:eth3']
  ```
- リンク順: 通常 L3 リンク → ペアごとに eth2, eth3 の順 (既存の `link_data + pair_link_data` 構造を維持)。
- eth2 = control (JunOS eth0 相当)、eth3 = fabric。ともに L3 TP に現れない固定割当て
  ([CLAUDE.md](../../../repos/netomox-exp/CLAUDE.md) の eth 割当て表と一致)。
- ns_convert_table 側 (`TermPointNameTable`) は変更しない: eth2 は元々 L3 TP にもテーブルにも
  現れず、コンテナラボ側でのみ直接使用する (eth3 と同様)。

## テスト変更 ([spec/convert_topology/containerlab_converter_spec.rb](../../../repos/netomox-exp/spec/convert_topology/containerlab_converter_spec.rb))

- `'uses env_name option or "emulated" as the name'` — converter 単体の挙動は不変のため維持。
- links 件数: `(l3_links.length / 2) + 2` → `+ 4` (2 HA ペア × eth2/eth3)。
- fabric リンクテスト: eth2 / eth3 の両リンク (site-a, site-b) の存在を assert。
  カウント検証を `-fw-` かつ eth2/eth3 の 4 本に更新。
- FW 属性なしの場合、eth2/eth3 いずれのペアリンクも出ないこと (既存テストを eth2 も対象に拡張)。
- API spec ([spec/api/ns_convert_table_api_spec.rb](../../../repos/netomox-exp/spec/api/ns_convert_table_api_spec.rb)):
  `containerlab_topology` 応答の `name` が snapshot 名 (`env_name` 省略時) になること、
  `env_name` 指定時は上書きされることを追加。

## ドキュメント更新

- [repos/netomox-exp/README.md](../../../repos/netomox-exp/README.md): `env_name` の説明を
  「default: snapshot 名」に。FW ペアの eth2/eth3 直結リンクの記述を追加。
- [repos/netomox-exp/CLAUDE.md](../../../repos/netomox-exp/CLAUDE.md) 「FW HA ペアの fabric リンク自動生成」節:
  eth3 のみ → eth2 + eth3、関連メソッド名を更新。
- [repos/netomox-exp/docs/test_plan.md](../../../repos/netomox-exp/docs/test_plan.md): fabric リンク記述 (L52, L158) を更新。
- [repos/netomox-exp/docs/architecture.md](../../../repos/netomox-exp/docs/architecture.md): 必要なら eth 割当て記述を追記。

## 影響範囲・確認事項

- 呼び出し元: リポジトリ内で `containerlab_topology` を呼ぶのは
  `demo/copy_to_emulated_env/project/playbooks/step2-1.yaml` (旧デモ。`env_name` 未指定のため
  環境名が `emulated` → `emulated_asis` に変わる) と、containerlab worker 側 (`message: clab`、
  本リポジトリ外・未確認)。worker が lab 名 `emulated` を前提にしていないか
  (destroy/cleanup 時の名前参照など。`scripts/env_post_clean.sh` も確認) を実装前に確認する。
- 旧 `demo/copy_to_emulated_env` は env 名変更で挙動が変わりうる (対象外なら許容)。
- repos/netomox-exp は playground のサブモジュール的リポジトリ。変更は netomox-exp 側で
  コミットし、playground 側の参照を更新する。

## 確定事項 (確認済み)

1. `env_name` パラメータは「省略時 snapshot 名の上書き用」として残す。
2. eth2/eth3 リンクの対象は FW HA ペアのみ。FW ノードがあっても pair 属性が無い、
   または pair の相手ノード (secondary) がトポロジ内に見つからない場合はリンクを追加しない
   (現行 `make_fabric_link` の `return nil if secondary_node.nil?` 相当を維持し、`[]` を返す)。
   - テスト追加: pair 属性はあるが相手ノードが存在しない場合に eth2/eth3 リンクが出ないこと。
