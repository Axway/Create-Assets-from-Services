#!/bin/bash

###############################################################################
# This script builds auxiliary files that are used by the create-assets.sh
# script and cleans working dir.
###############################################################################

# Sourcing user-provided env properties

source ./config/env.properties

####################################
# Utility function                 #
####################################
function error_exit {
   if [ $? -ne 0 ]; then
      echo -e "\033[33m""$1" "\033[0;39m"
      if [ $2 ]; then
         echo -e "\033[33m"See "$2" file for errors "\033[0;39m"
      fi
      echo -e "\033[33m"Exiting...
      exit 1
   fi
}

###################################################
# Creating an asset and mapping service instances #
###################################################

# creating a working dir for JSON files
if [ ! -d "./json_files" ]; then
   mkdir ./json_files
elif [ $(ls ./json_files/ | wc -l) -ne 0 ]; then
   rm ./json_files/*
fi

# Build  the list of API services, service instances, remisions
i=0

for arg; do
   export ENVIRONMENT_NAME="$arg"

   echo -e "\033[32m""Getting data for the $ENVIRONMENT_NAME environment."

   axway central get apisi -s $ENVIRONMENT_NAME -o json >./json_files/api-instances"$i".json
   cat ./json_files/api-instances"$i".json | jq -r .[].name >./json_files/apisi"$i".txt

   error_exit 'Problem getting Service Instances' "./json_files/apisi$i.txt"

   # Also, get all service revisions, as there are several elements that are used during
   # Asset creationg

   axway central get apisr -s $ENVIRONMENT_NAME -o json >./json_files/api-revisions"$i".json

   error_exit 'Problem getting Service Revisions' "./json_files/api-revisions$i.json"

   # Also, get all services, as there are several elements that are used during
   # Asset creationg

   axway central get apis -s $ENVIRONMENT_NAME -o json >./json_files/api-services"$i".json

   error_exit 'Problem getting Services' "./json_files/api-services$i.json"

   i=$((i + 1))
done
