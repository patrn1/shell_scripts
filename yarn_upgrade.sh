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
# Array to keep track of packages we have already updated in this run
# to prevent infinite recursion loops.
declare -a UPDATED_PACKAGES=()
# Function to check if array contains element
containsElement() {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}
upgrade_recursive() {
    local target_short_name=$1
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
    # 1. Identify if this package depends on the target
    # We look for exact match OR match ending in /target_name (to handle @scope/name)
    # We extract the Full Key (e.g., @myorg/aaa) and the URL value
    echo "JQ # 444"
    dependency_info=$(jq -r --arg target "$target_short_name" '
    .dependencies // empty | to_entries[] |
    select(.key == $target or (.key | tostring | endswith("/" + $target))) |
    "\(.key)|\(.value)"
    ' "$package_json")
    # If dependency_info is not empty, we found a match
    if [ ! -z "$dependency_info" ]; then
    # Split the info into Name and URL
    full_dep_name=$(echo "$dependency_info" | cut -d'|' -f1)
    dep_url=$(echo "$dependency_info" | cut -d'|' -f2)
    # Get the name of the CURRENT package (the one we are about to update)
    echo "JQ # 111"
    current_pkg_name=$(jq -r '.name' "$package_json")
    updated_packages_key="$full_dep_name|$current_pkg_name"
    # Check if we already processed this specific package to avoid loops
    if containsElement "$updated_packages_key" "${UPDATED_PACKAGES[@]}"; then
    echo " Skipping $dirname (already updated in this chain)."
    continue
    fi
    echo " Found dependent: $dirname ($current_pkg_name)"
    echo " -> Depends on: $full_dep_name"
    echo " -> Update Source: $dep_url"
    # 2. Perform the Upgrade
    # We use a subshell (parentheses) so directory changes don't affect the main loop
    (
    cd "$dir" || exit

    if [ ! -f "./.yarnrc.yml" ]; then
        yarn set version berry
        echo "nodeLinker: node-modules" > .yarnrc.yml
    fi

    echo " Executing yarn up in $dirname..."

    git restore --staged .

    # Yarn 2 Up command
    ############ yarn up "${full_dep_name}@${dep_url}"

    yarn_up_log="$(yarn up ${full_dep_name}@${dep_url})"

    echo "yarn_up_log" "$yarn_up_log"

    package_not_found="$(echo $yarn_up_log | grep 't seem to be present in your lockfile')"

    if [ -n "$package_not_found" ]; then

        yarn install;

    fi 

    has_yarn_update="$(git status | grep yarn.lock)"
    has_package_update="$(git status | grep package.json)"

    git add ./.yarn
    git add ./yarn.lock
    git add ./package.json
    git add ./.yarnrc.yml

    branch_is_ahead="$(git commit -m UPG_${full_dep_name} 2>&1 | grep 'Your branch is ahead of' | tr -d '\n')"

    if [ -n "$git_configure_path" ]; then

        $git_configure_path;

    fi

    if [[ -n "$has_yarn_update" || -n "$has_package_update" || -n "$branch_is_ahead" ]]; then

        echo "Do GIT PUSH @ ${dirname}"

        read -r -p "Press Enter to continue..."
    else
        # # Mark as updated
        UPDATED_PACKAGES+=($updated_packages_key)
    fi

    )

    # # Mark as updated
    # UPDATED_PACKAGES+=("$current_pkg_name")
    # 3. Recursive Step
    # Prepare the next target name.
    # If current package is @vendor/abc, we pass 'abc' to the next recursion.
    # Remove scope (everything before and including /)
    next_target_short_name="${current_pkg_name##*/}"
    echo " Propagating update downstream for '$next_target_short_name'..."
    # RECURSIVE CALL
    upgrade_recursive "$next_target_short_name"
    fi
    done
}
# Start the process
upgrade_recursive "$TARGET_ARG"
echo "---------------------------------------------------------"
echo " Chain upgrade complete."
