# ルーティング（routing.md）

<!--
  .agents/routing.md — a-c-m 標準構造の最小雛形。
  タスク種別やコード領域ごとに、参照すべき文脈・プロファイル・担当を割り当てる。
  TODO(段階3): a-c-m の vendored copy 取得（scripts/vendor-acm.sh）後、
  実レイアウト・記法に合わせて調整する。
-->

## 領域と参照

| 領域 | 参照先 |
|---|---|
| 全般ポリシー（信頼・知識・実行プレーン） | `.agents/core.md` |
| 役割別プロファイル | `.agents/profiles/` |
| リポジトリローカルスキル | `.agents/skills/` |
| チーム協業（メッセージ・記憶） | hive-mcp（`hive_post` / `hive_inbox` / `hive_remember` / `hive_recall`） |
| 未信頼コードの検証実行 | `scripts/sandbox_run.py`（cube-shim 経由） |

（TODO: プロジェクトの領域分割に応じて行を追記する。）
