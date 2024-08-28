# Create assets



## Getting started

This script follows the official documentation for creating Amplify Assets - [link](https://docs.axway.com/bundle/amplify-central/page/docs/manage_asset_catalog/asset_integrate_api_cli/index.html).

But the script takes it once step further by building an Asset from the same Services published in two or more related ENV, e.g. PROD and DEV

Usage:
```bash
./create-assets.sh prod qa dev
```

where *prod*, *qa*, and *dev* are the names (logical names in Amplify) of the related ENV. 

The first ENV in the list should be the "main" ENV that is used as a template for building Assets. That means that there may be services in other ENV that don't exist in the "main" ENV; those services will not be bundled into an Asset.

There may be an opposite situation when other ENV don't have a Service that exists in the "main" ENV. In that case, only the Service from the "main" ENV is bundled into an Asset.

You can also pass a name of one ENV, and the script will create Assets for all services in one ENV

Usage:
```bash
./create-assets.sh prod 
```

## Deleting Assets

If you want to remove the Assets created in the previous step, you can use the following script:

```bash
./del-assets.sh
```

The script will take action based on the JSON file created before ( ./json/assets-created.json). If this file doesn't exist or has been deleted, generate this file first, then invoke the *del-assets.sh* script.