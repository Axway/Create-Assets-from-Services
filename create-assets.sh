#!/bin/bash

###############################################################################
# This script follows the official documentaion for creating Assets:
# https://docs.axway.com/bundle/amplify-central/page/docs/manage_asset_catalog/asset_integrate_api_cli/index.html
#
# But the script takes it once step further by building an Asset from the same 
# Services published in two or more related ENV, e.g. PROD and DEV
# 
# Usage:
# ./create-assets.sh prod qa dev
#
# where "prod", "qa", and "dev" are the names (logical names in Amplify) of the 
# related ENV. 
# The first ENV in the list should be the "main" ENV that is used as a template 
# for building Assets. That means that there may be services in other ENV that 
# don't exist in the "main" ENV; those services will not be bundled into an 
# Asset.
# There may be an opposite situation when other ENV don't have a Service that 
# exists in the "main" ENV. In that case, only the Service from the "main" ENV 
# is bundled into an Asset.
###############################################################################

# There are a few parameters that the script reads from this properties file.

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

function print_info {
   echo -e "\033[32m""$1"
}


######################################################
# 0. Init the process with all necessary data        #
######################################################

# Check if a user is logged into Amplify

LOGGED_IN=$(axway auth list --json | jq '.|length')

if [ $LOGGED_IN -eq 0 ]; then
   (exit 1)
   error_exit "You need to be logged in."
fi

