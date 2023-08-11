# デモ②: 計画メンテ構成+障害シミュレーション

## 対象コンフィグの選択

デモでは pushed_configs: `202202demo1` ブランチを使用します。

```bash
bundle exec mddo-toolbox change_branch -n pushed_configs -b 202202demo1
```

## データ生成

リンクダウン発生時のスナップショットを生成しますが、元 (original) → Drawoff (計画メンテ構成) → Linkdown (リンクダウン障害発生) の段階を踏んで生成していきます。オプションには Drawoff でどこのリンクを停止させるかを指定します。

```bash
bundle exec mddo-toolbox generate_topology -n pushed_configs --off_node regiona-pe01 --off_intf_re "ge-0/0/0"
```

これで生成されるスナップショットは以下のようになります:

- Original (物理スナップショット)
- Drawoff (論理スナップショット) : RegionA-PE01 の ge-0/0/0 にマッチするインタフェースをリンクダウンさせる
    - 障害ポイントの確認 (RegionA-PE01のアップリンクの停止) : netoviz で確認してください
    - 回線借用で一時的に指定のリンクを止めた状況
- Link-down (論理スナップショット) : Drawoff からさらに物理リンクの障害が起きる
    - 回線借用中の障害が発生したときの状況 (Originalを起点にすると二重障害が起きたときの構成tともいえます)

## 静的検査

```bash
bundle exec mddo-toolbox compare_subsets -n pushed_configs -s mddo_network | tee compare_result.json
cat compare_result.json | jq '.[].score' | sort -n | uniq -c
cat compare_result.json | jq '.[] | select(.score >= 30)' | grep target_snapshot
```

```
playground/demo/linkdown_simulation$ cat compare_result.json | jq '.[].score' | sort -n | uniq -c
     20 2
      8 7
      2 21
      3 26
      2 27
      1 51
playground/demo/linkdown_simulation$ cat compare_result.json | jq '.[] | select(.score >= 50)' | grep target_snapshot
  "target_snapshot": "pushed_configs/mddo_network_linkdown_16",
```

Region間は2リンク冗長なので、linkdownスナップショット(二重障害パターン)では最低 1 つは致命的なものがあります。スナップショット No.16 がこれにあたります (netoviz で確認してください)。静的検査によってネットワーク構造の変化が検出できていることがわかります。

## 通信シミュレーション

```bash
# original snapshot
bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "mddo_network$" -r
# drawoff snapshot
bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "drawoff" -r
```

```bash
# all linkdown snapshots
bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "linkdown" -r
```

Original, Drawoff は問題なし。Linkdown は 8/140 が失敗しました。(original: 36 links → drawoff: 35 links → 35 link-down patterns * 4 flows = 140 cases)

```
playground/demo/linkdown_simulation$ bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "linkdown" -r
...

Finished in 0.05899858 seconds.
---------------------------------------------------------------------------------------------------------------------------------------
140 tests, 140 assertions, 8 failures, 0 errors, 0 pendings, 0 omissions, 0 notifications
94.2857% passed
---------------------------------------------------------------------------------------------------------------------------------------
2372.94 tests/s, 2372.94 assertions/s
```

失敗したスナップショット(リンク障害パターン)の絞り込みをします。

```bash
csvtool col 2-3,7-8 pushed_configs.test_summary.csv  | column -s, -t | egrep -vi '(accepted|disabled)'
```

```
playground/demo/linkdown_simulation$ csvtool col 2-3,7-8 pushed_configs.test_summary.csv  | column -s, -t | egrep -vi '(accepted|disabled)'
Snapshot                  Description                                                                 Deposition   Hops
mddo_network_linkdown_16  Link-down No.16: RegionA-PE02[ge-0/0/0] <=> RegionB-PE02[ge-0/0/0] (L1)     NULL_ROUTED  regiona-svr01[enp1s4]->regiona-ce01[Vlan10]->regiona-pe01[ge-0/0/2.0]
mddo_network_linkdown_16  Link-down No.16: RegionA-PE02[ge-0/0/0] <=> RegionB-PE02[ge-0/0/0] (L1)     NULL_ROUTED  regiona-svr02[enp1s4]->regiona-ce01[Vlan10]->regiona-pe01[ge-0/0/2.0]
mddo_network_linkdown_16  Link-down No.16: RegionA-PE02[ge-0/0/0] <=> RegionB-PE02[ge-0/0/0] (L1)     NULL_ROUTED  regiona-svr01[enp1s4]->regiona-ce01[Vlan10]->regiona-pe01[ge-0/0/2.0]
mddo_network_linkdown_16  Link-down No.16: RegionA-PE02[ge-0/0/0] <=> RegionB-PE02[ge-0/0/0] (L1)     NULL_ROUTED  regiona-svr02[enp1s4]->regiona-ce01[Vlan10]->regiona-pe01[ge-0/0/2.0]
mddo_network_linkdown_17  Link-down No.17: RegionA-PE02[ge-0/0/1] <=> RegionA-PE01[ge-0/0/1] (L1)     NULL_ROUTED  regiona-svr01[enp1s4]->regiona-ce01[Vlan10]->regiona-pe01[ge-0/0/2.0]
mddo_network_linkdown_17  Link-down No.17: RegionA-PE02[ge-0/0/1] <=> RegionA-PE01[ge-0/0/1] (L1)     NULL_ROUTED  regiona-svr02[enp1s4]->regiona-ce01[Vlan10]->regiona-pe01[ge-0/0/2.0]
mddo_network_linkdown_17  Link-down No.17: RegionA-PE02[ge-0/0/1] <=> RegionA-PE01[ge-0/0/1] (L1)     NULL_ROUTED  regiona-svr01[enp1s4]->regiona-ce01[Vlan10]->regiona-pe01[ge-0/0/2.0]
mddo_network_linkdown_17  Link-down No.17: RegionA-PE02[ge-0/0/1] <=> RegionA-PE01[ge-0/0/1] (L1)     NULL_ROUTED  regiona-svr02[enp1s4]->regiona-ce01[Vlan10]->regiona-pe01[ge-0/0/2.0]
```

No.16 は静的検査の段階で自明(回線借用時には単一障害点での障害)なので、問題は No.17 ということになります。

## Batfish内部の情報を見て詳細確認・問題点の分析

リンクダウンスナップショット No.17 を batfish にロードします。

```
bundle exec mddo-toolbox load_snapshot -n pushed_configs -s mddo_network_linkdown_17
```

batfish-wrapper 上で python を実行します。

```bash
docker compose exec batfish-wrapper python -i
```

以下の操作をします。

```python
# docker compose exec batfish-wrapper python -i
from pybatfish.client.session import Session
import pandas as pd

pd.set_option("display.width", 300)
pd.set_option("display.max_columns", 20)
pd.set_option("display.max_rows", 200)

bf = Session(host="batfish")
bf.list_networks()
bf.set_network('pushed_configs')
bf.list_snapshots()
bf.set_snapshot('mddo_network_linkdown_17')

# ce01のルーティングテーブル確認
bf.q.routes(nodes='regiona-ce01', vrfs='default').answer().frame()
# PE01のルーティングテーブル確認
bf.q.routes(nodes='regiona-pe01').answer().frame()
# PE01のbgp peer確認
bf.q.bgpEdges(nodes='regiona-pe01').answer().frame()
```

こうなります。

```python
>>> # ce01のルーティングテーブル確認
>>> bf.q.routes(nodes='regiona-ce01', vrfs='default').answer().frame()
           Node      VRF         Network                               Next_Hop     Next_Hop_IP Next_Hop_Interface   Protocol Metric Admin_Distance   Tag
0  regiona-ce01  default       0.0.0.0/0      interface Ethernet1 ip 172.16.1.1      172.16.1.1          Ethernet1     ospfE2      0            110  None
1  regiona-ce01  default   172.16.1.0/30                    interface Ethernet1  AUTO/NONE(-1l)          Ethernet1  connected      0              0  None
2  regiona-ce01  default   172.16.4.0/30  interface Port-Channel1 ip 172.16.5.2      172.16.5.2      Port-Channel1       ospf      2            110  None
3  regiona-ce01  default   172.16.5.0/30                interface Port-Channel1  AUTO/NONE(-1l)      Port-Channel1  connected      0              0  None
4  regiona-ce01  default  172.30.10.0/24                       interface Vlan10  AUTO/NONE(-1l)             Vlan10  connected      0              0  None
5  regiona-ce01  default  172.30.20.0/24                       interface Vlan20  AUTO/NONE(-1l)             Vlan20  connected      0              0  None
>>> # PE01のルーティングテーブル確認
>>> bf.q.routes(nodes='regiona-pe01').answer().frame()
           Node      VRF         Network                            Next_Hop     Next_Hop_IP Next_Hop_Interface   Protocol Metric Admin_Distance   Tag
0  regiona-pe01  default       0.0.0.0/0                             discard  AUTO/NONE(-1l)     null_interface  aggregate      0            130  None
1  regiona-pe01  default   172.16.1.0/30                interface ge-0/0/2.0  AUTO/NONE(-1l)         ge-0/0/2.0  connected      0              0  None
2  regiona-pe01  default   172.16.1.1/32                interface ge-0/0/2.0  AUTO/NONE(-1l)         ge-0/0/2.0      local      0              0  None
3  regiona-pe01  default   172.16.4.0/30  interface ge-0/0/2.0 ip 172.16.1.2      172.16.1.2         ge-0/0/2.0       ospf      3             10  None
4  regiona-pe01  default   172.16.5.0/30  interface ge-0/0/2.0 ip 172.16.1.2      172.16.1.2         ge-0/0/2.0       ospf      2             10  None
5  regiona-pe01  default  172.30.10.0/24  interface ge-0/0/2.0 ip 172.16.1.2      172.16.1.2         ge-0/0/2.0       ospf      2             10  None
6  regiona-pe01  default  172.30.20.0/24  interface ge-0/0/2.0 ip 172.16.1.2      172.16.1.2         ge-0/0/2.0       ospf      2             10  None
>>> # PE01のbgp peer確認
>>> bf.q.bgpEdges(nodes='regiona-pe01').answer().frame()
Empty DataFrame
Columns: [Node, IP, Interface, AS_Number, Remote_Node, Remote_IP, Remote_Interface, Remote_AS_Number]
Index: []
>>>
```

詳細解説は行いませんが、PE01にいくつか問題点があることがわかります。

- PE の bgp neighbor 設定が loopback 指定になっていない
- BGP→OSPFへのデフォルト広告をPE01でしか行っていない

## コンフィグの修正とテストの再実行

デモ②では省略します。
