__friendly_terminal_wrapper_zdotdir=$ZDOTDIR
ZDOTDIR=$FRIENDLY_TERMINAL_USER_ZDOTDIR
if [[ -r "$ZDOTDIR/.zshrc" ]]; then
  source "$ZDOTDIR/.zshrc"
fi
if [[ -n "$HISTFILE" && "$HISTFILE" == "$__friendly_terminal_wrapper_zdotdir/"* ]]; then
  HISTFILE="$FRIENDLY_TERMINAL_USER_ZDOTDIR/${HISTFILE#"$__friendly_terminal_wrapper_zdotdir/"}"
elif [[ -n "$HISTFILE" && "$HISTFILE" != /* ]]; then
  HISTFILE="$FRIENDLY_TERMINAL_USER_ZDOTDIR/$HISTFILE"
fi
ZDOTDIR=$__friendly_terminal_wrapper_zdotdir
unset __friendly_terminal_wrapper_zdotdir

autoload -Uz add-zsh-hook
typeset -g __friendly_terminal_command_running=0

__friendly_terminal_preexec() {
  local encoded_command
  encoded_command=$(printf '%s' "$1" | base64 | tr -d '\n')
  printf '\e]633;E;%s\a' "$encoded_command"
  printf '\e]133;B\a\e]133;C\a'
  __friendly_terminal_command_running=1
}

__friendly_terminal_precmd() {
  local exit_code=$?
  if (( __friendly_terminal_command_running )); then
    printf '\e]133;D;%d\a' "$exit_code"
    __friendly_terminal_command_running=0
  fi
  printf '\e]7;file://%s%s\a' "$HOST" "$PWD"
  printf '\e]133;A\a'
}

add-zsh-hook preexec __friendly_terminal_preexec
add-zsh-hook precmd __friendly_terminal_precmd