if [ $# -ne 0 ]; then
   ./init.sh "$@"
else
   (exit 1)
   error_exit "Input Error: you need to pass one or more ENV names from which you want to create Assets."
fi

######################################################
# 1. Creating "empty" assets                         #
######################################################

# Check if required Stage exists in the target ORG

export STAGE_COUNT=$(axway central get stages -q title=="\"$STAGE_TITLE\"" -o json | jq '.|length')

if [ $STAGE_COUNT -eq 0 ]; then
   (exit 1)
   error_exit "Stage - $STAGE_TITLE - doesn't exist."
else
   export STAGE_NAME=$(axway central get stages -q title=="\"$STAGE_TITLE\"" -o json | jq -r .[0].name)
fi

# Establish a category under which all Assets will be registered

axway central get category -q title=="\"$CATEGORY_TITLE\"" -o json > ./json_files/category.json
CATEGORY_COUNT=$(jq '.|length' ./json_files/category.json)
if [ $CATEGORY_COUNT -eq 0 ]; then
   echo "Creating new Category"
   jq -n -f ./jq/asset-category.jq --arg category_title "$CATEGORY_TITLE" --arg description "$CATEGORY_DESCRIPTION" >./json_files/category.json
   axway central create -f ./json_files/category.json -y -o json >./json_files/category-created.json
   export CATEGORY_NAME=$(jq -r .[0].name ./json_files/category-created.json)
else
   export CATEGORY_NAME=$(jq -r .[0].name ./json_files/category.json)
fi

# Prepare additional files for creating assets

echo "[]" >./json_files/assets.json
echo "[]" >./json_files/assets-mapping.json
echo "[]" >./json_files/assets-updated.json
echo "[]" >./json_files/assets-release-tag.json

#Loop through all APISI and create an Asset:
# ONE ASSET PER ONE APISI

echo ""
print_info "Building a list of ASSETS to create."

while IFS= read -r APISI_NAME; do

   export APISI_JQ=$APISI_NAME
   export RVSN_NAME=$(jq -r '.[] | select(.name == $ENV.APISI_JQ)  | .spec.apiServiceRevision' ./json_files/api-instances0.json)
   export SRV_NAME=$(jq -r '.[] | select(.name == $ENV.RVSN_NAME)  | .spec.apiService' ./json_files/api-revisions0.json)

   print_info "Working with the $SRV_NAME service"

   export ASSET_TITLE=$(jq -r '.[] | select(.name == $ENV.SRV_NAME)  | .title' ./json_files/api-services0.json)

   # Check if this Asset already exists in the file

   if [ $(jq 'any(.[]; .title == $ENV.ASSET_TITLE)' ./json_files/assets.json) = false ]; then
      export ASSET_TO_ADD=$(jq -n -f ./jq/asset.jq --arg title "$ASSET_TITLE")
      echo $(jq --argjson asset "$ASSET_TO_ADD" '. += [$asset]' ./json_files/assets.json) >./json_files/assets.json
   fi

done <./json_files/apisi0.txt

# Create all assets

echo ""
axway central create -f ./json_files/assets.json -o json -y >./json_files/assets-created.json
error_exit "Problem when creating the assets" "./json_files/assets-created.json"

######################################################
# 2. Build assets mappings and releases JSON files   #
######################################################


num_of_assets=$(cat ./json_files/assets-created.json | jq '.|length')

for ((i = 0; i < $num_of_assets; i++)); do

   # Now we need to add a release tag, otherwise Amplify won't allow us to use this asset in Product Foundry commands
   # Create a release tag file from a template

   export ASSET_NAME=$(jq -r ".[$i].name" ./json_files/assets-created.json)
   export ASSET_RELEASE_TAG=$(jq -n -f ./jq/asset-release-tag.jq --arg asset_name "$ASSET_NAME")
   echo $(jq --argjson asset "$ASSET_RELEASE_TAG" '. += [$asset]' ./json_files/assets-release-tag.json) >./json_files/assets-release-tag.json
done

# Now that we have our Assets created, we're going to update them and activate

params=( "$@" )
num_of_env=$#
for ((i = 0; i < $num_of_env; i++)); do

   export ENVIRONMENT_NAME=${params[i]}

   while IFS= read -r APISI_NAME; do

      export APISI_JQ=$APISI_NAME
      export RVSN_NAME=$(jq -r '.[] | select(.name == $ENV.APISI_JQ)  | .spec.apiServiceRevision' ./json_files/api-instances"$i".json)
      export SRV_NAME=$(jq -r '.[] | select(.name == $ENV.RVSN_NAME)  | .spec.apiService' ./json_files/api-revisions"$i".json)

      export ASSET_TITLE=$(jq -r '.[] | select(.name == $ENV.SRV_NAME)  | .title' ./json_files/api-services"$i".json)

      # If an Asset with a given ACCESS_TITLE exist, then we add a new Asset Mapping, etc.
      if [ $(jq 'any(.[]; .title == $ENV.ASSET_TITLE)' ./json_files/assets-created.json) = true ]; then
         export ASSET_NAME=$(jq -r '.[] | select(.title == $ENV.ASSET_TITLE)  | .name' ./json_files/assets-created.json)

         # Create an asset mapping file to add a Service Instance to the asset

         echo -e "\033[32m""Updating the $ASSET_NAME asset"

         export ASSET_TO_MAP=$(jq -n -f ./jq/asset-mapping.jq --arg asset_name "$ASSET_NAME" --arg stage_name "$STAGE_NAME" --arg env_name "$ENVIRONMENT_NAME" --arg apisi "$APISI_JQ")
         echo $(jq --argjson asset "$ASSET_TO_MAP" '. += [$asset]' ./json_files/assets-mapping.json) >./json_files/assets-mapping.json

         # Assign a category to the asset and set it state to Active

         export ASSET_UPDATED=$(jq '.[] | select(.name == $ENV.ASSET_NAME)' ./json_files/assets-created.json | jq '.spec.categories |= . + [env.CATEGORY_NAME]' | jq '.state = "active"' | jq 'del(. | .references)')

         echo $(jq --argjson asset "$ASSET_UPDATED" '. += [$asset]' ./json_files/assets-updated.json) >./json_files/assets-updated.json

         # Adding an image to the Asset

         export encodedImage=$(jq '.[] | select(.name == $ENV.SRV_NAME)  | .spec.icon.data' ./json_files/api-services"$i".json)
         if [ "$encodedImage" != "null" ]; then
            export ASSET_IMAGE=$(echo $ASSET_UPDATED | jq --argjson image $encodedImage '.icon = "data:image/png;base64," + $image')
            echo $(jq --argjson asset "$ASSET_IMAGE" 'map(select(.name == $ENV.ASSET_NAME) |= $asset )' ./json_files/assets-updated.json) >./json_files/assets-updated.json
         fi
      fi

   done <./json_files/apisi"$i".txt
done

######################################################
# 3. Complete assets creation                        #
######################################################

# Update Assets based on crated Assets mapping, etc.

axway central create -f ./json_files/assets-mapping.json -y -o json >./json_files/assets-mapping-created.json
error_exit "Problem creating asset mapping" "./json_files/asset-mapping-created.json"

echo $(jq 'del(. | .[].latestrelease)' ./json_files/assets-updated.json) > ./json_files/assets-updated.json
axway central apply -f ./json_files/assets-updated.json
error_exit "Problem updating Assets"

axway central create -f ./json_files/assets-release-tag.json -o json -y > ./json_files/assets-release-tag-created.json
error_exit "Problem creating release tags" "./json_files/assets-release-tag-created.json"
