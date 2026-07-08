# agent-tools.nix — devShell と AGENTS.md 生成の単一情報源。
#
# devShell の packages と「## 利用可能ツール」セクション生成スクリプトは、
# 双方このリストを参照する。ツールの増減はここ一箇所で行い、flake とエージェント指示の
# 乖離を構造的に防ぐ。
{ pkgs }:
{
  # Tier 1: 全テンプレート共通コア。
  tier1 = with pkgs; [
    ripgrep # コード検索（rg）
    fd # ファイル検索
    jq # JSON 処理
    yq-go # YAML/TOML 処理
    sd # 文字列置換（sed 代替）
    tree # 構造把握
    git # バージョン管理
    gh # GitHub 操作（--json 出力）
    just # タスクランナー
    curl # HTTP
    shellcheck # シェル lint
    shfmt # シェル整形
    coreutils # 基本コマンド統一（BSD 差異排除）
    gnused # GNU sed
    gawk # GNU awk
    unzip # 展開
    zstd # 圧縮
    sqlite # hive のデータ確認・デバッグ
    python311 # a-c-m 実行・Python 層（3.11）
    uv # wheel 依存管理
  ];

  # Tier 2: standard 以上に追加。
  tier2 = with pkgs; [
    ast-grep # 構文木ベース検索・書換
    watchexec # ファイル監視実行
    delta # diff 表示（人間レビュー用）
    hyperfine # ベンチマーク
    tokei # コード統計
    jc # コマンド出力の JSON 化
    nixfmt-rfc-style # Nix フォーマッタ
    statix # Nix lint
    nil # Nix LSP
    typos # スペルチェック
  ];
}
