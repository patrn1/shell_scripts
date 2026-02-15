#!/bin/bash
# set -e
#
###############################################################
# NPM/Yarn recursive upgrader
# Usage: ./upgrade_packages.sh <package_name_without_scope>
# Example: ./upgrade_packages.sh my-utils
#
###############################################################
TARGET_ARG=$1
TARGET_ARG=${TARGET_ARG#./}
TARGET_ARG=${TARGET_ARG%/}

if [ -z "$(git config --global user.email)" ]; then
  echo "Error: Please set your email in the Git config."
  exit 1
fi

if [ -z "$TARGET_ARG" ]; then
  echo "Error: Please provide a package name (without vendor/scope)."
  echo "Usage: $0 <package_name>"
  exit 1
fi
# Check for jq
echo "JQ # 222"
if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' is not installed. Please install it to use this script."
  exit 1
fi
# Root directory is the current directory
ROOT_DIR=$(pwd)
git_configure_path=$(command -v git-configure)
# has_updates=TRUE
# Array to keep track of packages we have already updated in this run
# to prevent infinite recursion loops.
# declare -a UPDATED_PACKAGES=()
declare -a POSTPONE_UPDATE=()
# Function to check if array contains element
containsElement() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}
wait_for_push() {

  local _dirname=$1

  echo "Do GIT PUSH @ ${_dirname}"

  read -r -p "Press Enter to continue..."

}
get_package_deps() {

  local _package_name=$1

  for _dir in "$ROOT_DIR"/*/; do
    # Remove trailing slash
    _dir=${_dir%*/}
    # Get just the folder name
    dirname=${_dir##*/}
    local _package_json="$_dir/package.json"
    # Check if package.json exists
    if [ ! -f "$_package_json" ]; then
        continue
    fi
    current_pkg_name=$(jq -r '.name' "$_package_json")

    if [ "$_package_name" == "$current_pkg_name" ]; then
        get_dependencies "$target_short_name" "$_package_json"
        break
    fi

  done
}
get_dependencies() {

  local _target_short_name=$1
  local _package_json=$2

  jq -r --arg target "$_target_short_name" '
  .dependencies // empty | to_entries[] |
  select(.key == $target or (.key | tostring | endswith("/" + $target))) |
  "\(.key)|\(.value)"
  ' "$_package_json"
}
get_package_name() {

  local _package_json=$1

  _current_pkg_name=$(jq -r '.name' "$_package_json")

  echo "${_current_pkg_name##*/}"
}
del_yarn_package_setting() {
  local _dirname=$1

  (jq 'del(.packageManager)' "${_dirname}/package.json" > tmp.json) && mv -f tmp.json "${_dirname}/package.json"

}
check_package_refs() {

  local _package_name=$1

  for _dir in "$ROOT_DIR"/*/; do
    # Remove trailing slash
    _dir=${_dir%*/}
    # Get just the folder name
    dirname=${_dir##*/}
    local _package_json="$_dir/package.json"
    # Check if package.json exists
    if [ ! -f "$_package_json" ]; then
        continue
    fi

    current_pkg_name=$(jq -r '.name' "$_package_json")

    deps=$(get_dependencies "$_package_name" "$_package_json")

    if [ -n "$deps" ]; then
        echo "$current_pkg_name"
        break
    fi

  done
}
upgrade_recursive() {
  local target_short_name=$1

  # if [ -z "$has_updates" ]; then

  #   return 0

  # fi

  # has_updates=

  echo "---------------------------------------------------------"
  echo " Looking for local packages depending on: '$target_short_name'..."
  # Iterate over all directories in the root folder
  for dir in "$ROOT_DIR"/*/; do
    # Remove trailing slash
    dir=${dir%*/}
    # Get just the folder name
    dirname=${dir##*/}
    local package_json="$dir/package.json"
    # Check if package.json exists
    if [ ! -f "$package_json" ]; then
        continue
    fi

    ############################
    ############################

    rm .pnp.* &> /dev/null;

    ############################ PACKAGE MANAGER
    ############################

    del_yarn_package_setting "$dir";

    # 1. Identify if this package depends on the target
    # We look for exact match OR match ending in /target_name (to handle @scope/name)
    # We extract the Full Key (e.g., @myorg/aaa) and the URL value
    echo "JQ # 444"
    dependency_info=$(get_dependencies "$target_short_name" "$package_json")

    # If dependency_info is not empty, we found a match
    if [ -n "$dependency_info" ]; then
    # Split the info into Name and URL
    full_dep_name=$(echo "$dependency_info" | cut -d'|' -f1)
    dep_url=$(echo "$dependency_info" | cut -d'|' -f2)
    # Get the name of the CURRENT package (the one we are about to update)
    echo "JQ # 111"
    current_pkg_name=$(jq -r '.name' "$package_json")

    continue_recursion=$(check_package_refs "$current_pkg_name")

    # updated_packages_key="$full_dep_name|$current_pkg_name"
    # Check if we already processed this specific package to avoid loops
    # if containsElement "$updated_packages_key" "${UPDATED_PACKAGES[@]}"; then
    # echo " Skipping $dirname (already updated in this chain)."
    # continue
    # fi
    echo " Found dependent: $dirname ($current_pkg_name)"
    echo " -> Depends on: $full_dep_name"
    echo " -> Update Source: $dep_url"
    # 2. Perform the Upgrade
    # We use a subshell (parentheses) so directory changes don't affect the main loop

    pushd "$dir" > /dev/null || exit

    ############################ YARN 2
    ############################
    # if [ ! -f "./.yarnrc.yml" ]; then
    #     yarn set version berry
    #     echo "nodeLinker: node-modules" > .yarnrc.yml
    # fi
    ############################ 
    ############################ 

    ############################ YARN 1
    ############################

    if [ -f "./.yarnrc.yml" ]; then

      rm -rf .yarn

      rm .yarnrc.yml

      # yarn set version 1.22.1

      yarn install

    fi

    ############################ 
    ############################ 

    if [ -f "./yarn.lock" ]; then

      rm -rf .yarn

      rm -rf yarn.lock

      npm install

    fi

    git restore --staged .

    ############################ 
    # YARN - UPDATE
    ############################ 

    ## echo " Executing yarn up in $dirname..."

    # Yarn 2 Up command
    ############ yarn up "${full_dep_name}@${dep_url}"

    ## yarn_version=$(yarn --version)

    ## if [[ $yarn_version == 1.* ]]; then
    ##     # Yarn 1 (Classic) – use 'yarn add'
    ##     yarn_up_log="$(yarn upgrade "${dep_url}")"
    ## else
    ##     # Yarn 2+ (Berry) – use 'yarn up'
    ##     yarn_up_log="$(yarn up "${full_dep_name}@${dep_url}")"
    ## fi

    ## echo "yarn_up_log" "$yarn_up_log"

    ##package_not_found="$(echo $yarn_up_log | grep 't seem to be present in your lockfile')"

    ##if [ -n "$package_not_found" ]; then
    ##
    ##    yarn install;
    ##
    ##fi 

    ############################ 
    # NPM - UPDATE
    ############################

    echo " Executing npm update ${full_dep_name} in $dirname..."

    npm_upd_log_errors=$(npm update "${full_dep_name}" 2>&1 | grep -i error)

    if [ -n "$npm_upd_log_errors" ]; then
      echo "$npm_upd_log_errors"
      exit 1
    fi

    ############################ 
    ############################ 

    git add ./.yarn
    git add ./yarn.lock
    git add ./package.json
    git add ./.yarnrc.yml
    git add ./package-lock.json

    ############################ 
    ############################ 

    git commit -m "UPG_${full_dep_name}" 2> /dev/null; 

    if [ -n "$git_configure_path" ]; then

        $git_configure_path;

    fi

    has_any_updates() {

        has_npm_update="$(git status | grep package-lock.json)"
        has_yarn_update="$(git status | grep yarn.lock)"
        has_package_update="$(git status | grep package.json)"

        branch_is_ahead="$(git status | grep 'Your branch is ahead of' | tr -d '\n')"

        [[ -n "$has_npm_update" || -n "$has_yarn_update" || -n "$has_package_update" || -n "$branch_is_ahead" ]]
    }

    was_updated=$(has_any_updates)

    if [[ -z "${continue_recursion//[[:space:]]/}" ]]; then

      if $was_updated; then

        if ! containsElement "$dirname" "${POSTPONE_UPDATE[@]}"; then
          
          POSTPONE_UPDATE+=("$dirname")

        fi

      fi

    else
        # if has_any_updates; then

        #     echo "DEPS $dependency_info" 

        #     wait_for_push "$dirname"

        # # else
        # #     # # Mark as updated
        # #     UPDATED_PACKAGES+=("$updated_packages_key")
        # fi

        while has_any_updates
        do

            echo "DEPS $dependency_info" 

            wait_for_push "$dirname"

        done
    fi

    # if has_any_updates; then

    #   if [ -z "$has_updates" ]; then

    #     has_updates=TRUE

    #   fi

    # fi

    popd > /dev/null;

    # # Mark as updated
    # UPDATED_PACKAGES+=("$current_pkg_name")
    # 3. Recursive Step
    # Prepare the next target name.
    # If current package is @vendor/abc, we pass 'abc' to the next recursion.
    # Remove scope (everything before and including /)

    if $was_updated; then

      next_target_short_name="${current_pkg_name##*/}"
      echo " Propagating update downstream for '$next_target_short_name'..."
      # RECURSIVE CALL
      upgrade_recursive "$next_target_short_name"

    fi
    fi
  done
}
# Start the process
upgrade_recursive "$TARGET_ARG"

# echo "#### ${POSTPONE_UPDATE}"

for dirname in "${POSTPONE_UPDATE[@]}"; do

    wait_for_push "${dirname}"

done

echo "---------------------------------------------------------"
echo " Chain upgrade complete."
