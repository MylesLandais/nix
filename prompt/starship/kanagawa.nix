{
  scan_timeout = 10;
  add_newline = false;
  line_break.disabled = false;
  format = ''
    $symbol[ ](bold #658594)$username$git_branch$kubernetes
    $directory$character
  '';
  # format = "$symbol[󰉊 ](bold #ee5396) $directory$character
  right_format = "$cmd_duration$time";
  character = {
    success_symbol = "[󰅂 ](bold #658594)";
    error_symbol = "[󰅂 ](bold #E82424)";
    vicmd_symbol = "[< ](bold #658594)";
  };

  username = {
    show_always = true;
    style_user = "bold bg:none fg:#658594";
    format = "[$user]($style)";
  };

  hostname = {
    disabled = true;
    ssh_only = false;
    style = "bold bg:none fg:#658594";
    format = "@[$hostname]($style) ";
  };

  directory = {
    read_only = " r";
    truncation_length = 3;
    truncation_symbol = "./";
    style = "bold bg:none fg:#658594";
  };

  git_branch = {
    format = " on [$symbol$branch(:$remote_branch)]($style) ";
    symbol = " ";
    style = "bold #658594";
  };

  time = {
    disabled = false;
    use_12hr = true;
    time_range = "-";
    time_format = "%R";
    utc_time_offset = "local";
    format = "[ $time 󰥔]($style) ";
    style = "bold #2D4F67";
  };

  nix_shell = {
    disabled = false;
    heuristic = false;
    impure_msg = "[impure-shell](red)";
    pure_msg = "[pure-shell](green)";
    unknown_msg = "[unknown-shell](yellow)";
  };
  kubernetes = {
    disabled = false;
    format = "[$symbol$context( ($namespace))]($style) in ";
    style = "bold #43242B";
    symbol = "󱃾 ";
  };
  direnv = {
    description = "Show '.envrc' when using a direnv environment";
    when = ''[ "$DIRENV_DIR" != "" ] && [ "$IN_NIX_SHELL" != "" ]'';
    shell = [
      "bash"
      "--noprofile"
      "--norc"
    ];
    style = "italic #DCA561";
    format = "[via](italic #E82424) [.envrc]($style)";
  };

  cmd_duration = {
    min_time = 2000;
    show_milliseconds = false;
    format = "took [$duration]($style)";
    style = "bold yellow";
    disabled = false;
  };
}
