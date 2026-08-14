# ルーティング（routing.md）

<!--
  .agents/routing.md — タスク種別やコード領域ごとに、参照すべき文脈・プロファイル・担当を
  割り当てる（手書き領域）。bootstrap の `agent-context scaffold --append-generated-block` が
  a-c-m の管理ブロック（Universal First Reads / Task Routes 等）を末尾に追記する。
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
