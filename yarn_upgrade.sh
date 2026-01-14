#!/bin/bash

# Script to recursively upgrade npm packages and push changes

# Global array to track processed service-folder combinations
declare -A PROCESSED_COMBINATIONS

git_configure_path=$(command -v git-configure)
current_dir=$(pwd)

# Function to extract package name from package.json
extract_package_name() {
    local folder="$1"
    if [ -f "$folder/package.json" ]; then
        package_name=$(grep -o '"name": *"[^"]*"' "$folder/package.json" | head -1 | cut -d'"' -f4)
        echo "$package_name"
    else
        echo ""
    fi
}

# Function to process a service
process_service() {
    local service_name="$1"
    # local current_dir=$(pwd)

    cd "$current_dir"
    
    echo "Processing service: $service_name"
    
    # Find all folders containing the service in package.json
    local folders
    mapfile -t folders < <(grep -rli "\"$service_name\"" ./*/package.json 2>/dev/null)
    
    if [ ${#folders[@]} -eq 0 ]; then
        echo "No dependencies found for $service_name"
        return 0
    fi
    
    # Process each folder
    for folder_path in "${folders[@]}"; do
        # Convert to directory path
        folder=$(dirname "$folder_path")
        
        # Create unique key for service-folder combination
        local combination_key="${service_name}|${folder}"
        
        # Check if we've already processed this combination
        if [[ ${PROCESSED_COMBINATIONS[$combination_key]} ]]; then
            echo "Already processed $service_name in $folder. Skipping..."
            continue
        fi

        echo "=========================="
        
        echo "# Processing folder: $folder"
        
        echo "=========================="
        
        # Navigate to the folder
        cd "$folder" || { echo "Failed to navigate to $folder"; continue; }

        # Extract package name from current folder's package.json
        local next_service=$(extract_package_name ".")

        if [ "$service_name" = "$next_service" ]; then

            echo "Skipping ${service_name} = ${next_service}"

            continue
        fi

        git config --global --add safe.directory "$(pwd)";
        
        # FIRST: process local dependencies
        local deps
        mapfile -t deps < <(extract_local_dependencies)

        for dep in "${deps[@]}"; do
            # Only recurse if it's a local package
            if [ -f "../$dep/package.json" ] || [ -f "./$dep/package.json" ]; then
                echo "Ensuring dependency $dep is upgraded before $next_service"
                process_service "$dep"
            fi
        done

        # THEN upgrade the target service
        echo "Running: yarn upgrade $service_name"
        yarn upgrade "$service_name"

        # Run git commands
        echo "Running git commands..."

        has_yarn_update="$(git status | grep yarn.lock)"

        git add ./yarn.lock
        git commit -m "UPG ${service_name}"

        if [ -n "$git_configure_path" ]; then
        
            $git_configure_path;

        fi

        if [ -z "$has_yarn_update" ]; then
        
            # Mark this combination as processed
            PROCESSED_COMBINATIONS["$combination_key"]=1

        fi

        ####### TODO:
        ####### git push

        finish_msg="# UPGRADED ${service_name} AT ${folder}"

        echo "${finish_msg}"

        if [ -n "$has_yarn_update"  ]; then

            ################################

            # for ((i=20; i>=1; i--)); do
            #     printf "DO GIT PUSH AT ${folder}: \r%d " "$i"
            #     sleep 1
            # done
            # printf "\n"

            ################################

            read -r -p "Press Enter to continue..."

            ################################
            
            # If we have a package name, recursively process it
            if [ -n "$next_service" ]; then
                # Check if we're about to create a cycle
                local next_key="${next_service}|${folder}"
                if [[ ${PROCESSED_COMBINATIONS[$next_key]} ]]; then
                    echo "Cycle detected: $next_service in $folder already processed. Stopping recursion."
                else
                    echo "Moving to next service: $next_service"
                    process_service "$next_service"
                fi
            else
                echo "No package name found in $folder/package.json"
            fi

            ################################

        fi
        
        # Return to original directory
        cd "$current_dir" || exit 1
    done
}

# Extract local dependencies (names only)
extract_local_dependencies() {
    jq -r '
      (.dependencies // {} + .devDependencies // {})
      | keys[]
    ' package.json 2>/dev/null
}

# Main execution
main() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <npm-package-name>"
        echo "Example: $0 user_service"
        exit 1
    fi
    
    local service_name="$1"
    
    # Initialize processed combinations
    PROCESSED_COMBINATIONS=()
    
    # Start processing
    process_service "$service_name"
    
    echo "Processing completed!"
}

# Run main function
main "$@"
