#!/bin/bash
# set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO, exit code $?" >&2' ERR

###############################################################
# Remove a GitHub dependency by repository name
# Usage: ./remove_github_dep.sh <github_https_url_with_token>
###############################################################

usage() {
    echo "Usage: $0 <github_https_url_with_token>"
    echo "Extracts the repository name from the URL and removes"
    echo "that package from all subfolders that depend on it."
    exit 1
}

revert_changes() {
    git checkout HEAD ./.yarn &> /dev/null;
    git checkout HEAD ./yarn.lock &> /dev/null;
    git checkout HEAD ./package.json &> /dev/null;
    git checkout HEAD ./package-lock.json &> /dev/null;
}

wait_for_push() {

  local _dirname=$1

  echo "Do GIT PUSH @ ${_dirname}"

  read -r -p "Press Enter to continue..."

}

get_github_token() {

  local _url=$1

  echo "$_url" | grep -oP '.*?https://\K[^@]+(?=@github\.com)'

}

get_full_repo_name() {

    local _url=$1

    repo_path=$(echo "$_url" | grep -oP 'github\.com/\K[^/]+/[^/]+(?=\.git)')

    echo "$repo_path"

}

# ---------- Argument handling ----------
if [ $# -ne 1 ]; then
    usage
fi

URL="$1"

this_script_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Extract repository name from URL (last path component, strip optional .git)
repo_name=$(echo "$URL" | sed -E 's#^.*/([^/]+)(\.git)?$#\1#')
git_configure_path=$(command -v git-configure)
if [ -z "$repo_name" ]; then
    echo "Error: Could not extract repository name from URL: $URL"
    exit 1
fi

echo "Repository name: $repo_name"

# ---------- Required tools ----------
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it (e.g., 'apt install jq' or 'brew install jq')."
    exit 1
fi

if ! command -v yarn &> /dev/null; then
    echo "Error: 'yarn' is not installed. Please install it."
    exit 1
fi

# ---------- Main loop: iterate over immediate subdirectories ----------
for dir in */; do
    [ -d "$dir" ] || continue
    dir=${dir%/}                     # remove trailing slash
    package_json="$dir/package.json"

    if [ ! -f "$package_json" ]; then
        continue
    fi

    echo "---------------------------------------------------------"
    echo "Checking: $dir"

    ####################################
    ####################################

    # package_json="./package.json"
    # repo_name='supabase_service.git'

    matches=$(jq -r --arg target "$repo_name" '
        [
            .dependencies
            | select(. != null)
            | to_entries[]
            | select(
                .key == $target or 
                (.key | endswith("/" + $target)) or 
                (.value | strings | contains($target))
              )
            | .key
        ] | unique[]' "$package_json")

    ####################################
    ####################################

    if [ -n "$matches" ]; then
        echo "  Found package(s): $(echo $matches | tr '\n' ' ')"
        pushd "$dir" > /dev/null

        current_pkg_name=$(jq -r '.name' "$(pwd)/package.json")

        git config --global --unset http.proxy
        git config --global --unset https.proxy
        git config --global --unset core.gitProxy          # if you set a custom proxy executable
        git config --global --unset remote.origin.proxy    # rarely used, but check

        revert_changes

        NEW_TOKEN=$(get_github_token "$URL")

        REPO_PATH=$(get_full_repo_name "$URL")

        sed -i \
    -E "s|(https://)[^@]+(@github\.com/${REPO_PATH})|\1${NEW_TOKEN}\2|g" \
    "$(pwd)/package.json"

        sed -i \
    -E "s|(https://)[^@]+(@github\.com/${REPO_PATH})|\1${NEW_TOKEN}\2|g" \
    "$(pwd)/package-lock.json"

        for pkg in $matches; do

            ####################################
            # YARN - REMOVE
            ####################################

            ##echo "  Running: yarn remove $pkg"
            ## yarn remove "$pkg"

            ##if yarn add "$URL" > /dev/null 2>&1; then
            ##    echo 123 > /dev/null;
            ##else
            ##    echo "yarn add HAS FAILED, REVERTING CHANGES @ ${dir}"
            ##
            ##    revert_changes
            ##
            ##    # exit
            ##fi

            ####################################
            # NPM - INSTALL
            ####################################

            echo "  Running: npm uninstall $pkg"
            npm uninstall "$pkg" ##  "$pkg"

            if npm install "$URL" > /dev/null 2>&1; then
                echo 123 > /dev/null;
            else
                echo "npm install HAS FAILED, REVERTING CHANGES @ ${dir}"
            
                revert_changes
            
                # exit
            fi

            ####################################
            ####################################

        done

        ############################ 
        ############################ 

        git add ./.yarn
        git add ./yarn.lock
        git add ./package.json
        git add ./package-lock.json

        ############################ 
        ############################ 

        git commit -m "UPG_${repo_name}" 2> /dev/null; 

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


        if has_any_updates; then

            wait_for_push "$dir"

            # bash "${this_script_path}/upgrade_yarn.sh" "${current_pkg_name}"

        fi

        popd > /dev/null

    else
        echo "  No matching dependency found."
    fi
done

echo "---------------------------------------------------------"
echo "Done."
