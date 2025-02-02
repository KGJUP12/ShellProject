#!/bin/bash

###########
# Author: Kavindra 
# Description: Script to Upload Jenkins Logs from Server to S3 for cost-saving purposes.
# Version: v1
# Note: Please update the S3 bucket name as needed.
###########

# Exit immediately if a command exits with a non-zero status
set -e
# Print each command before execution (for debugging purposes)
set -x
# Fail the script if any command in a pipeline fails
set -o pipefail

# Define the Jenkins home directory where jobs and logs are stored
JENKINS_HOME="/var/lib/jenkins"
# Define the S3 bucket URL for storing the logs
S3_BUCKET="s3://demo-jenkins-bucket"
# Get today's date in YYYY-MM-DD format to compare with the logs' modification date
DATE=$(date +%Y-%m-%d)

# Check if AWS CLI is installed on the system
if ! command -v aws &> /dev/null; then
    # If AWS CLI is not found, print an error message and exit
    echo "AWS CLI is not installed. Please install it to proceed."
    exit 1
else
    # If AWS CLI is installed, print a success message
    echo "AWS CLI Installed."
fi

# Iterate through all Jenkins job directories inside $JENKINS_HOME/jobs/
# For example: /var/lib/jenkins/jobs/test-job/, /var/lib/jenkins/jobs/dev-job/, etc.
for job_dir in "$JENKINS_HOME/jobs/"*/; do
    # Extract the base name of the job directory (e.g., test-job, dev-job)
    job_name=$(basename "$job_dir")

    # Iterate through the builds directory inside each job's folder (e.g., /var/lib/jenkins/jobs/test-job/builds/)
    for builds_dir in "$job_dir/builds/"*/; do
        # Extract the build number (e.g., 1, 2, 3, etc.)
        build_no=$(basename "$builds_dir")
        # Set the log file path for the current build (e.g., /var/lib/jenkins/jobs/test-job/builds/1/log)
        log_file="$builds_dir/log"

        # Check if the log file exists and was created today
        if [ -f "$log_file" ] && [[ "$(date -r "$log_file" +%Y-%m-%d)" == "$DATE" ]]; then
            # Upload the log file to the S3 bucket using AWS CLI
            aws s3 cp "$log_file" "$S3_BUCKET/$job_name-$build_no.log" --only-show-errors
            # Check if the upload was successful by inspecting the exit status of the last command
            if [ $? -eq 0 ]; then
                # If upload was successful, print a success message
                echo "Uploaded successfully: $job_name/$build_no to $S3_BUCKET/$job_name-$build_no.log"

                # Use a subshell to delete the build directory after uploading the log
                # This avoids affecting the current shell's environment
                $(sudo rm -rf "$builds_dir")

                # Check if the removal was successful
                if [ $? -eq 0 ]; then
                    # If successful, print a removal confirmation message
                    echo "Removed directory: $builds_dir from the local server."
                else
                    # If removal failed, print an error message
                    echo "Failed to remove directory: $builds_dir."
                fi
            else
                # If the upload failed, print an error message
                echo "Failed to upload: $job_name/$build_no"
            fi
        fi
    done
done

