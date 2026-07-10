__friendly_terminal_wrapper_zdotdir=$ZDOTDIR
ZDOTDIR=$FRIENDLY_TERMINAL_USER_ZDOTDIR
if [[ -r "$ZDOTDIR/.zlogin" ]]; then
  source "$ZDOTDIR/.zlogin"
fi
ZDOTDIR=$__friendly_terminal_wrapper_zdotdir
unset __friendly_terminal_wrapper_zdotdir
