# 設計・実装

## manual_stepsデモにおけるデータフロー

![flowchart](fig/flowchart.drawio.svg)

## Prealloc resourceに対するリンク操作

### リンク操作の実態
Emulated env (Linux上の仮想環境)において、リンクはveth pairとして実現されます。このとき :
1. コンテナに対するインタフェースの割り当てはコンテナ起動時に設定されるため、環境起動後にインタフェースを足したり減らしたりできない。
2. リンク(veth pair)は固定/変更不可で、「片方のインタフェースを消して、別なインタフェースに付け替える」ような操作はない。
3. [vethの名前はOS上で制約がある](/doc/system_architecture.md#ネーミングの制約) → そのため、コンテナの中(コンテナで動くNOS)から見える名前とOS上の名前が異なる。この名前の対応は[名前変換テーブルで管理される](/doc/system_architecture.md#名前空間の変換と変換処理)。

という問題があります。

1\. については、preallocated resource として、オペレーションの中であとから必要になるデバイスを事前にparams.yaml (シナリオパラメータ)定義し、環境起動時に「空のインタフェース」として見えるよう起動にすることでワークアラウンドとします。(通常、環境操作の中で対象とするリソース、追加するリソースは事前に定義してあるはずなので。)

2./3. については、リンク操作…「指定したポートの間をつなぐ」APIによって操作を行います。NDT環境(仮想NW)内の既存のノード(ポート)に対して指定、あるいは新規に足したprealloc resourceに対しての指定で組み合わせを分けて対応します。

![preallocated resource operation](fig/prealloc_ops.drawio.svg)

現時点では、リンクをつなぐ端点(termination point)の両方または片方がprealloc resourceとなることを想定しています。
- ⚠️[3]両端点が既存のリソース場合、Seg.X or Y の他のリンク等を鑑みてどのセグメントにつなぐべきなのかを指定しないと操作が確定できないため。(A-Bを、Seg.X でつなぐべき? Seg.Yでつなぎべき? 新規セグメントを作ってつなぐべき? …これらのパラメタが必要になるが今はそこまで含めていない)
- [1][2]では、最も優先度の低い接続=shutdown bridge接続が明確に決まっているため、自動的に処理を確定できる。

リンク操作フロントエンド([topo_frontend.py](../../topo_frontend.py))ではAPIへのデータ生成とPOST、トポロジデータの修正等はmodel-conductorで実行しています。


## リンク操作処理実装

### 概要

mddo-workerを通じたemulated envに対するリンク操作の概要は下の図のようになります。

![worker api](fig/worker_api.drawio.svg)

### リンク操作に伴うトポロジデータおよびemulated networkの変化

マニュアル操作(手動でのリンク=preallocated resource操作)では一つのオペレーションごとに操作前後のスナップショットを取得してトポロジ情報を管理します。
- 操作ごとに異なるスナップショットとしてデータを保存
- 一つ前の操作とのdiffを取る

![snapshots](fig/snapshots.drawio.svg)

> [!WARNING]
> リンク操作に関しては、emulated env topology (topology file) を生成しません。
> - 状態を維持するため。特定のリンクだけをターゲットにする必要があります。都度環境全体のデプロイすると状態が飛んでしまうため、emulated env topology 全体を作り直しても使用しません。
> - 操作するリンクが特定できてその名前が変換できれば良いため。トポロジ全体は original topology 側で管理します。

### リンク操作に伴う処理の流れ

リンク操作に伴うsnapshot (prealloc0,1) の生成の流れは以下の図の通りです。

```mermaid
sequenceDiagram
	participant frontend as topology_frontend.py
	participant conductor as model-conductor
	participant netomox as netomox-exp
	participant topo_orig_asis_pa0 as topology<br>original_asis_preallocated0
	participant topo_orig_asis_pa1 as topology<br>original_asis_preallocated1
	participant worker as mddo-worker

	note over frontend: リンク操作
	activate frontend
		frontend ->> +conductor: POST /conduct/<NW>/topology_ops
			note over conductor: detect target prealloc snapshots
			conductor ->> +netomox: get preallocated snapshot list
			netomox -->> -conductor: snapshot list
			conductor ->> conductor: detect current/next prealloc snapshot<br>(curr=prealloc0, next=prealloc1)

			note over conductor: construct link ops commands
			conductor ->> +netomox: GET /topologies/<NW>/original_asis_preallocated0/topology
			netomox ->> topo_orig_asis_pa0: read
		netomox -->> -conductor: topology data
		activate conductor
			conductor ->> conductor: construct link operation commands
		deactivate conductor

		alt is dry_run == FALSE
			note over conductor: save next topology
			conductor ->> +netomox: POST /topologies/<NW>/original_asis_preallocated1/topology
				netomox ->> topo_orig_asis_pa1: write (NEW)
			netomox -->> -conductor: return

			note over conductor: diff
			activate conductor
				conductor ->> conductor: GET /conduct/<NW>/snapshot_diff/original_asis_preallocated0/original_asis_preallocated1
			deactivate conductor
			conductor ->> +netomox: GET /topologies/<NW>/original_asis_preallocated0/topology
				netomox ->> topo_orig_asis_pa0: read
			netomox -->> -conductor: topology data
			conductor ->> +netomox: GET /topologies/<NW>/original_asis_preallocated1/topology
				netomox ->> topo_orig_asis_pa1: read
			netomox -->> -conductor: topology data
			conductor ->> +netomox: POST /topologies/<NW>/original_asis_preallocated1/topology
				netomox ->> topo_orig_asis_pa1: write
			netomox -->> -conductor: topology data
			note over topo_orig_asis_pa1: with diff (overwriten)

		end
		conductor -->> -frontend: link operation commands etc
		frontend ->> worker: send commands to change emulated env topology
	deactivate frontend

```

### リンク操作(worker側)作業計画

Emulated env で実施すべきトポロジ変更操作(トポロジ変更のための作業計画)は、model-conductorがprealloc snapshot操作を行うのと合わせて生成されます。model-conductorはAPI: `/conduct/<nw>/topology_ops` の応答として、以下のようなデータを返します。

* `command_list` : emulated envで実行すべきリンク操作コマンド(の列)

> [!WARNING]
> どの環境の名前を使うかに注意
> - 操作対象は emulated env なので emulated env namespace の名前を使用する。(ただ、それだと original env namespace で環境操作を考える利用者にはわかりにくいのでコメント付き(#)で併記している。)

```json
{
  "operation": {
    "command": "connect_link",
    "original_link": "as65550-edge01,Ethernet3 <-> edge-tk12,ge-0/0/0.0"
  },
  "current_resource": {
    "links": [
      [
        "link:as65550-edge01,Ethernet3,Seg_empty00,sbp0",
        "link:Seg_empty00,sbp0,as65550-edge01,Ethernet3"
      ],
      [
        "link:edge-tk12,ge-0/0/0.0,Seg_empty00,sbp1",
        "link:Seg_empty00,sbp1,edge-tk12,ge-0/0/0.0"
      ]
    ],
    "empty_bridges": [
      "node:Seg_empty01"
    ]
  },
  "tobe_resource": {
    "remove_links": [
      [
        "link:as65550-edge01,Ethernet3,Seg_empty00,sbp0",
        "link:Seg_empty00,sbp0,as65550-edge01,Ethernet3"
      ],
      [
        "link:edge-tk12,ge-0/0/0.0,Seg_empty00,sbp1",
        "link:Seg_empty00,sbp1,edge-tk12,ge-0/0/0.0"
      ]
    ],
    "append_links": [
      [
        "link:as65550-edge01,Ethernet3,Seg_empty01,sbp0",
        "link:Seg_empty01,sbp0,as65550-edge01,Ethernet3"
      ],
      [
        "link:edge-tk12,ge-0/0/0.0,Seg_empty01,sbp1",
        "link:Seg_empty01,sbp1,edge-tk12,ge-0/0/0.0"
      ]
    ],
    "command_list": [
      [
        "# ovs-vsctl del-port Seg_empty00 as65550-edge01_eth3.0",
        "ovs-vsctl del-port br25 br25p0",
        "# ovs-vsctl add-port Seg_empty01 as65550-edge01_eth3.0",
        "ovs-vsctl add-port br26 br25p0"
      ],
      [
        "# ovs-vsctl del-port Seg_empty00 edge-tk12_eth1.0",
        "ovs-vsctl del-port br25 br25p1",
        "# ovs-vsctl add-port Seg_empty01 edge-tk12_eth1.0",
        "ovs-vsctl add-port br26 br25p1"
      ]
    ],
    "empty_bridge": []
  }
}

```

### リンク操作に伴う名前変換テーブルの更新

OVSにアタッチされているリンク端点(vethインタフェース)にはOSの制約があり、トポロジデータ(original)上の名前とは異なる名前になります([検証環境構築上の制約とそのための別名設定](/doc/system_architecture.md#検証環境構築上の制約とそのための別名設定))。操作対象のリンクはoriginal namespaceの名前で指定するため、操作対象のvethを特定するために名前変換が必要です。

- 名前変換テーブルは、 `originalノード名 { [originalインタフェース名 { 実体インタフェース名 }, …] }` のような階層構造になっている。
- リンク操作では、OVS Bridge = Segment node 側のポートをつけかえることになる。emulated env に対するリンク操作と整合性が取れるように、インタフェースに関する名前変換データを別な(接続先の)ノードの下に移動する操作が必要になる。

### Nokia SR-SIMに対するポート名変換処理

Emulated envのルーター(NWノード)として主に利用しているJuniper cRPDは、商用環境で使用している機材と同じポート名を使用できません。そのため、original env name → emulated env name への変換が必要です。一方、Nokia SR-SIMは、ノードコンフィグに応じて商用環境と同じポート名を利用できます。この場合、original env name = emulated env name とする(名前変換しない)ことができます。

上記の2点より、SR-Simについては変換テーブル作成時に名前を置き換えないという操作が必要です。実装上、prealloc resource 定義の中で `emualted_params` セクションがある場合には、名前を変換していません。

> [!NOTE]
> デモ時点では `emualted_params` セクションが必要になるのは prealloc resource として登録する SR-SIM node だけなので、厳密に SR-SIM指定かどうかまでをチェックしていません。

```yaml
l3_preallocated_resources:
  - type: node
    name: edge-tk12
    interfaces:
      - 1/1/c12/1
      - 1/1/c21/1
    emulated_params:
      license: ./sros_license.txt
      image: localhost/nokia/srsim:25.7.R1
      kind: nokia_srsim
      type: SR-2s
...

## Containerlab MTU問題

cRPD/cJunosEvo間の接続でMTUのミスマッチが発生する問題があります。

```text
root@edge-tk12> show ospf neighbor

Address          Interface              State           ID               Pri  Dead
192.168.1.101    et-0/0/2.0             ExStart         192.168.255.101   10    32
192.168.1.3      et-0/0/2.0             2Way            192.168.255.3     10    32
192.168.1.2      et-0/0/2.0             2Way            192.168.255.2     10    32
192.168.1.1      et-0/0/2.0             2Way            192.168.255.1     10    32
192.168.1.102    et-0/0/2.0             ExStart         192.168.255.102   10    39
192.168.1.11     et-0/0/2.0             2Way            192.168.255.11    10    38
```

```text
root@edge-tk12> show log ospf-debug | match MTU
Mar 21 10:52:39.747040   options 0x52, i 1, m 1, ms 1, r 0, seq 0xc0a80a01, mtu 9500
Mar 21 10:52:39.747176 OSPF packet ignored: MTU mismatch from 192.168.1.102 on intf et-0/0/2.0 area 0.0.0.0
Mar 21 10:52:40.649736   options 0x52, i 1, m 1, ms 1, r 0, seq 0xc0a59082, mtu 9500
Mar 21 10:52:40.649759 OSPF packet ignored: MTU mismatch from 192.168.1.101 on intf et-0/0/2.0 area 0.0.0.0
Mar 21 10:52:41.836716   options 0x52, i 1, m 1, ms 1, r 0, seq 0xc0a04ee1, mtu 1500
Mar 21 10:52:43.061037   options 0x52, i 1, m 1, ms 1, r 0, seq 0xc0a04d0c, mtu 1500
```

これは[cRPDの仕様](https://www.juniper.net/documentation/jp/ja/software/crpd/crpd-deployment/topics/task/configure-settings-on-crpd.html)によるものです。
> cRPDはLinux MTU定義を使用しますが、MTU値はレイヤー3パケットサイズ(IPペイロード)のみを表し、イーサネットフレームオーバーヘッド(14バイトイーサネットヘッダー+4バイトFCS)は含まれません。これは、従来の Junos OS 実装とは異なります

[Containerlabの仕様](https://zenn.dev/moatdrive/books/containerlab-manual/viewer/network#%E3%83%AA%E3%83%B3%E3%82%AF%E3%81%AEmtu)では以下の通りです。
> vethリンクのMTUはデフォルトで9500Bに設定されているため、通常のジャンボ・フレームは問題なくリンクを通過できるはずです。MTUを変更する必要がある場合は、リンク定義でmtuプロパティを設定することで変更できます。

そのため、ノード間のMTU仕様の違いによるミスマッチが発生します。
この状況は、ContainerLabの設定ファイルでリンクのMTUを設定する、cRPDのコンフィグでMTUを設定する、どちらの方法でも対処できます。
今回は[cRPDのコンフィグで回避します](../../playbooks/template/crpd/common/crpd.j2)。これには以下のようなトレードオフがあります。MTUに関する全てのケースは拾いきれないので、現状は実装できる範囲で回避策(workaround)としています。
* ContainerLab側の設定でMTU1500に固定する(cRPDのコンフィグ上にMTUを明示的に出さないようにする)ことができる。作業者から見るとノード上のコンフィグにMTU設定は名には現れない。余計なノイズのないコンフィグにはメリットがある。
* 元(original)のconfig上でMTUが指定されている場合は何らかの手段でL3トポロジに吸い上げる必要がある。ただし元のplatformによって”MTU”のconfigが指す意味が違うので誰かが解釈するロジックを持たなければいけない(処理の複雑さが増える)。
* MTUを作業者から見えないところで固定してしまうと「MTUの不一致を検出する」というユースケースを排除してしまう副作用がある。作業する上ではノイズになりうるが、明文化してconfigを見せる方が、検証環境としては安全側に倒せる。元configが暗黙のMTU1500を採用していた場合、1500と明示的に外挿する必要がある。
* clabとしては9500Byteのままで、cRPDのconfigで制限する。ユースケースとしてMTUを操作したい場合は、打ち消しconfigを入れて変更することで対応してもらう
