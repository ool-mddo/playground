# Plan: blueprint (topology-def.yaml / topology.json) に endpoint を含める

(状態: 実装済み (playground `v2.12.1-dev`、model-conductor `v1.19.0-dev`)。コミット・PR は未実施)

## 目的

`configs/mddo-fw/original_asis` に endpoint (`site-[abc]-host-[12]`) と、それを収容する L2 スイッチ
(`site-[abc]-seg[12]`) が追加された。これに合わせ `usecases/refocus_topology/mddo-fw/original_asis_blueprint[12]/`
の `topology-def.yaml` を endpoint 込みで再定義し、`topology.json` を再生成する。

要件 (ユーザー指示):

- endpoint は省略しない。blueprint 対象サイト (blueprint1: site-a/b、blueprint2: site-a/b/c) の endpoint は
  original_asis と同等のノードとして保持する。
- endpoint を収容する L2 スイッチは省略可 (endpoint の IP address / default gateway 設定が変わらなければ)。
- endpoint segment の gateway を担う L3 機器 (site-*-cr-1/2) は、endpoint から見た default gateway と機能を
  損なわない範囲でまとめる (冗長化されたものは 1 ノード可)。

## 現状 (調査結果)

### original_asis (configs / topologies)

| 種別 | ノード | 内容 |
|---|---|---|
| endpoint | `site-[abc]-host-1` / `-host-2` | eth0 のみ。host-1: `192.168.{100,101,102}.10/24`、host-2: `192.168.{200,201,202}.10/24`。gateway は `.1` (VRRP VIP)。 |
| L2 SW | `site-[abc]-seg1` / `seg2` | VLAN 100/200。cr-1 ge-0/0/2(3)、cr-2 ge-0/0/2(3)、host を収容。 |
| gateway | `site-[abc]-cr-1/2` | ge-0/0/2 が seg1、ge-0/0/3 が seg2 向け。VRRP group 1/2 (cr-1 が priority 150 / master、cr-2 が 100)。VIP = `.1`。cr-1 = `.2`、cr-2 = `.3`。 |

- layer3 topology では L2 SW は **ノードにならない**。host と cr-1/cr-2 は segment ノード
  (`Seg_192.168.100.0/24` 等、3 endpoint) に繋がる。したがって blueprint (layer3 のみ) に **L2 SW を書く場所はなく、
  「省略」は自動的に満たされる**。
- blueprint の host ノードの `supports` は layer3 ノード名 (`site-a-host-1` 等) を直接参照する。

### blueprint の現状

- blueprint1: site-a / site-b の cr・fw、wan-zone-rt のみ (zoom0 / zoom1 の 2 段)。blueprint2: site-c を追加。
- cr-1/cr-2 は既に `site-*-cr` に集約済み (= gateway の冗長化ペアを 1 ノードにする要件は現行定義で満たす)。
- endpoint は blueprint に無いため、conduit topology では host も host 向け segment も現在は出力されない。
- `topology_def_to_blueprint.py` は `supports` の最下層参照を検証しない。TP 名・link はブループリント上の
  記述でしかなく、conduit 生成 (`BlueprintNetwork`) が使うのは各ノードの `supports` (= グルーピング) のみ。

### conduit 生成の挙動 (model-conductor / 試験で確認)

host を blueprint ノードとして追加した最小 blueprint (cr / fw / host-1 / host-2、site-a) を
model-conductor コンテナ内の `ConduitTopologyGenerator` に与えて出力を確認した
(リポジトリ・topologies には何も書いていない)。結果:

1. host は router type として扱われ、`site-a-host-1:eth1` のように TP が `ethN` に改名される
   (`build_router_tp_mapping` が router グループの external TP を `eth1, eth2, …` に改名。カウンタが 0 始まりで
   割当前に +1 するため `eth1` から。`eth1` 始まりの設計意図の記述はリポジトリに無く、containerlab の mgmt=`eth0`
   を避けたものと推測。JunOS FW の `eth0`=control は FW 固有のルールで host には無関係)。
   host 向け segment (`Seg_192.168.100.0/24`) は blueprint の 2 グループ (cr / host) にまたがるので
   **external segment として出力される** (host が blueprint に入ったことで初めて出る)。
2. **問題 (要対応)**: `site-a-cr` に集約された cr-1/cr-2 の ge-0/0/2 が、それぞれ別 TP
   (`eth2`=`192.168.100.2/24`、`eth5`=`192.168.100.3/24`) として同じ segment に繋がる。
   - `FhrpGatewayResolver` は edge TP (= external segment に繋がらない fhrp TP) しか 1 TP + VIP に畳まないため、
     host 向け TP は対象外。
   - fhrp は「冗長性維持なし (メンバが同一 conduit ノード)」で落とされ、VIP `192.168.100.1` が **どの TP にも
     残らない** → host の default gateway (`192.168.100.1`) が消える。**要件違反**。
   - 3 endpoint segment になるので TP description も空 + warn (`conduit_tp_description.md` の multi-access 規約)。
