#!/bin/bash

# Get variables defined in .env

source .env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

# Start

echo "[YESILCMS]: Removing old target directories..."
rm -r ./vol/yesilcms_github

echo "[YESILCMS]: Cloning github repositories..."
git clone $VMANGOS_GIT_SOURCE_YESILCMS ./vol/yesilcms_github/

echo "[YESILCMS]: YESILCMS data prepared."