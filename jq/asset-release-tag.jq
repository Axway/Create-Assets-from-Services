{
    group: "catalog",
    apiVersion: "v1alpha1",
    kind: "ReleaseTag",
    metadata: {
        scope: {
            kind: "Asset",
            name: $asset_name,
        }
    },
    spec: {
        releaseType: "major"
    }
}