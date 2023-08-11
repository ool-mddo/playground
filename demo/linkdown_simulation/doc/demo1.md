# デモ①: 設定変更時のリンク障害シミュレーション

## 準備

デモシナリオ実行用のディレクトリに移動します。

```bash
# in playground dir
cd demo/linkdown_simulation/
```

以降、原則 `playground/demo/linkdown_simulation` ディレクトリで作業します。

## 入力データ(NW機器コンフィグ)の選択

デモには pushed_configs ネットワーク (`configs/pushed_configs`) を使用します。

`202202demo2` ブランチを選択します。

- コマンド(内部的には batfish-wrapper のAPI)でブランチを切り替えていますが、実体としては batfish-wrapper にボリュームマウントされた `playground/configs/pushed_network` リポジトリのブランチを切り替えています

```bash
# in demo/linkdown_simulation dir
bundle exec mddo-toolbox change_branch -n pushed_configs -b 202202demo2
```

```
playground/demo/linkdown_simulation$ bundle exec mddo-toolbox change_branch -n pushed_configs -b 202202demo2
I, [2023-03-08T13:37:02.386894 #1488098]  INFO -- mddo-toolbox: POST: http://localhost:15000//configs/pushed_configs/branch, data={:name=>"202202demo2"}
{
  "current_branch": "202202demo2",
  "message": "Your branch is up to date with 'origin/202202demo2'.",
  "status": "success"
}
```

## データ生成

対象とするネットワーク/スナップショットを指定して、トポロジデータを生成します。

```bash
bundle exec mddo-toolbox generate_topology -n pushed_configs -s mddo_network
```

バックエンド (model-conductor → batfish-wrapper & netomox-exp) では以下の操作が行われています:

- 物理リンクダウンのパターン生成 → 論理スナップショット情報の生成
- 物理・論理スナップショットの情報を基に Batfish でコンフィグ解析 → `playground/queries/<network>/<snapshot>`
- 解析したデータを基にトポロジデータを生成 → `playground/topologyes/<network>/<snapshot>`

ここまでできていれば Web UI ベースのツールが使える状態になります。

- netoviz : `http://locahost:$NETOVIZ_PORT/` (`.env` で指定した値)
- fish-tracer : `http://$FISH_TRACER_BASE_HOST:$PROXY_PORT/` (`.env` で指定した値)

## 静的検査

リンクダウンの発生によって、ネットワークの構成(構造)の変化による影響度を確認するため、ネットワーク構造の特徴量の算出とスコアリングを行います。これをデモでは「静的検査」とよんでいます。

- 特徴量は、トポロジデータの各レイヤについて、ネットワーク構成要素の数、ループの有無、連結しているクラスタの数など、ネットワーク構造の特徴をチェックするものです。
- 元 (Original, 物理スナップショット, mddo_network) の特徴量と、先 (linkdown, 論理スナップショット, mddo_network_linkdown_XX) の特徴量を比較して、ネットワークの構成がどのように変化しているのかをスコア化しています。
    - スコアが大きいほど、リンクダウンの発生による構成変化が大きいと予想できます。

```bash
bundle exec mddo-toolbox compare_subsets -n pushed_configs -s mddo_network | tee compare_result.json
cat compare_result.json | jq '.[].score' | sort -n | uniq -c
cat compare_result.json | jq '.[] | select(.score >= 30)' | grep target_snapshot
```

スコア別のスナップショット数 (”個数 スコア”が表示されています)

```
playground/demo/linkdown_simulation$ cat compare_result.json | jq '.[].score' | sort -n | uniq -c
     20 2
      8 7
      3 21
      3 26
      2 38
playground/demo/linkdown_simulation$ cat compare_result.json | jq '.[] | select(.score >= 30)' | grep target_snapshot
  "target_snapshot": "pushed_configs/mddo_network_linkdown_21",
  "target_snapshot": "pushed_configs/mddo_network_linkdown_36",
```

ここではスコア 38 が一番大きく、No.21 と No.36 のスナップショット(それぞれ何らかのリンク障害に対応)のインパクトが大きいことが考えられます。