3. host の `static-route` の `interface` が `eth0` のまま、TP は `eth1` に改名される (不整合)。
   `RouterNodeAttrMerger` は static-route の interface を TP 改名に追従させていない。
   → Step 2 で「改名しない」方針にすることで解消する (static-route 側は変更しない)。
   なお現状の `emulated_asis` では namespace 変換側で host TP が `eth0` → `eth1.0`、static-route interface が
   `dynamic` に変換されており、emulated 側の TP 名は conduit 側の名前に依存しない (実装後に要確認)。

→ **topology-def.yaml の書き換え (データのみ) では要件を満たせない**。model-conductor の修正が必要。

## 変更方針

### Step 1: topology-def.yaml の再定義 (データ)

対象: blueprint1 / blueprint2。 zoom0 / zoom1 の 2 段構成は維持する。

- zoom0-layer3: 各サイトの cr の host 向け TP を追加し、host ノードを追加。
  ```yaml
  site-a-host-1: {supports: [site-a-host-1]}
  site-a-host-2: {supports: [site-a-host-2]}
  ...
  links:
    - endpoints: ['site-a-cr:eth2', 'site-a-host-1:eth0']   # seg1 (VRRP VIP .1)
    - endpoints: ['site-a-cr:eth3', 'site-a-host-2:eth0']   # seg2 (VRRP VIP .1)
  ```
  - cr の TP 番号は conduit 生成の採番に合わせる (eth1 = fw 向け、eth2 = seg1 向け、eth3 = seg2 向け。
    Step 2 で host 向けを 1 TP に畳んだ後の番号)。**実際の conduit 出力と突き合わせて確認する**。
  - host の TP は `eth0` (Step 2 で 1:1 グループは改名しないため。元の host の TP 名と同じ)。
- zoom1-layer3: host / cr をそのまま 1:1 で引き継ぐ (`supports: [site-a-host-1]` 等)。link も同様。
- blueprint1 は site-a / site-b の host (4 台)、blueprint2 は site-a/b/c の host (6 台)。
- L2 SW (`seg1/seg2`) は blueprint に書かない (上記のとおり layer3 では存在しない)。
- gateway (cr-1/cr-2) は現行どおり `site-*-cr` に 1 ノード化 (host から見た default gateway = VIP `.1` を保つ。Step 2 が前提)。

### Step 2: conduit 生成の修正 (model-conductor) — **承認済み (案 A + 2-b)**

Step 2 は次の 2 点から成る (ユーザー承認済み)。

- **2-a: 冗長 gateway TP の畳み込み (案 A)** … 下記
- **2-b: 1:1 router グループの TP を改名しない** … 下記

目的: 同一 conduit ノードに集約された冗長メンバの TP が同じ external segment に複数繋がる場合、
1 TP に畳み、冗長性が維持されない fhrp は VIP をその TP の address にする (既存の edge TP と同じ意味論)。

案:

- **案 A (推奨): external segment 内の同一 conduit ノードの fhrp TP を畳む**
  - `Layer3ConduitBuilder` で、external segment の endpoint のうち「同一 conduit ノードに属し、同じ fhrp group を持つ TP」を
    `FhrpGatewayResolver` の代表選出 (priority → source-address) で 1 つに絞り、残りを segment・tp_mapping から除く。
  - 代表 TP の address / fhrp は `build_edge_tp` と同じ規則 (冗長なし → VIP/prefix、冗長あり → fhrp 維持)。
  - 利点: 既存の edge TP の意味論の自然な拡張。host に限らず「冗長 gateway が 1 segment に複数繋がる」一般ケースに効く。
    3 endpoint → 2 endpoint (p2p) になり TP description (`to_site-a-host-1_eth0`) も生成される。
  - 欠点: `Layer3ConduitBuilder` / `FhrpGatewayResolver` の責務を広げる。既存 spec (`layer3_conduit_builder*_spec.rb`)
    の更新・追加が必要。
- **案 B (不採用): host を「endpoint」として別扱いし、host を含む segment の cr TP は従来の edge TP として処理**
  - host 判定の基準 (flag? 名前? static-route のみ?) が必要で、判定が恣意的。外部 host を blueprint に含める一般形に弱い。
- **案 C (不採用): データのみで運用 (修正しない)**
  - cr-1/cr-2 を集約せず blueprint 上で別ノードにすれば冗長性は維持されるが、「まとめる」要件に反する。不採用。

#### 2-b: メンバが 1 ノードだけの router グループは TP 名を維持する

