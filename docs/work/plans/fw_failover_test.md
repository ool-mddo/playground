# Plan: vSRX chassis cluster の act 側「切り離し」障害試験 (emulated env)

(状態: 実装済み・検証用の縮小トポロジで動作確認済み。mddo-fw フル構成 (`22_up_conduit.sh`) での確認は未実施)

## 目的

`mddo-fw` の FW クラスタ (vSRX chassis cluster, act/sby) を emulated env 上に起動した状態で、
act 側 (node0) を切り離しても E2E 通信が継続されることを確認する障害試験を行えるようにする。

- 確認したいこと: トラフィックの片寄せ、切り替え・切り戻しの手順、切り替え時にトラフィックが落ちないこと (落ちるならその断時間)
- ref. Notion「v2.11-12作業メモ」10/23「そのままではリンクダウンしないのでどうするか、がボトルネック」

## 課題: 単純にリンクを落とせない

vSRX のリンクは次の経路で構成されている ([vsrx_ha.yaml](../../../repos/mddo-worker/playbooks/vsrx_ha.yaml))。

```
対向 cRPD (eth) ⇄ veth ⇄ [Proxmox コンテナ] ethN ⇄ vmbrN (Linux bridge) ⇄ tap{VMID}i{K} ⇄ [vSRX VM] virtio netK = ge-x/0/y
```

- `K = N - 1` (`net$i: virtio,bridge=vmbr$((i+1))`、`eth$((i+1))` を `vmbr$((i+1))` に収容)
  - eth1=fxp0, eth2=control(em0), eth3=fabric(ge-0/0/0 / ge-7/0/0), eth4〜=データ IF
- VMID: act = `{cluster_id}00`, sby = `{cluster_id}01`
- Linux bridge / tap は carrier 状態を伝搬しない (検証で確認済み)。
  - VM 側 (`set_link off`) だけ落とす → vSRX は即 down、対向 cRPD は up のまま (OSPF dead 40 秒待ちの非対称障害)
  - コンテナの `ethN` だけ落とす → 対向は即 down、vSRX は up のまま

## 方式: リンクの両端を落とす

| 側 | 操作 | 効果 |
|---|---|---|
| VM 側 | QEMU monitor `set_link netK off` (`echo ... \| qm monitor <VMID>`) | vSRX の ge-x/0/y が `Physical link is Down` |
| 対向側 | 対向ノードの IF を `ip link set <if> down` (admin down) | 対向は IF down、Proxmox コンテナ側 ethN は NO-CARRIER |

- 当初案はコンテナ側 `ethN` を落とす (対向は carrier down) だったが、**対向が cRPD だと切り戻し後に
  connected 経路が消えてブラックホールになる**ため、対向側の admin down/up に変更した (後述)。
- VM 側は `qm set --netK ...,link_down=1` ではなく monitor を使う (`vsrx_ha.yaml` は netK を MAC 指定なしで
  定義しているため、net の再指定は NIC 差し替えになりうる)。`qm monitor` は標準入力から非対話で使える。
- 対向ノード・IF は `topology-data.json` の `links` から引く。

## 実装

- mddo-worker
  - [playbooks/fw_fault.yaml](../../../repos/mddo-worker/playbooks/fw_fault.yaml) (新規)
  - [ansible-eda/rulebook.yaml](../../../repos/mddo-worker/ansible-eda/rulebook.yaml): `message: "fw_fault"` を追加
  - [README.md](../../../repos/mddo-worker/README.md): 4.4 節ほか
- playground
  - [demo/candidate_model_ops/23_fw_fault.sh](../../../demo/candidate_model_ops/23_fw_fault.sh) (新規):
    JunOS IF 名 → ethN を ns_convert_table (`l1_principal`) で変換して worker に POST。
    HA 相手側のポート (FPC 番号が自ノードの fabric メンバと異なる) を指定するとエラー
  - [README_refocus_topology.md](../../../demo/candidate_model_ops/README_refocus_topology.md): 使い方

| mode | down | up |
|---|---|---|
| `link` | `set_link netK off` + 対向 IF admin down | 対向 IF admin up + `set_link netK on` |
| `node` | 全リンクの対向 IF admin down + `qm stop` | 全リンクの対向 IF admin up + `qm start` |
| `silent` | `qm suspend` (VM 一時停止、リンクは up のまま) | `qm resume` |

## 試験ケース

mddo-fw の FW ([site-a-fw-1.config](../../../configs/mddo-fw/original_asis/configs/site-a-fw-1.config)) は
reth / RG1 を持たず、各ノードの物理 IF (ge-0/0/x: node0, ge-7/0/x: node1) が個別に L3 + OSPF を持つ構成
(冗長グループは RG0 のみ)。データプレーンの切り替えは「RG フェイルオーバ」ではなく
「OSPF の経路切り替え」で起き、OSPF (rpd) は RG0 primary 側で動く。

| # | ケース | 操作 |
|---|---|---|
| TC1 | リンク切り離し (node0 データ IF) | `23_fw_fault.sh -n site-a-fw-1 -i ge-0/0/1,ge-0/0/2` |
| TC2 | ノード障害 (node0 全体) | `23_fw_fault.sh -n site-a-fw-1 -m node` |
| TC3 | サイレント障害 | `23_fw_fault.sh -n <node> -m silent` |
| 切り戻し | — | `-u` で復旧。TC2 は復帰後に手動で RG0 を node0 に戻す |