本来はこの時点でどういう障害でスコアが大きく出ているのかを確認しておく必要があります。(各スナップショットの構成やリンクダウン発生箇所は netoviz を参照することで確認できます。)


補足: 特定のスナップショットのスコアを確認したい場合には以下のようにします。

```bash
cat compare_result.json | jq '.[] | select(.target_snapshot == "pushed_configs/mddo_network_linkdown_XX").score'
```

## 通信シミュレーション

静的検査に対して、実際にネットワークの動作を確認することを「動的」なテストと読んでいます。ここでは実際に動くデバイスを使うのではなく、Batfishのシミュレーション機能による通信シミュレーションを行います。Batfish では L3 (IP) の到達性シミュレーション(traceroute 同等) が可能です。

対象となるネットワークとスナップショットを指定して通信テストを行います。通信テストのテストパターン (どこからどこにテストをするのか) は、デモディレクトリの traceroute_patterns.yaml に定義されています。デモでは RegionA内サーバ〜RegionB内サーバへ、4パターンの通信フローを生成します。

対象スナップショットは名前(正規表現マッチ)で指定できます。指定しない場合、ネットワーク内の全ての(物理・論理)スナップショットに対して L3 到達性テストが実行されます。

```bash
# original snapshot
bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "mddo_network$" -r
```

```bash
# all linkdown snapshots
bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "linkdown" -r
```

それぞれ実行すると以下のようになります。

```
playground/demo/linkdown_simulation$ bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "mddo_network$" -r
...

TestTracerouteResult: 
  Target: pushed_configs/mddo_network: Origin snapshot: 
    test: regiona-svr01[enp1s4](172.30.10.100) -> regionb-svr01[enp1s4](172.31.10.100):                         .: (0.003522)
    test: regiona-svr01[enp1s4](172.30.10.100) -> regionb-svr02[enp1s4](172.31.20.100):                         .: (0.000279)
    test: regiona-svr02[enp1s4](172.30.10.101) -> regionb-svr01[enp1s4](172.31.10.100):                         .: (0.000217)
    test: regiona-svr02[enp1s4](172.30.10.101) -> regionb-svr02[enp1s4](172.31.20.100):                         .: (0.000154)

Finished in 0.004840821 seconds.
---------------------------------------------------------------------------------------------------------------------------------------
4 tests, 4 assertions, 0 failures, 0 errors, 0 pendings, 0 omissions, 0 notifications
100% passed
---------------------------------------------------------------------------------------------------------------------------------------
826.31 tests/s, 826.31 assertions/s
```

```
playground/demo/linkdown_simulation$ bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "linkdown" -r
...

Finished in 0.070293392 seconds.
---------------------------------------------------------------------------------------------------------------------------------------
144 tests, 144 assertions, 4 failures, 0 errors, 0 pendings, 0 omissions, 0 notifications
97.2222% passed
---------------------------------------------------------------------------------------------------------------------------------------
2048.56 tests/s, 2048.56 assertions/s
```

物理スナップショットではすべて成功、論理スナップショット (linkdown) では 4/144 が失敗しました。

テスト結果は下記のファイルに保存されています。

- `<network>.test_detail.json`
- `<network>.test_summary.json`
- `<network>.test_summary.csv`

Summary JSON/CSV は情報量としては同じです。(機械用 (test script) に使うか、人が使うかでデータフォーマットを変えています)

どのスナップショットで失敗しているのかを確認してみます。下記 2 種類のテスト結果は問題がないので除外しています。

- `ACCEPTED` : 通信できた(問題なし)
- `DISABLED` : 対象 snapshot でテストしたい通信フローの source/destination interface がリンクダウンしている場合 (テスト対象外)

```bash
csvtool col 3,7-8 pushed_configs.test_summary.csv  | column -s, -t | egrep -vi '(accepted|disabled)'
```

