if [[ -r /etc/profile ]]; then
  source /etc/profile
fi

__friendly_terminal_loaded_login_profile=0
for __friendly_terminal_profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
  if [[ -r "$__friendly_terminal_profile" ]]; then
    source "$__friendly_terminal_profile"
    __friendly_terminal_loaded_login_profile=1
    break
  fi
done
unset __friendly_terminal_profile

if [[ "$__friendly_terminal_loaded_login_profile" == "0" && -r "$HOME/.bashrc" ]]; then
  source "$HOME/.bashrc"
fi
unset __friendly_terminal_loaded_login_profile

__friendly_terminal_last_history_number=''

__friendly_terminal_encode_path() {
  local LC_ALL=C input=$1 out='' i ch byte
  for (( i = 0; i < ${#input}; i++ )); do
    ch=${input:i:1}
    case $ch in
      [A-Za-z0-9/_.~-]) out+=$ch ;;
      *) printf -v byte '%d' "'$ch"; printf -v ch '%%%02X' "$(( byte & 0xFF ))"; out+=$ch ;;
    esac
  done
  REPLY=$out
}

__friendly_terminal_precmd() {
  local exit_code=$?
  if [[ -z "$__friendly_terminal_last_history_number" ]]; then
    __friendly_terminal_last_history_number=${HISTCMD:-0}
  elif [[ "${HISTCMD:-0}" != "$__friendly_terminal_last_history_number" ]]; then
    local command_line
    local encoded_command
    command_line=$(HISTTIMEFORMAT= history 1 | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]*//')
    encoded_command=$(printf '%s' "$command_line" | base64 | tr -d '\n')
    printf '\e]633;E;%s\a' "$encoded_command"
    printf '\e]133;B\a\e]133;C\a\e]133;D;%d\a' "$exit_code"
    __friendly_terminal_last_history_number=${HISTCMD:-0}
  fi
  local REPLY
  __friendly_terminal_encode_path "$PWD"
  printf '\e]7;file://%s%s\a' "${HOSTNAME}" "$REPLY"
  printf '\e]133;A\a'
}

if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
  PROMPT_COMMAND=(__friendly_terminal_precmd "${PROMPT_COMMAND[@]}")
else
  PROMPT_COMMAND="__friendly_terminal_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi
