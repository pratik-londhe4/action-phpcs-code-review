#!/usr/bin/env bash

## Logging functions
# Arguments: Message.
error_message() {
  echo -en "\033[31mERROR\033[0m: $1"
}

warning_message() {
  echo -en "\033[33mWARNING\033[0m: $1"
}

info_message() {
  echo -en "\033[32mINFO\033[0m: $1"
}

# Check if the current branch is feature/add-plugin
if [[ "$(git rev-parse --abbrev-ref HEAD)" != "feature/add-plugin" ]]; then
  echo $(warning_message "This script is supposed to be run on the feature/add-plugin branch.")
  exit 0
fi

# VIP Go CI tools directory.
VIP_GO_CI_TOOLS_DIR="$ACTION_WORKDIR/vip-go-ci-tools"

# Setup GitHub workspace inside Docker container.
DOCKER_GITHUB_WORKSPACE="$ACTION_WORKDIR/workspace"

# Sync GitHub workspace to Docker GitHub workspace.
rsync -a "$GITHUB_WORKSPACE/" "$DOCKER_GITHUB_WORKSPACE"

echo $( info_message "DOCKER_GITHUB_WORKSPACE: $DOCKER_GITHUB_WORKSPACE" )

if [[ ! -d "$VIP_GO_CI_TOOLS_DIR" ]] || [[ ! -d "$DOCKER_GITHUB_WORKSPACE" ]]; then
  echo $( error_message "One or more of the following directories are not present: VIP_GO_CI_TOOLS_DIR, DOCKER_GITHUB_WORKSPACE" )
  exit 1
fi

################################################################################
#                    Configure options for vip-go-ci                           #
#                                                                              #
#   Refer https://github.com/Automattic/vip-go-ci#readme for more information  #
################################################################################

################################################################################
#                             General Configuration                            #
################################################################################

#######################################
# Set the --lint and --phpcs
# Default: true
# Options: BOOLEAN
#######################################
CMD=( "--lint=false" "--phpcs=true" )

################################################################################
#                            PHPCS configuration                               #
################################################################################

#######################################
# Set the --phpcs-php-path
# Default: PHP in $PATH
# Options: FILE (Path to php executable)
#######################################
if [[ -n "$PHPCS_PHP_VERSION" ]]; then
  if [[ -z "$( command -v php$PHPCS_PHP_VERSION )" ]]; then
    echo $( warning_message "php$PHPCS_PHP_VERSION is not available. Using default php runtime...." )
    phpcs_php_path=$( command -v php )
  else
    phpcs_php_path=$( command -v php$PHPCS_PHP_VERSION )
  fi

  CMD+=( "--phpcs-php-path=$phpcs_php_path" )
fi

#######################################
# Set the --phpcs-path
# Default: $VIP_GO_CI_TOOLS_DIR/phpcs/bin/phpcs
# Options: FILE (Path to phpcs executable)
#######################################
phpcs_path="$VIP_GO_CI_TOOLS_DIR/phpcs/bin/phpcs"

if [[ -n "$PHPCS_FILE_PATH" ]]; then
  if [[ -f "$DOCKER_GITHUB_WORKSPACE/$PHPCS_FILE_PATH" ]]; then
    phpcs_path="$DOCKER_GITHUB_WORKSPACE/$PHPCS_FILE_PATH"
  else
    echo $( warning_message "$DOCKER_GITHUB_WORKSPACE/$PHPCS_FILE_PATH does not exist. Using default path...." )
  fi
fi

CMD+=( "--phpcs-path=$phpcs_path" )

#######################################
# Set the --phpcs-standard
# Default: WordPress
# Options: STRING (Comma separated list of standards to check against)
#
#  1. Either a comma separated list of standards to check against.
#  2. Or a path to a custom ruleset.
#######################################
phpcs_standard=''

defaultFiles=(
  '.phpcs.xml'
  'phpcs.xml'
  '.phpcs.xml.dist'
  'phpcs.xml.dist'
)

phpcsfilefound=1

for phpcsfile in "${defaultFiles[@]}"; do
  if [[ -f "$DOCKER_GITHUB_WORKSPACE/$phpcsfile" ]]; then
    phpcs_standard="$DOCKER_GITHUB_WORKSPACE/$phpcsfile"
    phpcsfilefound=0
  fi
done

if [[ $phpcsfilefound -ne 0 ]]; then
  if [[ -n "$1" ]]; then
    phpcs_standard="$1"
  else
    phpcs_standard="WordPress"
  fi
fi

if [[ -n "$PHPCS_STANDARD_FILE_NAME" ]] && [[ -f "$DOCKER_GITHUB_WORKSPACE/$PHPCS_STANDARD_FILE_NAME" ]]; then
  phpcs_standard="$DOCKER_GITHUB_WORKSPACE/$PHPCS_STANDARD_FILE_NAME"
fi;

CMD+=( "--phpcs-standard=$phpcs_standard" )

#######################################
# Set the --phpcs-standards-to-ignore
# Default: PHPCSUtils
# Options:String (Comma separated list of standards to ignore)
#######################################
if [[ -n "$PHPCS_STANDARDS_TO_IGNORE" ]]; then
  CMD+=( "--phpcs-standards-to-ignore=$PHPCS_STANDARDS_TO_IGNORE" )
else
  CMD+=( "--phpcs-standards-to-ignore=PHPCSUtils" )
fi

#######################################
# Set the --phpcs-skip-scanning-via-labels-allowed
# Default: true
# Options: BOOLEAN
#######################################
CMD+=( "--phpcs-skip-scanning-via-labels-allowed=true" )

#######################################
# Set the --phpcs-skip-folders
# Options: STRING (Comma separated list of folders to skip)
#######################################
if [[ -n "$SKIP_FOLDERS" ]]; then
  CMD+=( "--phpcs-skip-folders=$SKIP_FOLDERS" )
fi

#######################################
# Set the --phpcs-sniffs-exclude
# Default: ''
# Options: STRING (Comma separated list of sniffs to exclude)
#######################################
if [[ -n "$PHPCS_SNIFFS_EXCLUDE" ]]; then
  CMD+=( "--phpcs-sniffs-exclude=$PHPCS_SNIFFS_EXCLUDE" )
fi

#######################################
# Set the --phpcs-skip-folders-in-repo-options-file
# Default: If .vipgoci_phpcs_skip_folders file exists in the repo, then true.
#######################################
if [[ -f "$DOCKER_GITHUB_WORKSPACE/.vipgoci_phpcs_skip_folders" ]]; then
  CMD+=( "--phpcs-skip-folders-in-repo-options-file=true" )
fi

################################################################################
#                Start Code Review and set GH build status                     #
################################################################################

echo $( info_message "Running PHPCS inspection..." )
echo $( info_message "Command: $VIP_GO_CI_TOOLS_DIR/vip-go-ci/vip-go-ci.php ${CMD[*]}" )

PHPCS_CMD=( php "$VIP_GO_CI_TOOLS_DIR/vip-go-ci/vip-go-ci.php" "${CMD[@]}" )

"${PHPCS_CMD[@]}"
