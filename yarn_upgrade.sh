#!/bin/bash

# Script to recursively upgrade npm packages and push changes

# Global array to track processed service-folder combinations
declare -A PROCESSED_COMBINATIONS

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
    local current_dir=$(pwd)
    
    echo "Processing service: $service_name"
    
    # Find all folders containing the service in package.json
    local folders
    mapfile -t folders < <(grep -rli "\"$service_name\"" ../*/package.json 2>/dev/null)
    
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
        
        echo "Processing folder: $folder"
        
        # Mark this combination as processed
        PROCESSED_COMBINATIONS["$combination_key"]=1
        
        # Navigate to the folder
        cd "$folder" || { echo "Failed to navigate to $folder"; continue; }
        
        # Upgrade the package
        echo "Running: yarn upgrade $service_name"
        yarn upgrade "$service_name"
        
        # Run git commands
        echo "Running git commands..."
        git-configure
        git push
        
        # Extract package name from current folder's package.json
        local next_service=$(extract_package_name ".")
        
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
        
        # Return to original directory
        cd "$current_dir" || exit 1
    done
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
