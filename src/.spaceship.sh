SPACESHIP_PROMPT_ADD_NEWLINE="false"
SPACESHIP_GIT_STATUS_COLOR="yellow"

SPACESHIP_PROMPT_ORDER=(
  dir
  git
  awsauth
  exec_time
  line_sep
  jobs
  exit_code
  char
)

SPACESHIP_AWSAUTH_SHOW="${SPACESHIP_AWSAUTH_SHOW=true}"
SPACESHIP_AWSAUTH_PREFIX="${SPACESHIP_AWSAUTH_PREFIX="$SPACESHIP_PROMPT_DEFAULT_PREFIX"}"
SPACESHIP_AWSAUTH_SUFFIX="${SPACESHIP_AWSAUTH_SUFFIX="$SPACESHIP_PROMPT_DEFAULT_SUFFIX"}"
SPACESHIP_AWSAUTH_SYMBOL="${SPACESHIP_AWSAUTH_SYMBOL="🚀"}"
SPACESHIP_AWSAUTH_COLOR="${SPACESHIP_AWSAUTH_COLOR="white"}"

spaceship_awsauth() {
    [[ -n "$AWS_ROLE_IDENTIFIER" ]] || return

    local role=${AWS_ROLE_IDENTIFIER##*/}

    spaceship::section \
        "$SPACESHIP_AWSAUTH_COLOR" \
        "$SPACESHIP_AWSAUTH_PREFIX" \
        "$SPACESHIP_AWSAUTH_SYMBOL $role" \
        "$SPACESHIP_AWSAUTH_SUFFIX"
}

function awsauth { bash $HOME/.aws/auth.sh "$@"; [[ -r "$HOME/.aws/sessiontoken" ]] && . "$HOME/.aws/sessiontoken"; }
