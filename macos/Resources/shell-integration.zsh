#!/usr/bin/env zsh

[[ -z "$FRIENDLYTERMINAL_INTEGRATION" ]] && return 0

_ft_osc() { printf "\e]%s\a" "$1"; }

_ft_prompt_start()   { _ft_osc "133;A"; }
_ft_prompt_end()     { _ft_osc "133;B"; }
_ft_output_start()   { _ft_osc "133;C"; }
_ft_command_end()    { _ft_osc "133;D;$1"; }

_ft_command_text()   { _ft_osc "633;E;$(printf '%s' "$1" | base64 | tr -d '\n')"; }

_ft_update_cwd() {
    local encoded_host
    encoded_host=$(hostname 2>/dev/null || echo "localhost")
    _ft_osc "7;file://${encoded_host}${PWD}"
}

_ft_precmd() {
    local exit_code=$?
    _ft_command_end "$exit_code"
    _ft_update_cwd
    _ft_prompt_start
}

_ft_preexec() {
    local cmd="$1"
    _ft_prompt_end
    _ft_command_text "$cmd"
    _ft_output_start
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd  _ft_precmd
add-zsh-hook preexec _ft_preexec

_ft_update_cwd
_ft_prompt_start
