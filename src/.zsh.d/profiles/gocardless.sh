MBF_PLUGINS+=(
  asdf
  ruby
  node
  python
  golang
)

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/usr/local/opt/google-cloud-sdk/path.zsh.inc' ]; then . '/usr/local/opt/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/usr/local/opt/google-cloud-sdk/completion.zsh.inc' ]; then . '/usr/local/opt/google-cloud-sdk/completion.zsh.inc'; fi

function setup_draupnir() {
  spring stop
  if [ -n "$1" ]; then
    echo "Using instance $1"
    eval $(draupnir env $1)
  else
    echo "Using new instance"
    eval $(draupnir new)
  fi

  local remote=$(git remote get-url origin)
  if [[ $remote =~ 'payments-service' ]]; then
    export PGDATABASE=gc_paysvc_live PGDATABASE_REPLICA=gc_paysvc_live
  fi
  if [[ $remote =~ 'frontier' ]]; then
    export PGDATABASE=gc_banking_integrations_live
  fi
  if [[ $remote =~ 'nexus' ]]; then
    export PGDATABASE=gc_nexus_live
  fi

  echo "Using $PGDATABASE - disabling spring"
  export DISABLE_SPRING=true
}

function cleanup_draupnir() {
  unset PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE PGSSLMODE PGSSLROOTCERT PGSSLCERT PGSSLKEY
  for i in $(draupnir instances list | cut -d" " -f1); do draupnir instances destroy $i; done
}
