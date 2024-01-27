# 検証結果

## 検証環境のリソース

実行時間については[デモ動画](https://youtu.be/wu9IWRbiKKU)も参照してください。

- デモおよびNTTCom検証環境の再現で使用している機器(サーバ)は同じです。
    - CPU : Xeon Silver 4216(16C/32T)
    - Mem : 64GB
    - CNF : Juniper cRPD

|  |  | デモ | NTTCom検証環境 |
| --- | --- | --- | --- |
| 検証環境サイズ | NWノード(CNF) | 6 | 12 |
|  | セグメント数(OVS) | 9 | 12 |
| 使用リソース | CPU (ピーク) | 40% | 42% |
|  | Mem (増分) | +2GB | +2GB |
| 処理時間(sec) | 合計 | 153 | 187 |
|  | Step① | 14 | 14 |
|  | Step② | 93 | 125 |
|  | Step③ | 41 | 43 |
|  | Step④ | 5 | 5 |

再現する規模に対して、消費リソースはそれほど増えませんでしたが、デプロイ処理時間(Step②)は増加傾向が見えます。

今回使用しているサーバでも30ノード程度のネットワークであれば環境が起動できると思われます。

## 課題点

### 識別子の変換とコンフィグのパースに関する複雑さ

- 検証作業時(②')に、対応する元(Original)インタフェース名がわからない
    - 👉Interface descriptionに元のインタフェース名を埋めて対応 (正直イマイチ)
- CNFだとネーミングルールが大きく違う
    - Loopback系 : `lo0` or `lo.0` or `lo0.0` ? (cRPDが`lo.0`とかなり特殊)
    - トラフィックIF系 : `ethX` (NW機器とは異なるルールが出てくる)
        - 👉[Batfishでオレオレパッチ](https://github.com/ool-mddo/batfish/tree/ool-mddo-patches)を作って対応
- Batfish (Config parser) 問題
    - IOS系インタフェース名の正規化ルールの違い
        - 10Gインタフェースは省略形(`TenGigE`)で正規化するが、100Gインタフェースはフルネーム(`HundredGigabitEthernet`)で正規化する
    - 一部コンフィグの "誤読" (誤parse)
        - 👉[Batfishオレオレパッチ](https://github.com/ool-mddo/batfish/tree/ool-mddo-patches)
    - OVS非対応
        - 👉OVSにする前にArista cEOSを使っていたので、cEOSのコンフィグをBatfish向けに生成して、OVSの代わりのコンフィグとしてコンフィグパースさせている
        - L3 segmentをOVSで再現しているが、モデルデータ上L3で名前を一意に識別しようとすると、ある程度複雑な名前が必要になる。一方、OVSで実働するインスタンスをたてようとすると、OVSやOS側インタフェース(veth)名の制約があるためそのまま同じ名前を使えない。また、BatfishがOVS configを読めないため、いったん別なコンフィグ(Batfish が読めるコンフィグ: 今回は Arista cEOS)に置き換えているが、この時にもまたインタフェース名ルールが変わってしまう
            - 👉[コンテキストに応じたインタフェース名の使い分け](../../../doc/system_architecture.md)
- 同じemulated namespaceの範囲内でも、見る側のコンテキストによって識別子の使い分けをしなければいけないものがある
    - モデルデータ内のインタフェース名
    - ホストOS側から見た時のインタフェース名
    - コンテナ内(コンテナとして動作するNetwork OS)がわからみたときのインタフェース名
    - 👉[変換テーブルで用途別の名前を管理することで対応](../../../doc/system_architecture.md)

### Containerlab と CNF の取り扱い

- Containerlab Linux Bridge問題
    - ホストOSのLinux Bridgeを使うため、ホスト側のDocker上に存在しているContainerlab以外の仮想ブリッジの経路とEmulated環境上で経路が重複する可能性があり、使えなかった。
    - 👉初期はOVSコンテナを使うことで対応。その後は [Openvswitch bridge - containerlab](https://containerlab.dev/manual/kinds/ovs-bridge/) で対応。OVSコンテナとホスト側のOVS bridgeを使うのとでは、インタフェース名の一意性を保証しなければいけない範囲が変わるので注意が必要。
- 管理アクセスIF問題
    - コンフィグに見えてこないのにルーティングテーブルに見えてくる
    - OSPFで余分に管理IFの経路を広報
    - 管理IFでOSPFの経路交換してしまう
    - 👉コンフィグで打ち消せる設定なら、ゼロタッチコンフィグ生成時に打ち消しコンフィグ入れ込む
