{ pkgs, ... }:

let
  # statusline 스크립트를 그대로 store 에 넣고 의존성을 래퍼 PATH 로 번들한다.
  # → 스크립트 내용은 그대로 사용, 의존성(jq/gawk/bc/git 등)은 self-contained.
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
    package = pkgs.claude-code; # 모듈이 바이너리 소유 (configuration.nix 에서는 제거)

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
        DISABLE_AUTOUPDATER = "1"; # nix 가 바이너리 소유 → 자동 업데이트 끔
        ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4-8[1m]";
        CLAUDE_CODE_SUBAGENT_MODEL = "claude-sonnet-4-6";
        CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "50";
        ENABLE_PROMPT_CACHING_1H = "1";
        BASH_MAX_OUTPUT_LENGTH = "10000";
        MAX_MCP_OUTPUT_TOKENS = "10000";
        # 스크롤 fix: fullscreen(alternate screen) 대신 네이티브 터미널 스크롤백 사용
        CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN = "1";
        CLAUDE_CODE_DISABLE_MOUSE = "1";
      };

      statusLine = {
        type = "command";
        command = "${statusline}/bin/claude-statusline";
        padding = 0;
        refreshInterval = 10; # 초 단위. 5h 리셋 타이머 등 주기 갱신
      };
    };

    # rules/agents/commands/hooks/skills 는 넣을 콘텐츠가 생기면 rulesDir 등으로 추가.
    # (존재하지 않는 디렉터리를 가리키면 빌드 실패하므로 지금은 미설정)
  };
}
