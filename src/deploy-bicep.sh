#!/bin/bash
# ===================================================
# Script Name: deploy-bicep.sh
# Description: This script deploys a bicep template.
# Author: Audun Akse
# Date: 2024-11-28
# Version: 1.0
# ===================================================

# Enable strict mode
set -euo pipefail

# Multiline annotation replacement function
format_multiline_annotation() {
    # Input: A multiline string
    # Output: The string formatted for GitHub annotations

    local input="$1"

    # Replace newlines with %0A to support multiline annotations in GitHub workflows
    local formatted_string=$(echo "$input" | sed ':a;N;$!ba;s/\n/%0A/g')

    # Output the formatted string
    echo "$formatted_string"
}

# Cleanup function
print_stderr() {
    # Read the file line by line
    while IFS= read -r line; do
        if [[ $line == WARNING:* ]]; then
            # Extract the WARNING message and print it in yellow
            echo -e "\e[33m${line#WARNING: }\e[0m"
        elif [[ $line == INFO:* ]]; then
            # Print the INFO message in the default color
            echo "${line#INFO: }"
        elif [[ $line == ERROR:* ]]; then
            # Extract the JSON from the ERROR message
            json=${line#ERROR: }
            # Pretty-print the JSON and apply red color to each line, suppressing extra lines
            formatted_json=$(echo "$json" | jq . 2>/dev/null | while IFS= read -r json_line || [[ -n $json_line ]]; do
                echo -e "\e[31m${json_line}\e[0m"
            done)
            annotation_json=$(format_multiline_annotation "$formatted_json")
            echo "::error::An error occurred during deployment. See error details in below%0A${annotation_json}"
        fi
    done <stderr.log
}

# Set trap to call the cleanup function on ERR
trap print_stderr ERR

# Create deployment command
cmd=()
case $SCOPE in
resourceGroup)
    cmd+=("az deployment group create")
    cmd+=("--resource-group \"$RESOURCE_GROUP\"")
    ;;
subscription)
    cmd+=("az deployment sub create")
    cmd+=("--location \"$LOCATION\"")
    ;;
managementGroup)
    cmd+=("az deployment mg create")
    cmd+=("--location \"$LOCATION\"")
    cmd+=("--management-group-id \"$MANAGEMENT_GROUP_ID\"")
    ;;
tenant)
    cmd+=("az deployment tenant create")
    cmd+=("--location \"$LOCATION\"")
    ;;
*)
    echo "::error::Unknown deployment scope." >&2
    exit 1
    ;;
esac

# Add common parameters
cmd+=("--parameters \"$PARAMETER_FILE\"")
cmd+=("--name \"$DEPLOYMENT_NAME\"")
cmd+=("--verbose")
cmd+=($([[ $WHAT_IF == 'true' ]] && echo "--what-if" || echo ""))
cmd+=($([[ $DEBUG -eq 1 ]] && echo "--debug" || echo ""))

# Print command
echo "Running command:"
printf "\n%s\n" "$(
    printf "%s \\\\\n" "${cmd[@]}" |                # Print each array element followed by " \\"
        awk 'NR==1 {print; next} {print "  " $0}' | # Add two spaces before all lines except the first
        sed '$ s/ \\$//'                            # Remove the trailing slash from the last line
)"

# Run deployment command
deploymentOutput=$("${cmd[@]} 2> >(tee stderr.log >&2) | tee stdout.log")

# Write the result to console
echo "$deploymentOutput"

# Write success annotation
formatted_json=$(echo "$deploymentOutput" | jq . 2>/dev/null)
annotation_json=$(format_multiline_annotation "$formatted_json")
echo "::notice::Bicep template successfully deployed. Result:%0A${annotation_json}"

# Format markdown code block and output to deployment.md
sed \
    -e '1s/^/```diff\n/' \
    -e '$a```' \
    -e 's/~/!/g' \
    -e 's/^[ \t]*//' \
    stdout.log >deployment.md

# Write as github output
echo "deploymentOutput=$(echo $deploymentOutput)" >>"$GITHUB_OUTPUT"

exit 0
