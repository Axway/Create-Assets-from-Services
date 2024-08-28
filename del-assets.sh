#!/bin/bash

###############################################################################
# This script deletes all Assets that have been created with the 
# create-assets.sh script.
#
# Make sure you still have the ./json_files/assets-created.json file.
# If you don't have it, please, generate it with the Assets that you want to
# delete.
###############################################################################


# Check if a user is logged into Amplify

LOGGED_IN=$(axway auth list --json | jq '.|length')

if [ $LOGGED_IN -eq 0 ]; then
   (exit 1)
   error_exit "You need to be logged in."
fi

# Check presentce some dir and file

if [ ! -d "./json_files" ] 
then
    mkdir ./json_files
fi

if [ ! -f "./json_files/assets-created.json" ] 
then
   echo -e "\033[33m""The file ./json_files/assets-created.json doesn't exist. Please, generate this file with the Assets that you want to delete." "\033[0;39m" 
   exit 1
fi

echo "" > ./json_files/asset-to-archive.json
echo "" > ./json_files/asset-to-delete.json

jq '.[].state = "deprecated"' ./json_files/assets-created.json | jq 'del(. | .[].references , .[].latestrelease)' > ./json_files/asset-to-archive.json
axway central apply -f ./json_files/asset-to-archive.json


jq '.[].state = "archived"' ./json_files/asset-to-archive.json  > ./json_files/asset-to-delete.json
axway central apply -f ./json_files/asset-to-delete.json

echo "Deleting Assets..."

axway central delete -f ./json_files/asset-to-delete.json
