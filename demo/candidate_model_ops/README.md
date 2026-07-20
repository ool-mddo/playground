# candidate_model_ops (運用者の試行錯誤をモデル操作で実現する)

## Main scenario

* [デモ環境](./doc/abstract.md)
* ユースケース (デモシナリオ)
  * [デモ操作手順](./doc/operation.md)
  * [(単一AS)複数リージョントラフィック制御](./doc/multi_region_te/introduction.md)
  * [複数ASトラフィック制御](./doc/multi_src_as_te/introduction.md)
* 拡張ユースケース(デモシナリオ)
  * [過去障害の再現とトポロジ手動操作](./doc/manual_steps/introduction.md)
    * デモ操作手順
      * [All cRPD](doc/manual_steps/operation_all_crpd.md)
      * [SR-SIM](doc/manual_steps/operation_srsim.md)
      * [cJunosEvo](doc/manual_steps/operation_cjunosevo.md)
    * [実装・設計](doc/manual_steps/tech_design.md)

## Related info

システム構成については[環境セットアップ(ワーカー分離)](../../doc/provision_workers.md)を参照してください。
