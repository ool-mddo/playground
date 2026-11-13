# Plan: OSPF cost/timer をコンフィグ値どおりにトポロジ→コンフィグ出力する

**ステータス: 方針 B で承認・実装済み（netomox-exp `ospf_data_builder.rb`）。最終 conf 出力の再確認と spec 追加は未実施**

承認された方針: クラスタ FW は物理構成ベースで 2 ノード扱いのまま、fw-1/fw-2 の OSPF パラメータを一致させる (B)。
priority / retransmission-interval はスコープ外。
実装: 同名 IF・同一 IP を持つ他ノード(HA 相方)の record を集め、名前順で先頭ノード(fw-1)の値を採用。差異があれば warn ログ。
結果: original_asis / conduit1 / emulated_asis で site-a/b-fw-2 の `ge-7/0/x` が metric 10 (site-c は設定通り 1)。rspec spec/topology_builder 56 examples 0 failures。

## 前提・実施済みの作業

- `configs/mddo-fw` を `playground-v2.12-dev-2` に切替済み（`origin/playground-v2.12-dev-2` を fetch して checkout。
  playground 側ではサブモジュール参照先が変わった状態。コミットは未実施）。
- `docker compose up -d` → `./21_generate_conduit.sh` を実行し、`queries/mddo-fw/*` と
  `topologies/mddo-fw/{original_asis,original_asis_conduit1,original_asis_conduit2,emulated_*}` を再生成済み。
- `playground-v2.12-dev` との config 差分のうち OSPF 関連は次の 2 件のみ:
  - `site-a-fw-1`: `ge-7/0/1.0` / `ge-7/0/2.0` に `metric 10;`
  - `site-b-fw-1`: 同上
  - （他の変更は site-a-fw-1/2 の security policy 追加）
- どのコンフィグにも `hello-interval` / `dead-interval` の記述は**無い**（全て既定値）。

## 調査結果

### 1. Batfish query (`queries/mddo-fw/original_asis/ospf_intf_conf.csv`) — 拾えている

| IF | OSPF_Cost | Hello | Dead |
|---|---|---|---|
| site-a-fw-1[ge-7/0/1.0], [ge-7/0/2.0] | **10** | 10 | 40 |
| site-b-fw-1[ge-7/0/1.0], [ge-7/0/2.0] | **10** | 10 | 40 |
| それ以外 | 1 | 10 | 40 |

- cost はコンフィグ値が query に反映されている。
- timer はコンフィグ未設定なので既定値 (10/40) が出ているだけ。**明示設定した場合に拾うかは未検証**（下記 検証A）。

### 2. topology (`topologies/mddo-fw/original_asis/topology.json`) — cost が落ちている

`ospf_area10` / `ospf_area20` の `mddo-topology:ospf-area-termination-point-attributes`:

- `site-a-fw-1` / `site-b-fw-1` の `ge-7/0/x` は **ospf layer に TP 自体が存在しない**（layer3 には存在）。
- 代わりに `site-a-fw-2` / `site-b-fw-2` の `ge-7/0/x` が存在し、`metric: 1`（fw-2 側のコンフィグには `metric 10` が無いため正しく 1）。
- つまり「Batfish query にある cost=10 が topology に載っていない」ように見えるが、実際は
  **cost=10 を持つ TP (fw-1 の ge-7) が ospf layer に採用されていない**のが原因。

### 3. 原因（どの処理か）

- FW は HA クラスタ (fw-1=node0 / fw-2=node1)。両ノードが同一 IP を持つ
  （例: fw-1 `ge-7/0/1.0` と fw-2 `ge-7/0/1.0` が共に 172.16.2.2/30。`interface_props.csv` で確認）。
- 物理リンク (`edges_layer1.csv`) は実配線側 (br-2 ↔ **fw-2** の ge-7/0/1 等) しか存在しないため、
  layer3 の Segment (`Seg_172.16.2.0/30`) に接続されるのは fw-2 の TP のみ。fw-1 の ge-7 は
  未接続の ip-owner TP (`add_unlinked_ip_owner_tp`) として layer3 に残るが segment と link しない。
- ospf layer は `OspfDataBuilder#setup_ospf_topology` が「layer3 の segment からの link 先」だけを
  ospf node/TP として追加する（`repos/netomox-exp/lib/topology_builder/ospf_data_builder.rb` `add_ospf_node_tp_link`）ため、
  fw-1 の ge-7 は ospf layer に出てこない。
- ospf TP の metric は `find_record_by_node_intf(l3_node.name, l3_tp.name)` で **自ノード名**を使って引くので、
  fw-2 の ge-7 TP は fw-2 の record (cost 1) を拾う（`ospf_tp_attr`）。

### 4. 最終出力（topology → コンフィグ）

