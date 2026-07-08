# __PROJECT_NAME__

エージェント・ネイティブ開発リポジトリ（standard テンプレート）。
本ファイルはマルチベンダーのエージェント（Claude Code / Codex / Gemini CLI / Copilot / 人間）が
最初に読む指示の**正本**です。CLAUDE.md / GEMINI.md / .github/copilot-instructions.md は
本ファイルへのブリッジであり、指示は本ファイルに一元化しています。

<!-- agent-context-maintainer:begin -->
<!--
  この begin/end で囲まれた領域は agent-context-maintainer が生成・管理します。
  手で編集しないでください（`agent-context scaffold` / `sync` で再生成されます）。
  領域外の手書きセクション（アーキテクチャ原則 等）は a-c-m が保全します。
  TODO(段階3): 実際の a-c-m マーカー書式は vendor 取得（scripts/vendor-acm.sh）時に確定・照合する。
-->

## 利用可能ツール

<!--
  本セクションの正本は scripts/gen-tool-list.py が agent-tools.nix から生成する
  a-c-m ソース断片 .agents/tools.md です（`just gen-tools` で再生成）。反映は
  agent-context scaffold/sync 経由でのみ行い、本ファイルを直接編集しません。
  以下は a-c-m の vendored copy 取得（scripts/vendor-acm.sh・段階3）前のプレースホルダで、
  sync 後は .agents/tools.md の内容へ置き換わります。
-->

devShell（`direnv allow` で有効化）で以下が利用可能です。慣行として、検索は `grep` ではなく `rg`、
ファイル検索は `fd`、置換は `sd`、タスク実行は `just`（`just test` / `just lint`）を第一候補にしてください。

- コード検索: `rg`（ripgrep） / 構文木ベースの検索・書換: `ast-grep`
- ファイル検索: `fd` / 構造把握: `tree`
- JSON/YAML/TOML: `jq` / `yq` / 文字列置換: `sd`
- タスクランナー: `just`（このリポジトリでの正しい操作を教示する）
- Git / GitHub: `git` / `gh`（`--json` 出力）
- 品質: `shellcheck` `shfmt` `statix` `nil` `typos`
- その他: `curl` `delta` `tokei` `hyperfine` `jc` `watchexec`

## 知識プレーン

- 依存 OSS（公開リポジトリ）の構造は **DeepWiki MCP に ask** する（clone より先に）。
- 自リポジトリの構造把握は本 `.agents/` と `tree` / `ast-grep` を基本とする。
- **プライベートコードに関する質問を公開 MCP（DeepWiki）へ送らない**（質問文自体が漏洩経路）。

詳細な行動ポリシーは [.agents/core.md](.agents/core.md) を参照。
<!-- agent-context-maintainer:end -->

## アーキテクチャ原則

<!-- 手書き（a-c-m 保全領域）。本リポジトリの設計上の約束事を記述してください。 -->

- （TODO: モジュール境界・依存方向・レイヤ原則など、プロジェクト固有の原則を記述する）

## レビュー方針

<!-- 手書き。 -->

- テスト・lint（`just test` / `just lint`）を必須とする。
- （TODO: レビュー観点・マージ条件など、プロジェクト固有の方針を記述する）

## 禁止事項

<!-- 手書き。 -->

- 資格情報・秘密情報をコミットしない。
- （TODO: プロジェクト固有の禁止事項を記述する）
