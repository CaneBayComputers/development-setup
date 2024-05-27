#!/bin/bash

set -e

shopt -s expand_aliases

cd ~/repos/cbc-development-setup

source .bash_aliases

# Function to remove rules with a specific comment from a given table and chain
remove_custom_rules() {

	table=$1
	chain=$2
	comment=$3

	# List the rules with line numbers, search for the comment, extract line numbers, and remove those rules
	iptables -t $table -L $chain --line-numbers -n | grep "$comment" | awk '{print $1}' | tac | while read -r line_number; do
		
		iptables -t $table -D $chain $line_number
	
	done
}


#######################################################
# Main
#######################################################


# Define the comment to search for
custom_comment="cbc-rule"


# Remove custom rules from the filter table
for chain in INPUT FORWARD OUTPUT; do
	
	remove_custom_rules filter $chain $custom_comment
	
done


# Remove custom rules from the nat table
for chain in PREROUTING POSTROUTING OUTPUT; do
	
	remove_custom_rules nat $chain $custom_comment
	
done


# Remove custom rules from the mangle table
for chain in PREROUTING INPUT FORWARD OUTPUT POSTROUTING; do
	
	remove_custom_rules mangle $chain $custom_comment
	
done


# Print confirmation message
echo; echo-green "CBC iptables rules have been removed!"; echo-white; echo


# Shut down Docker containers
for CONTAINER_ID in $(docker ps -q); do

    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' $CONTAINER_ID | sed 's/^\/\+//')

    REPO_DIR=~/repos/$CONTAINER_NAME;

    if [ -d "$REPO_DIR" ]; then

    	echo; echo-cyan "Shutting down $CONTAINER_NAME ..."; echo-white; echo

    	cd $REPO_DIR

    	dockerdown

    	divider

    fi

done

if dockerls | grep cbc-mariadb > /dev/null; then

	echo; echo-cyan "Shutting down cbc-development-setup ..."; echo-white; echo

	downcbcstack

	echo

fi

# Remove startup log
if rm -f ~/repos/cbc-development-setup/startup.log; then true; fi

# Print confirmation message
echo; echo-green "All CBC containers have been shut down!"; echo-white; echo