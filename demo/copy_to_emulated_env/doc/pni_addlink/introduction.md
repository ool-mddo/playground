# デモユースケース: PNI リンク増設

## 概要

PNIユースケースは通信事業者(ISP)のBGPオペレーションの一つを取り上げています。

次のような状況でのトラフィックコントロールを考えます
- 事前状態：拠点AからのトラフィックはPNI01-Edge-TK01間を経由している
![alt text](fig/pni_addlink_usecase_1.png)


- PNI回線の拠点A側 (Edge-TK01 と PNI01 間の回線) の定常的に流れるトラフィックが増加する
![alt text](fig/pni_addlink_usecase_2.png)


- PNI回線の拠点A側 (Edge-TK03 と PNI01 間の回線) の回線を増設する
![alt text](fig/pni_addlink_usecase_3.png)

- PNI回線の拠点A側 (Edge-TK03 と PNI01 間の回線) の回線上でBGPピアを確立し、経路の一部を増設した回線に流れるようにポリシー設定を入れる
![alt text](fig/pni_addlink_usecase_4.png)


## デモの流れ
デモにあたって、以下の情報は予め既知あるいは指定するものとします。(Given)
また、コンフィグの状態としては追加する回線のLayer3でのリンクはすでに確立済みの状態とします。

- 追加する回線情報(BGP情報も含む)：~/playground/configs/mddo-bgp/original_asis/external_as_topology/pni_addlink/addl3.csv
  ```
  srcrouter,srcif,srcaddress,peeraddress,netmask,peeras,srcas
  edge-tk03,GigabitEthernet0/0/0/2,172.16.1.18,172.16.1.17,30,65550,65518
  ```
- (Option)IXピアなどのまだ対応していないピア形態を除外するためのピア情報：~/playground/configs/mddo-bgp/original_asis/external_as_topology/pni_addlink/except.csv
  ```
  except_peer
  172.16.1.12
  ```


オペレーションの目的は、増設した回線に特定のPrefixのトラフィックを移植することです。そのために、検証(Emulated)環境で以下の操作・実際のNW動作シミュレーションをします。
- [環境準備](./provision.md): デモシステムの設定・起動
- [Step1](./step1.md): 検証(Emulated)環境を構築する
- [Step2](./step2.md): フローに基づいて疑似トラヒックを流す
- [BGPオペレーション](./operation.md): Prefix 広告を調整することで流量を減ることを確認する
  - その後、本番環境に適用して輻輳を回避・防ぐ(デモでは割愛)
- [デモ結果](./result.md)

参考
- [デモシステムの終了](./cleanup.md)
