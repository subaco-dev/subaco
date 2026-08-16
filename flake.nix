{
  # Subaco — AIエージェント・ネイティブ開発環境ボイラープレートエンジン。
  # 本 flake は 3 種のテンプレート（minimal / standard / multi-agent）を配布し、
  # あわせて subaco リポジトリ自身を編集するための devShell を提供する。
  description = "Subaco — agent-native product boilerplate（flake templates）";

  # nixpkgs は常に現行安定リリースへ追随する（5 月／11 月リリースに合わせて更新）。
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      # サポート対象の 4 システム（forAllSystems）。
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
      # flake templates 出力。利用者は次で新規プロダクトを開始する:
      #   nix flake init -t github:subaco-dev/subaco#standard
      # 各テンプレートは templates/<name>/ 配下に自己完結する（nixpkgs 直接参照）。
      templates = {
        minimal = {
          path = ./templates/minimal;
          description = "最小: devShell + direnv のみ（単独ツール／単独リポジトリ向け。.mcp.json なし）";
        };
        standard = {
          path = ./templates/standard;
          description = "標準: minimal + agent-context + CI + DeepWiki MCP";
        };
        multi-agent = {
          path = ./templates/multi-agent;
          description = "フル: standard + hive-mcp（メモリ）+ cube-shim（実行）";
        };
        # 既定は standard（クイックスタート例に一致）。
        default = self.templates.standard;
      };

      # subaco リポジトリ自身の開発 devShell。
      # テンプレートの .nix / .sh を触るのもエージェントであるため、Nix/シェルの整備道具を揃える。
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt-rfc-style # Nix フォーマッタ（RFC スタイル）
            nil # Nix LSP
            statix # Nix lint
            shellcheck # シェル lint（ラッパースクリプト検査）
            shfmt # シェル整形
            just # タスクランナー
          ];
        };
      });

      # `nix fmt` 用フォーマッタ。
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