```
playground/demo/linkdown_simulation$ csvtool col 3,7-8 pushed_configs.test_summary.csv  | column -s, -t | egrep -vi '(accepted|disabled)'
Description                                                                 Deposition  Hops
Link-down No.19: RegionA-PE01[ge-0/0/2] <=> RegionA-CE01[Ethernet1] (L1)    NO_ROUTE    regiona-svr01[enp1s4]->regiona-ce01[Vlan10]
Link-down No.19: RegionA-PE01[ge-0/0/2] <=> RegionA-CE01[Ethernet1] (L1)    NO_ROUTE    regiona-svr02[enp1s4]->regiona-ce01[Vlan10]
Link-down No.19: RegionA-PE01[ge-0/0/2] <=> RegionA-CE01[Ethernet1] (L1)    NO_ROUTE    regiona-svr01[enp1s4]->regiona-ce01[Vlan10]
Link-down No.19: RegionA-PE01[ge-0/0/2] <=> RegionA-CE01[Ethernet1] (L1)    NO_ROUTE    regiona-svr02[enp1s4]->regiona-ce01[Vlan10]
```

No.19 のリンクダウンスナップショットで失敗しているので、netoviz でどういった構成(リンク障害)だったのかを確認してください。

具体的に、スナップショット No.19 ではどんな問題があったのかを分析していきます。

## Batfish内部の情報を見て詳細確認・問題点の分析

問題の分析は、実際の検証環境(実機環境)等でも良いですが、デモとしては Batfish によるシミュレーションを行っていることもあり、Batfish 上での分析方法を見ていきます。

Linkdown snapshot No.19 を batfish にロードします。

```bash
bundle exec mddo-toolbox load_snapshot -n pushed_configs -s mddo_network_linkdown_19
```

Batfish の操作には python + pybatfish を使用します。これらは batfish-wrapper で使用しているので、一旦このコンテナ内に入って作業を行います。

```bash
docker compose exec batfish-wrapper python -i
```

python を対話モードで起動して `>>>` プロンプトが出たら以下の操作をします。

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
bf.set_snapshot('mddo_network_linkdown_19')

# ce01のルーティングテーブル確認
bf.q.routes(nodes='regiona-ce01', vrfs='default').answer().frame()
# ce01のospf neighbor確認
bf.q.ospfEdges(nodes='regiona-ce01').answer().frame()
# ce01のvrrp priority確認 (どちらがmaster?)
bf.q.vrrpProperties(nodes='/regiona-ce*/', interfaces='/Vlan10/').answer().frame()
```

こうなります

```bash
>>> from pybatfish.client.session import Session
>>> import pandas as pd
>>> 
>>> pd.set_option("display.width", 300)
>>> pd.set_option("display.max_columns", 20)
>>> pd.set_option("display.max_rows", 200)
>>> 
>>> bf = Session(host="batfish")
>>> bf.list_networks()
['pushed_configs']
>>> bf.set_network('pushed_configs')
'pushed_configs'
>>> bf.list_snapshots()
['mddo_network_linkdown_19', 'mddo_network']
>>> bf.set_snapshot('mddo_network_linkdown_19')
'mddo_network_linkdown_19'
>>> 
>>> # ce01のルーティングテーブル確認
>>> bf.q.routes(nodes='regiona-ce01', vrfs='default').answer().frame()
           Node      VRF         Network                 Next_Hop     Next_Hop_IP Next_Hop_Interface   Protocol Metric Admin_Distance   Tag
0  regiona-ce01  default   172.16.5.0/30  interface Port-Channel1  AUTO/NONE(-1l)      Port-Channel1  connected      0              0  None
1  regiona-ce01  default  172.30.10.0/24         interface Vlan10  AUTO/NONE(-1l)             Vlan10  connected      0              0  None
2  regiona-ce01  default  172.30.20.0/24         interface Vlan20  AUTO/NONE(-1l)             Vlan20  connected      0              0  None
>>> # ce01のospf neighbor確認
>>> bf.q.ospfEdges(nodes='regiona-ce01').answer().frame()
Empty DataFrame
Columns: [Interface, Remote_Interface]
Index: []
>>> # ce01のvrrp priority確認 (どちらがmaster?)
>>> bf.q.vrrpProperties(nodes='/regiona-ce*/', interfaces='/Vlan10/').answer().frame()
              Interface Group_Id Virtual_Addresses  Source_Address Priority Preempt Active