- `demo/candidate_model_ops/playbooks/template/vsrx/vsrx_cluster.j2` は
  `ospf_areas` から primary/secondary 両ノードの interface を集約し、`metric` / `hello-interval` / `dead-interval` を
  topology の値どおりに**常に出力する**（出力側の構造は問題なし）。
- 既存の生成物 `configs/mddo-fw/emulated_asis/configs/site-a-fw-1.conf` (2026-10-23 生成、今回は再生成が確認できていない) でも
  `ge-7/0/1.0` が `metric 1;` で出ており、上記の topology の値がそのまま出力されていることと整合。
- crpd 用 `crpd_ospf.j2` も同様に metric/timer/priority を出力する。
- 今回の実行では `22_up_conduit.sh -s emulated_asis -d` を叩いたが ansible-eda の出力ファイルが更新されたことを
  確認できていない（ansible-eda ログは host 出力まで進んだ状態）。**最終出力の再確認は修正後の検証で行う**。

### 5. 関連して気づいた点（今回の主題ではないが影響あり）

- `ospf_data_builder.rb:124` の `ospf_cost || 10` は record が無いときの既定値が 10 で、Batfish/Junos の既定 (1) とずれる
  （record 無し＝ospf 対象外 IF では使われないが、不整合ではある）。
- `priority` (10) と `retransmission-interval` (5) は Batfish の `ospf_intf_conf.csv` に列が無く、topology では固定/既定値。
  テンプレートは `priority 10;` を常に出力するため、コンフィグ側の priority 設定は反映されない
  （Junos 既定は 128 なので、元コンフィグと出力コンフィグで挙動が変わりうる）。要確認: 10 が netomox の既定値かどうか。
- `site-a-fw-2` / `site-b-fw-2` のコンフィグには fw-1 と同じ `metric 10` が入っていない。
  実機クラスタでは両メンバーのコンフィグは同一になるはずなので、サンプル config 側の不整合の可能性がある。

## 修正方針の候補（承認待ち）

| 案 | 内容 | メリット | デメリット |
|---|---|---|---|
| **A: コンフィグ側のみ修正** | fw-2 のコンフィグにも `metric 10` を追加（クラスタ同一設定にする） | コード変更なし。出力 ge-7 も 10 になる | 「実配線ノードの TP を使う」という dedup 仕様に依存したまま。fw-1 側の値だけ変えたケースでは再発 |
| **B: ospf layer で HA 同 IP TP を同期** | netomox-exp `OspfDataBuilder#ospf_tp_attr` で、同一 IP を持つ HA 相方の record にフォールバックまたは優先する（pair 情報は firewall 属性 / `ip_owners.csv` の同一 IP で判定） | クラスタ全体で値が一貫。fw-1 側の設定を正とできる | HA ペア判定の追加が必要。どちらを正とするか仕様決定が必要。`splice_firewall_attributes` の順序（ospf が先に作られる）に注意 |
| **C: テンプレート側で補正** | `vsrx_cluster.j2` で primary/secondary の同名 IF の値をマージ | netomox-exp 変更不要 | topology 自体は誤ったまま。netoviz 表示などと不整合 |

推奨: まず **A（データ整合）＋検証A** で現状の仕組みが cost/timer を正しく通すことを確認し、
HA ペアで片側のみ設定されるケースを許容するかをユーザー判断 → 許容するなら **B**。

## 検証手順（承認後）

- **検証A（timer の取り込み確認）**: 一時的な別 network/snapshot（`configs/mddo-fw` 本体は汚さない）に、
  通常ルータ (例: site-a-br-1) へ `metric` / `hello-interval` / `dead-interval` / `priority` を明示した config を置き、
  1. `ospf_intf_conf.csv` に timer が出るか（Batfish 層）
  2. topology の `timer` / `metric` に出るか
  3. `crpd_ospf.j2` の出力に出るか
  を段階的に確認。priority は Batfish query に列が無いことも合わせて確認。
- 修正後（B を採る場合）: `./21_generate_conduit.sh` で再生成し、`site-a-fw-1` / `site-b-fw-1` の `ge-7/0/x` が
  cost 10 になること、conduit1/2・`emulated_asis` へ回帰が無いこと、`22_up_conduit.sh -s emulated_asis -d` で
  生成された `site-*-fw-1.conf` の `ge-7/0/x` が `metric 10;` になることを確認。
- netomox-exp の変更時は `repos/netomox-exp` の rubocop / rspec を実行。

## 要判断事項

1. fw-1 だけに設定された cost（片側のみ設定の HA ペア）を、クラスタとして有効とみなすか（A のみで良いか / B まで必要か）。
2. `priority` / `retransmission-interval` もスコープに含めるか（Batfish query に無いため、取り込むなら batfish-wrapper 側の query 拡張が必要）。
3. 検証A 用の一時 config をどこに置くか（別 network 名で良いか）。
