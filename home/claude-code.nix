{ pkgs, ... }:

let
  statusline = pkgs.runCommandLocal "claude-statusline"
    { nativeBuildInputs = [ pkgs.makeWrapper ]; }
    ''
      install -Dm755 ${./statusline.sh} $out/bin/claude-statusline
      wrapProgram $out/bin/claude-statusline \
        --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [ bash coreutils gnugrep gawk bc jq git ])}
    '';
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    settings = {
      permissions = {
        defaultMode = "acceptEdits";
        allow = [
          "Bash(sudo nixos-rebuild*)"
          "Bash(nix *)"
          "Bash(nix-*)"
          "Bash(nixos-option*)"
          "Bash(sudo nix*)"
          "Bash(git *)"
          "Bash(systemctl status*)"
          "Bash(systemctl list-units*)"
          "Bash(journalctl*)"
          "Bash(ls *)"
          "Bash(find *)"
          "Bash(grep *)"
          "Bash(df *)"
          "Bash(free *)"
          "Bash(ip *)"
          "Bash(ss *)"
          "Bash(ps *)"
        ];
        deny = [
          "Read(./.env)"
          "Read(./.env.*)"
          "Read(./secrets/**)"
        ];
      };

      theme = "dark";
      model = "opus";
      effortLevel = "high";
      advisorModel = "opus";

      skipAutoPermissionPrompt = true;
      skipDangerousModePermissionPrompt = true;
      skipWorkflowUsageWarning = true;

      env = {
        DISABLE_AUTOUPDATER = "1";
        ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4-8[1m]";
        CLAUDE_CODE_SUBAGENT_MODEL = "claude-sonnet-4-6";
        CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "50";
        ENABLE_PROMPT_CACHING_1H = "1";
        BASH_MAX_OUTPUT_LENGTH = "10000";
        MAX_MCP_OUTPUT_TOKENS = "10000";
        CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN = "1";
        CLAUDE_CODE_DISABLE_MOUSE = "1";
      };

      statusLine = {
        type = "command";
        command = "${statusline}/bin/claude-statusline";
        padding = 0;
        refreshInterval = 10;
      };
    };
  };
}
