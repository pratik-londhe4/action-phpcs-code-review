#!/usr/bin/env bash

message=$(cat << "EOF"
PHPCS Code Review - GitHub Action by
      _    ____
 _ __| |_ / ___|__ _ _ __ ___  _ __
| '__| __| |   / _` | '_ ` _ \| '_ \
| |  | |_| |__| (_| | | | | | | |_) |
|_|   \__|\____\__,_|_| |_| |_| .__/
                              |_|
EOF
)

echo -e "\e[0;32m\n$message\n\e[0m"

# If token are not set, exit with error.
if [[ -z "$GH_BOT_TOKEN" ]] && [[ -z "$VAULT_TOKEN" ]]; then
  echo $( echo -en "\033[31mERROR\033[0m: Secret GH_BOT_TOKEN or VAULT_TOKEN is missing. Please add it to this action for proper execution. \nRefer https://github.com/rtCamp/action-phpcs-code-review#github-token-creation for more information." )

  exit 1
fi

main_script="/usr/local/bin/main.sh"
custom_path="$GITHUB_WORKSPACE/.github/inspections/vip-go-ci/"

if [[ -d "$custom_path" ]]; then
    rsync -a "$custom_path" /usr/local/bin/
fi

bash "$main_script" "$@"
