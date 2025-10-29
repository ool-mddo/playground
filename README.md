# ool-mddo/playground

## Project

* [Okinawa Open Laboratory](https://www.okinawaopenlabs.org/)
  * [Model-Driven Network DevOps Project](https://www.okinawaopenlabs.org/mdnd)

## Documents

* [このプロジェクトの位置づけ](./doc/project_positioning.md)
* [システムアーキテクチャ](./doc/system_architecture.md)
* [ネットワークのモデル](./doc/network_model.md)
  * [中間出力・トポロジデータのサンプル](https://github.com/ool-mddo/mddo-bgp-queries)
* [デモ環境セットアップ](./doc/provision.md)
  * [開発用・開発者向け](./doc/development.md)
* [デモ環境セットアップ(ワーカー分離)](./doc/provision_workers.md)

## Demonstration

* [物理トポロジデータの生成と編集](./demo/layer1_topology/README.md)
* [リンクダウンシミュレーション](./demo/linkdown_simulation/README.md)
  * [大規模ネットワークのシミュレーション性能調査](./demo/multi_region_expr/README.md)
* [実環境をコンテナベースの検証環境にコピーして検証可能にする](./demo/copy_to_emulated_env/README.md)
  * [セグメント移転](./demo/copy_to_emulated_env/doc/move_seg/introduction.md)
  * PNIユースケース
    * [PNI トラフィック制御](./demo/copy_to_emulated_env/doc/pni_te/introduction.md)
    * [PNI リンク増設](./demo/copy_to_emulated_env/doc/pni_addlink/introduction.md)
* [運用者の試行錯誤をモデル操作で実現する](./demo/candidate_model_ops/README.md)
  * [(単一AS)複数リージョントラフィック制御](/demo/candidate_model_ops/doc/multi_region_te/introduction.md)
  * [複数ASトラフィック制御](./demo/candidate_model_ops/doc/multi_src_as_te/introduction.md)

## Reference

### FY2021

* Blog report
  * [モデルベースなネットワーク自動化への挑戦～検証環境の構築と装置のコンフィグ自動取得 - BIGLOBE Style](https://style.biglobe.co.jp/entry/2022/03/30/090000) (2022/03/30)
  * [ネットワークをモデルとして抽象化しオペレーションを高度化するチャレンジ - NTT Communications Engineers' Blog](https://engineers.ntt.com/entry/2022/03/31/090000) (2022/03/31)
  * [ネットワークのモデルベース検査と障害シミュレーションによる運用高度化への挑戦 | ナレッジ／事例 TISプラットフォームサービス](https://www.tis.jp/special/platform_knowledge/nw02/) (2022/04/15)
* NTT Tech Conference 2022 (2022/03/23)
  * [ネットワーク運用におけるモデル定義と Reconciliation Loop への挑戦](https://speakerdeck.com/tjmtrhs/nwyun-yong-niokerumoderuding-yi-toreconciliation-loophefalsetiao-zhan)
* リンクダウンシミュレーション デモ動画 (2022/06/24)
  * [NWのモデルベース検査と障害シミュレーションのデモンストレーション - YouTube](https://youtu.be/wu9IWRbiKKU)

### FY2022

* ENOG74 Meeting (2022/06/10)
  * [ENOG74 Meeting を開催しました – Echigo Network Operators' Group](https://enog.jp/archives/2572)
  * “沖縄オープンラボラトリ Model Driven Network DevOps (MDDO) Project の紹介”
* IEICE ICM研究会 (2022/07/07-08)
  * [研究会 開催プログラム - 2022-07-ICM](https://ken.ieice.org/ken/program/index.php?tgs_regid=2999890161ea46d8a46d7d0ab86457b95ea553f8b858d0678bf9a3535b3e8b1d&tgid=IEICE-ICM)
  * [研究会 - 機器設定ファイルからのトポロジモデル抽出による机上検査を含めたネットワーク設計支援システム](https://ken.ieice.org/ken/paper/20220708FCkR/)
* Okinawa Open Days 2022 (2022/12/13-15)
  * [Dec 15 講演 | Okinawa Open Days 2022](https://www.okinawaopendays.com/session-dec15-oolpj-2)
  * [モデルを基に本番環境を再現して事前に検証可能にする運用サイクル / ood2022 - Speaker Deck](https://speakerdeck.com/corestate55/ood2022)
  * デモ動画: [OOD2022: Model Driven Network DevOps デモ - YouTube​](https://youtu.be/SHexAIO7awE)
* JANOG 51 Meeting (2023/01/25-27)
  * [もし本番ネットワークをまるごと仮想環境に”コピー”できたらうれしいですか? - JANOG51 Meeting](https://www.janog.gr.jp/meeting/janog51/copy/)
  * [もし本番ネットワークをまるごと仮想環境に”コピー”できたらうれしいですか? / janog51 - Speaker Deck](https://speakerdeck.com/corestate55/janog51)
  * デモ動画: [デモ動画_janog51(Model Driven NW DevOps PJ) - YouTube](https://youtu.be/xRxpsly1kls)
* NTT Tech Conference 2023 (2023/03/24)
  * [ネットワーク設定の抽象化とコンテナルータを用いた検証環境の立ち上げ支援](https://speakerdeck.com/tjmtrhs/ntt-tech-conf-2023)
* JANOG 52 Meeting (2023/07/05-07)
  * [コンテナルータをルータ単体として使う: 野良BoF](https://drive.google.com/file/d/1qmufTTErWtO9Ll_sV-7mmQ7ynF7djMY2/view)

### FY2023
* 第 16 回 インターネットと運用技術シンポジウム (IOTS 2023) (2023/12/07-08)
  * ポスターセッション: [本番機器設定ファイルからBGP設定を含むモデルを抽出する仮想検証環境構築方法の検討](http://id.nii.ac.jp/1001/00231069/)
* Okinawa Open Days 2023 (2023/12/05-07)
  * [ISPネットワークのモデルベース再現とBGP運用シミュレーション](https://www.okinawaopendays.com/post/hiroshimaeno) (資料は[プロジェクトページ](https://www.okinawaopenlabs.org/mdnd)に掲載しています)
  * デモ動画: [ISPネットワークのモデルベース再現とBGP運用シミュレーション - YouTube](https://www.youtube.com/watch?v=kdPh17xdPiM)
* JANOG 53 Meeting (2024/01/17-19)
  * [BIGLOBE AS2518をまるごと仮想環境へ”コピー”してみた - JANOG53 Meeting in Hakata](https://www.janog.gr.jp/meeting/janog53/as2518/)
* ITRC meet55 (2024/05/16-17)
  * [ISP機器設定ファイルをもとにトポロジモデルを抽出し仮想検証環境構築と運用手順確認に利用する手法](https://www.itrc.net/meet/meet55-program/)
* 電子情報通信学会 ソサイエティ大会 (2024/09/10-13)
  * [コンテナを用いたISPネットワーク検証システムとトラヒックシミュレーションによる作業事前検証の実施](https://pub.confit.atlas.jp/ja/event/society2024/session/31-20408-11)

### FY2024
* Okinawa Open Days 2024 (2024/12/04-06)
  * [『運用者の試行錯誤を想定した NWモデル上での並列検証システム』萩原 学 / 田島 照久](https://www.okinawaopendays.com/post/1206-03)
  * [運用者の試行錯誤を想定したNWモデル上での並列検証システム / ood2024 - Speaker Deck](https://speakerdeck.com/corestate55/ood2024)
  * デモ動画: [OOD2024 運用者の試行錯誤を想定したNWモデル上での並列検証システム デモ動画 - YouTube](https://www.youtube.com/watch?v=jO3bj1aNNeA)

### FY2025
* APNOMS 2025 (2025/09/22-24)
  * Poster session
  * [Proposal of Verification System Based on Network Models for Large-Scale Network Reproduction in Virtual Environments | IEEE Conference Publication | IEEE Xplore](https://ieeexplore.ieee.org/document/11181368)
