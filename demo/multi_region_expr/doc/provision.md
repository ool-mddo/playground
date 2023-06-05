<!-- TOC -->

- [環境準備](#%E7%92%B0%E5%A2%83%E6%BA%96%E5%82%99)

<!-- /TOC -->

---

# 環境準備

[リンクダウンシミュレーション](../../linkdown_simulation/doc/provision.md) と同様です。

以下の点については追加で必要になります:
* Gnuplot のインストール
* 分析対象にするネットワーク機器コンフィグ(スナップショット)については追加のデータを使用します。

Gnuplot のインストール (Ubuntu)

```shell
sudo apt install gnuplot
```

大規模ネットワーク用NW機器コンフィグの準備

```shell
cd configs/pushed_configs
git fetch
git checkout -b 202202demo origin/202202demo # 2region
git checkout -b 5regiondemo origin/5regiondemo
git checkout -b 10regiondemo origin/10regiondemo
git checkout -b 20regiondemo origin/20regiondemo
git checkout -b 40regiondemo origin/40regiondemo

cd ../.. # playground
```
