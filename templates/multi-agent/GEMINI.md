<!-- agent-context-maintainer:begin -->
# Gemini CLI 向け指示（ブリッジ）

本プロジェクトのエージェント向け指示の**正本は [AGENTS.md](./AGENTS.md)** です。
Gemini CLI は本ファイルを読み込みますが、指示内容は AGENTS.md に一元化しています。
作業前に必ず [AGENTS.md](./AGENTS.md) と [.agents/core.md](./.agents/core.md) を参照してください。

なお hive-mcp の登録は Gemini CLI 側のユーザーグローバル設定（`.gemini/settings.json` の `mcpServers`）で
行う必要があり、`.mcp.json`（Claude Code 規約）は読まれません。登録雛形は runbook を参照。

<!--
  このブリッジは agent-context-maintainer が管理します。手で編集しないでください。
  TODO(段階3): 実際の a-c-m マーカー書式は vendor 取得（scripts/vendor-acm.sh）時に確定・照合する。
-->
<!-- agent-context-maintainer:end -->
