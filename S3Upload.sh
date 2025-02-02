#!/bin/bash

###########
#Author: Kavindra 
#Description: Script to Upload Jenkins Logs from Server to s3 to save cost
#Version: v1
###########
#
#

set -e
set -x
set -o pipefail

JENKINS_HOME="/var/lib/jenkins"
S3_BUCKET="s3://jenkinlogstorebucket"
DATE=$(date +%Y-%m-%d)                    #get today's date to compare if log files were created today

#Check if Aws CLI is installed or not
if ! command -v aws &> /dev/null; then     # command is used to check if aws is installed, i.e it checks if aws is executable or not 
        echo "AWS CLI  is not installed. Please install it to proceed"
        exit 1
fi

#First we iterate through all Job directories ie. first-job, second-job, third-job etc...
#Inside these directories we have the execution of jobs i.e (1 time ,2 time ...)
#and inside those jobs we have log file inside each
#sample log file path: var/lib/jenkins/jobs/test/builds/1/log    , Here test is my Jenkins Job name, 
#builds is created after u run jobs, and the jobs can run as many time you want and each run is given unique number and each run has its own logs generated. 
#So to traverse all log files and upload the one generated today.

for job_dir in "$JENKINS_HOME/jobs/"*/;do    #double quotes ensure that $jenkins_home/logs/ is treated as single entity preserving spaces , and * is wildcard and / ensures that only directory is selected
        job_name=$(basename "$job_dir") #$() is command substitution, executes the command and stores it output, basename extracts last word from the directry namespaces which is stored in job_dir here

        #Iterate through builds directory for jobs
        for builds_dir in "$job_dir/builds/"*/; do
                build_no=$(basename "$builds_dir")
                log_file="$builds_dir/logs"

                #Check if logs file exists and was created today
                if [ -f "$log_file" ] && [ "$(date -r "$log_file" +%Y-%m-%d)" == "$DATE")]; then  #date -r is used to find the last modified date of file and then format it in Y-m-d format.
                        #Upload log file to s3 bucket 
                        aws cp "$log_file" "$S3_BUCKET/$job_name-$build_no.log" --only-show-errors

                        if[ $? -eq 0 ];  then
                                echo "UPLOADED SUCCESSFULLY $job_name/$build_no to $S3_BUCKET/$job_name-$build_no.log"
                        else
                                echo "Failed to Upload $job_name/$build_no"
                        fi
                fi
        done
done
