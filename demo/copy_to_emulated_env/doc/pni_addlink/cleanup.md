## デモ環境の停止

検証(Emulated)環境を削除します。

```bash
# playground/demo/copy_to_emulated_env
sudo ./demo_remove.sh
```

Grafanaを停止します。

```bash
# playground/demo/copy_to_emulated_env
cd visualize
docker compose down
```

デモシステムを停止します。

```bash
cd playground
docker compose down
```
