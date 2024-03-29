# 検証結果

## できたこと(技術面)

- 本番環境のNW機器コンフィグを、L1-L3/OSPF/BGPトポロジやポリシを含めてモデル化することで、仮想環境(emulated env)として「コピー」することができる。
  - 独自コンフィグパーサーの導入
  - ベンダごとに表現が異なるBGPポリシの標準化・可搬性の確保
- ユースケースに合わせて、仮想環境を拡張することができる。
  - AS外の(コンフィグがない)部部についてのデータ(トポロジ)の追加
  - コンテナを使用した検証ツールの導入 (デモでは [iperf 入り Linux コンテナ](https://github.com/ool-mddo/ool-iperf)を使用)
- 本番環境で取得するフローデータに基づいて、プレフィックス別の流量を設定し、実際の状況を模擬することができた。

## できたこと(業務面)

実際にISPでのトライアルを行った結果については、Janog53資料を参照してください。
* [BIGLOBE AS2518をまるごと仮想環境へ”コピー”してみた - JANOG53 Meeting in Hakata](https://www.janog.gr.jp/meeting/janog53/as2518/)

定性的な評価にはなりますが、以下のような効果が期待できます。
* 事前検証環境自体の準備……検証環境を用意することが難しく、検証ができない状況の回避
* レビューの正確性・作業品質の向上
  * 人の経験に依存しないチェックが可能になる…属人性の軽減
  * 非定型作業の動作シミュレーション、本番作業手順の検討への応用

## できななかったこと・課題点

詳細はJanog53資料を参照してください。
* [BIGLOBE AS2518をまるごと仮想環境へ”コピー”してみた - JANOG53 Meeting in Hakata](https://www.janog.gr.jp/meeting/janog53/as2518/)

### 一部のNW機器コンフィグパーサー、BGPポリシーパーサー

一部のNW機器コンフィグについては手頃なコンフィグパーサーがなかったため対応を見送っている。

コンフィグパーサー(Batfish)が対応しているケースでも、BGPポリシデータを使い勝手の良いデータで取り出すことができなかったので、BGPポリシについては[独自のパーサー](https://github.com/ool-mddo/bgp-policy-parser)を実装している。
* IOS-XRからJunos(cRPD)へのBGPポリシー変換が必要となり、そのためのパーサを探したが満足にパースできるツールが無かった
  * 特定のOSのみ対応、nestされたifは非対応、など
  * Batfishはパースできていそうだがデータ仕様の情報が無く扱いづらい (データ仕様が不明 → パターン列挙してデータ確認: 時間がかかる・見落としリスク)
* 既存を拡張させるのは時間がかかりそうなのでTTPで自作
  * 正規表現を書かなくてもパースできるので楽に感じるが、デフォルトの挙動を把握していないと予期しない動きをする

### BGPポリシ変換

BGPポリシについてはプロジェクトの都合・プロジェクトとしてやりたいことの2面から、ベンダに依存しないデータに標準化しています。

* プロジェクトの都合: Emulated環境で使用するコンテナルータとして cRPD を使用する (検証ライセンス調達の都合等がありこれに揃えている)
* やりたいこと: 単純にコンフィグが生成できればよいだけではなくて、BGPポリシの内容・意味などに踏み込んだ静的検査など高度な操作も実現できるようにしたい

実際には Cisco (IOS-XR), Juniper (Junos) のBGPポリシを扱っていますが、それぞれのOSに特化した書き方(表現)などがあり完全に透過変換するのは困難でした。
* IOS-XRとJunos間におけるBGPポリシーコンフィグの差分吸収
  * if-else-elseif、nested-if : Junosのポリシーはif-endifを連ねた構造になっている ➡ if文ごとにsubroutineを作ってそこで評価する形で対応
  * next-hop-self : XRではneighborブロックに設定されるがJunosではthen句で設定 ➡ neighborブロックのパース結果からthen句に反映する形で対応
* 全てのポリシーを等価に変換するのは難しい
  * 変換しきれないポリシーは今回のユースケースでの要否を考慮して読み飛ばすなどした
  * OSごとに効率的な書き方が存在するが、ポリシー変換を考えるとそれぞれの最大公約数的な書き方がされていないと厳しい

### 削除オペレーション

* ツール機能面
  * Containerlab は指定したトポロジを作るツールなので、あとからリンクを足す・減らすといった動的なトポロジ変更ができません。
* 宣言的アプローチ、モデルベース手法との相性
  * kubernetes のように宣言的なアプローチを取る場合、定義された構成情報が必ず実際の環境(リソース)に反映される、べき等なオペレーションが大前提にあるため、明示的に何かを足す・減らすといったオペレーションは存在しません。
  * 一方、実際のネットワークには、個々のネットワークデバイスあるいは複数のデバイスで構成される軽全体にステートがあります。そのためネットワークに対する操作は必ずしも冪等にはなりません(できません)。モデル中心のアプローチを取る場合には、こうしたオペレーションプロセスをどのように考慮するのかを考えていく必要があります。
