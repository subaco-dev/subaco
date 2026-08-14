# __PROJECT_NAME__

エージェント・ネイティブ開発リポジトリ（standard テンプレート）。
本ファイルはマルチベンダーのエージェント（Claude Code / Codex / Gemini CLI / Copilot / 人間）が
最初に読む指示の**正本**です。CLAUDE.md / GEMINI.md / .github/copilot-instructions.md は
本ファイルへのブリッジであり、指示は本ファイルに一元化しています。

<!--
  下の begin/end 区間は agent-context-maintainer が生成・管理する（bootstrap の
  `agent-context scaffold --append-generated-block` が更新。手で編集しない）。
  区間外の手書きセクション（利用可能ツール・知識プレーン・アーキテクチャ原則 等）は
  a-c-m が保全する。
-->
<!-- agent-context-maintainer:begin -->
## Agent Context Entry

Always read these files before making repository changes:

1. `.agents/core.md`
2. `.agents/routing.md`
3. The matching provider profile in `.agents/profiles/`; if unsure, read `.agents/profiles/generic.md`

If `.agents/routing.md` routes the task to a skill, read that `SKILL.md` before editing.
<!-- agent-context-maintainer:end -->

## 利用可能ツール

<!--
  手書き（ポインタのみ）。一覧の正本は .agents/tools.md —— scripts/gen-tool-list.py が
  agent-tools.nix から生成する（`just gen-tools` で再生成・`just gen-tools-check` で乖離検査）。
  a-c-m は断片を AGENTS.md へインライン展開しないため、本セクションには一覧を書かず
  参照だけを置く（flake との乖離を構造的に防ぐ）。
-->

devShell（`direnv allow` で有効化）で使えるツールの一覧と用途・推奨慣行は
[.agents/tools.md](.agents/tools.md) を参照。要点: 検索は `grep` ではなく `rg`、
ファイル検索は `fd`、置換は `sd`、タスク実行は `just`（`just test` / `just lint`）を第一候補にする。

## 知識プレーン

<!-- 手書き。詳細な慣行は .agents/core.md（知識プレーンの使い分け）を参照。 -->

- 依存 OSS（公開リポジトリ）の構造は **DeepWiki MCP に ask** する（clone より先に）。
- 自リポジトリの構造把握は `.agents/` と `tree` / `ast-grep` を基本とする。
- **プライベートコードに関する質問を公開 MCP（DeepWiki）へ送らない**（質問文自体が漏洩経路）。

詳細な行動ポリシーは [.agents/core.md](.agents/core.md) を参照。

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