0  regiona-ce02[Vlan10]        1   ['172.30.10.3']  172.30.10.2/24      100    True   True
1  regiona-ce01[Vlan10]        1   ['172.30.10.3']  172.30.10.1/24      110    True   True
```

解説は省略しますが、No.19 でおきている問題の原因が以下の要因によるものだということがわかります。

- ce01 が vrrp master になってサーバからのトラフィックを吸い込む
- ce01 に ospf 経路がない
    - ce01 の ospf neighbor がない : ceo1-ce02 間の ospf session がない

原因がわかったら batfish-wrapper (python) を抜けてデモディレクトリに戻ります。python は `Ctrl-d` で抜けます。

## コンフィグの修正

問題点がわかったらコンフィグを修正します。実際にはコンフィグを修正した後、リポジトリに push し、 `playground/configs/` 下のリポジトリで pull してくることになります。デモでは修正済みのコンフィグがすでにブランチ `202202demo` として push されているのでこれを使います。

```bash
bundle exec mddo-toolbox change_branch -n pushed_configs -b 202202demo
```

必要に応じて修正点を確認しておきます。

> [!NOTE]
> ここはREST API等用意してないので直接リポジトリ参照です。実際にはコンフィグリポジトリは別にあってそちらで修正・コミット・差分確認しており、playground ではそのコピー(clone)を参照するだけの想定です。

```bash
# in playground/configs/pushed_configs dir
git diff 202202demo2
```

## テストの再実行

### データ生成

```bash
bundle exec mddo-toolbox generate_topology -n pushed_configs -s mddo_network
```

### 静的検査

- 本来、スコアが変化したスナップショット(障害ケース)については要確認ですが、ここでは省略します。
    - No.19のトポロジ(リンク障害発生時の状況)では、コンフィグ修正前後で OSPF レイヤのトポロジに変化がないためスコアは変化していません
    - その他のリンクダウンスナップショットについてはコンフィグ修正によってOSPFレイヤのトポロジが変化しているものがあります。

```bash
bundle exec mddo-toolbox compare_subsets -n pushed_configs -s mddo_network | tee compare_result.json
cat compare_result.json | jq '.[].score' | sort -n | uniq -c
cat compare_result.json | jq '.[] | select(.score >= 30)' | grep target_snapshot
```

```
layground/demo/linkdown_simulation$ cat compare_result.json | jq '.[].score' | sort -n | uniq -c
     20 2
      8 7
      2 21
      3 26
      3 31
playground/demo/linkdown_simulation$ cat compare_result.json | jq '.[] | select(.score >= 30)' | grep target_snapshot
  "target_snapshot": "pushed_configs/mddo_network_linkdown_20",
  "target_snapshot": "pushed_configs/mddo_network_linkdown_21",
  "target_snapshot": "pushed_configs/mddo_network_linkdown_36",
```

### 障害シミュレーション

```bash
# original snapshot
bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "mddo_network$" -r
```

```bash
# all linkdown snapshots
bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "linkdown" -r
```

```
playground/demo/linkdown_simulation$ bundle exec mddo-toolbox test_reachability -t traceroute_patterns.yaml -s "linkdown" -r
...

Finished in 0.036411818 seconds.
---------------------------------------------------------------------------------------------------------------------------------------
144 tests, 144 assertions, 0 failures, 0 errors, 0 pendings, 0 omissions, 0 notifications
100% passed
---------------------------------------------------------------------------------------------------------------------------------------
3954.76 tests/s, 3954.76 assertions/s
```

コンフィグ修正前は通信テスト(シミュレーション)に失敗していたものがありましたが、修正後は全ての通信テスト(traceroute)が問題なく終わりました。これでコンフィグの修正は完了です。