方針: FW でない (`firewall` flag 無し) ノードでも、改名が不要なら元の TP 名のままにする。

- `Layer3ConduitBuilder#build_router_tp_mapping`: `group.original_node_names.size == 1` の router グループは、
  external TP を `eth1, eth2, …` ではなく **元の TP 名の identity** で `tp_mapping` に入れる
  (`build_fw_tp_mapping` と同じ考え方)。複数ノードを集約するグループ (cr / wan-zone-rt) は従来どおり改名
  (メンバ間で TP 名が衝突し、集約後は元の名前に意味が無いため)。
- 効果: host の `eth0` が維持され、static-route `interface: eth0` との不整合が解消する。segment TP は
  `site-a-host-1_eth0` になる。`RouterNodeAttrMerger` の static-route は変更しない。
- 影響: 既存の blueprint1/2 に 1:1 router グループが無く出力が変わらないことを確認する (host 追加分のみ差分)。
  1:1 router グループの TP 名が維持される挙動変更は、`layer3_conduit_builder.rb` のコメント、
  `docs/architecture.md`、`repos/model-conductor/docs/plans/fhrp_termination_point_attribute.md` の
  「external TP のみ eth1, eth2, … に rename」の記述に反映する。
- fhrp edge TP (`assign_fhrp_edge_tp_mappings`) は集約グループ向けで、採番カウンタは従来どおり。
  1:1 グループが fhrp TP を持つ場合の扱い (改名維持との整合) は実装時に spec で確認する。

テスト: `repos/model-conductor/spec/generate_conduit_topology/` に、冗長 gateway (VRRP) + host の segment が
1 TP + VIP に畳まれること、冗長性維持時 (別 conduit ノード) は fhrp が維持されること、既存ケース (edge TP) が変わらないことを追加。

### Step 3: topology.json の再生成

```sh
cd usecases/refocus_topology
python3 topology_def_to_blueprint.py -s original_asis_blueprint1
python3 topology_def_to_blueprint.py -s original_asis_blueprint2
```

`git diff` で host ノード・link の追加のみであることを確認 (既存ノードの順序・内容が変わらないこと)。

### Step 4: 検証

1. `bundle exec rspec` / `rubocop` (repos/model-conductor)
2. `cd demo/candidate_model_ops && source demo_vars && ./21_generate_conduit.sh` (blueprint1) と `-b original_asis_blueprint2`
3. 生成された `original_asis_conduit*` / `emulated_asis_conduit*` で確認:
   - host ノードが元と同じ IP / default route (next-hop = VIP) を持つ
   - `site-*-cr` の host 向け TP が 1 つで、address = `192.168.x.1/24` (VIP)、fhrp なし
   - host の static-route interface と TP 名が整合
   - TP description の stale / 空が増えていない
   - `emulated_asis_conduit*` で host の TP / static-route が namespace 変換で正しく変換されている (`eth1.0` / `dynamic` 相当)
4. `./22_up_conduit.sh -s emulated_asis_conduit1 -d` で config 生成が成功 (host ノードが含まれる場合の挙動を確認。
   host 向けの emulator 側ノード生成が未対応ならここで判明するので、別 plan とする)
5. netoviz で blueprint1 / 2 の conduit topology を目視確認

### Step 5: ドキュメント更新

- `usecases/refocus_topology/README.md`: blueprint1/2 の対象 (「site-a/site-b のみ」→ endpoint を含む旨)、
  endpoint / L2 SW の扱い (layer3 のため L2 SW は書かない) を追記。
- `demo/candidate_model_ops/README_refocus_topology.md`: conduit topology に endpoint が含まれる旨と
  host gateway の扱い (VIP を保つ) を追記。
- `docs/work/plans/conduit_tp_description.md`: 「現状の blueprint の external segment は全て p2p」の注記を、
  endpoint 追加後も p2p のまま (Step 2 の畳み込みの結果) であることに更新。

## 確認事項 (回答反映済み)

1. Step 2 の方針: 案 A (一般的な畳み込み) でよいか。この修正は model-conductor 本体の変更になる (承認依頼)。
2. blueprint1 に site-c の host は含めない (site-c の cr/fw が blueprint1 に無いため) で良いか。
(決定済み)
1. Step 2 は案 A + 2-b (1:1 router グループは TP 名維持)。
2. blueprint1 に site-c の host は含めない。
3. host の static-route `interface` は 2-b の改名なしで解消 (static-route 側の修正は不要)。
4. blueprint 上の host の TP 名は `eth0`。

## 変更しないもの

- `queries/` `topologies/` `policies/` (自動生成物)
- `configs/mddo-fw` (サブモジュール。更新済み。playground 側の参照先更新は本 plan の対象外)
- 既存インタフェース (blueprint topology-def フォーマット、`topology_def_to_blueprint.py`、API)