注意: TC1 で control link / fabric (eth2/eth3) を落とさない (両ノード生存のまま切るとスプリットブレイン)。

## 検証結果 (2026-10-29, tjm-vm04)

### 検証環境

mddo-fw の site-a 部分を模した縮小トポロジを手書きの clab-topo で起動した (playground の
トポロジ生成・config 生成パイプラインは通していない)。

```
client ─ cr-1 ─ (ge-0/0/2) site-a-fw-1/2 (ge-0/0/1) ─ br-1 ─ server
           │       [vSRX cluster 1: node0=fw-1, node1=fw-2]        │
         cr-2 ─ (ge-7/0/2)                        (ge-7/0/1) ─ br-2
```

- vSRX 19.1R1-S1.3 (junos-vsrx3), rtedpro/proxmox:9.2.3, cRPD 23.4R1.9, mddo-worker (eda v0.2.0, clab 0.81.1)
- クラスタ構築は既存の `vsrx_ha` / `vsrx_config` を webhook で実行 (構築に約 19 分)
- FW 設定は site-a-fw-1.config 相当 (OSPF area 0.0.0.10 p2p, LAN→WAN permit, router-id / lo0 なし)
- 断時間は client → server の `ping -i 0.1` の欠落数から算出

### 結果

| ケース | 結果 | ping 欠落 |
|---|---|---|
| 前提確認 | `set_link net3 off` で vSRX ge-0/0/1 が `Physical link is Down`、`on` で Up | — |
| TC1 down | vSRX ge-0/0/1,2 down / br-1,cr-1 eth1 down。RG0 は node0 のまま、経路は cr-2 → ge-7/0/x → br-2 に迂回 | 0.7 秒 |
| TC1 up | cRPD の connected 経路も復帰し、経路は node0 側に戻る | 0.3 秒 |
| TC2 down | node0 `lost`、RG0 が node1 へ移動 | 0.3 秒 (直後) + 7.1 秒 (約 14 秒後の RG0 切替時) |
| TC2 up | `qm start` から約 5 分でクラスタ復帰、さらに約 1.5 分で同期 (CF/CS) 完了・OSPF Full | — |
| 切り戻し (RG0 → node0 手動) | `request chassis cluster failover redundancy-group 0 node 0` → reset | 7.1 秒 |
| TC3 (node1) | VM paused、対向 br-2 eth1 は UP のまま。node0 から node1 は `lost` | (経路外のため影響なし) |
| TC3 resume | node1 は `ineligible` (Control link failure) → 3 分後 `disabled`。**復旧には node1 の再起動が必要** (`qm reset 101` から約 6.5 分で secondary 復帰・OSPF Full) | — |

### わかったこと

1. **vSRX に router-id がないため、IF の up/down で OSPF の全隣接がリセットされる。**
   router-id が ge-0/0/1 のアドレス (172.16.1.2) から決まっており、ge-0/0/1 の down/up のたびに
   「local router ID changed」で node1 側 (ge-7/0/x) を含む全隣接が張り直しになる。
   mddo-fw の実機設定 (site-a/b/c-fw) にも router-id / lo0 はないので、実機でも起こりうる挙動。
   縮小トポロジでは 1 秒以内に再 Full になるため断は短いが、フル構成では伸びる可能性がある。
2. **RG0 の切替 (障害・手動とも) で約 7 秒断になる。** graceful-restart がなく、RE が切り替わると
   OSPF が全部張り直しになるため (Notion トラブル案 8)。TC2 では node0 停止から RG0 切替まで約 14 秒あり、
   その間は node1 のデータプレーンで転送が続いていた。
3. **cRPD の対向で carrier が落ちて戻ると、connected 経路がカーネルから消えたままになる。**
   carrier down 中に rpd が同じプレフィクスの OSPF 経路でカーネルの connected 経路を置き換え、
   carrier up で rpd がその経路を削除する。カーネルは carrier の復帰では connected 経路を作り直さない。
   admin down/up ならカーネルが作り直すので、障害注入は対向側 IF の admin down/up で行う。
   (FW とは無関係の cRPD の性質。veth を落とす他の操作でも同じことが起きる)
4. **silent (VM 一時停止) は cluster からは control link 障害に見え、再開したノードは disabled になる。**
   Junos の仕様どおり。復旧には対象ノードの再起動 (`qm reset <VMID>` や `-m node` の down/up) が必要。
5. VM の netK は MAC 指定なしのため、`qm stop/start` のたびに virtio の MAC が再生成される。
   クラスタモードの ge-x/0/y はクラスタ由来の MAC (4c:96:14:...) を使うので、今回の試験では影響はなかった。
6. (検証用トポロジの事情) cRPD の veth は MTU 9500 で vSRX (1500) と合わず OSPF が ExStart で止まった。
   本番テンプレート (crpd.j2) は unit に `mtu 1500` を設定しているので、フル構成では問題にならないはず。

## 残課題

- mddo-fw フル構成 (`21_generate_conduit.sh` → `22_up_conduit.sh -s emulated_asis`) 上での動作確認
  (`23_fw_fault.sh` は ns_convert_table をモック API で返して変換・POST 内容のみ確認済み)
- ステートフルな通信 (TCP: HTTP / iperf3) の継続確認。今回は ICMP のみ
- node モードでは HA 相手の VM 側 (control/fabric の virtio) は up のまま。相手側は heartbeat 断で検知する
- router-id 未設定の影響を、試験のトラブル案 (Notion「AIに聞く」) として扱うかどうか
