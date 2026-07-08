{
  # minimal テンプレート — devShell と direnv のみ。
  # 単独ツール・単独リポジトリ向け。agent-context-maintainer / hive / cube は同梱しない。
  # .mcp.json も持たない。自己完結（nixpkgs 直接参照・forAllSystems）。
  description = "agent-native product template (minimal)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
            "aarch64-darwin"
            "x86_64-darwin"
          ]
          (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # Tier 1: 全テンプレート共通コア。
          # minimal は単一情報源 agent-tools.nix を持たず、ここに Tier 1 をインラインする。
          packages = with pkgs; [
            ripgrep # コード検索（rg）
            fd # ファイル検索
            jq # JSON 処理
            yq-go # YAML/TOML 処理
            sd # 文字列置換（sed 代替）
            tree # 構造把握
            git # バージョン管理
            gh # GitHub 操作
            just # タスクランナー
            curl # HTTP
            shellcheck # シェル lint
            shfmt # シェル整形
            coreutils # 基本コマンド統一（BSD 差異排除）
            gnused # GNU sed
            gawk # GNU awk
            unzip # 展開
            zstd # 圧縮
            sqlite # DB 確認・デバッグ
            python311 # Python 層（3.11）
            uv # wheel 依存管理
          ];

          shellHook = ''
            # minimal は a-c-m 非同梱・bootstrap 不要のため、セットアップガードは適用しない。
            # （uv sync / agent-context 部分を持たない最小構成。）
            echo "ℹ subaco minimal devShell（Tier1 ツールのみ）"
          '';
        };
      });
    };
}
