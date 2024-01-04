# zcnwebappscripts

Scripts that Züs network webapps like Chimeny, Blimp use to provision their servers.


### Chimney:

[chimney.sh](https://github.com/0chain/zcnwebappscripts/blob/main/chimney.sh) is used to provision a server as chimeny blobber.


### Blimp:
[blimp.sh](https://github.com/0chain/zcnwebappscripts/blob/main/blimp.sh) is used to provision a s3 server

the script [migration.sh](https://github.com/0chain/zcnwebappscripts/blob/main/migration.sh) helps in migrating files from AWS S3 to Züs network


# preparing Zip file

create zip file for grafana dashboard files
```
rm artifacts/chimney-dashboard.zip
cd chimney-dashboard
zip -r ../artifacts/chimney-dashboard.zip . -x ".*" -x "*/.*"
```

create zip file for blobber files
```
rm artifacts/blobber-files.zip
cd blobber-files
zip -r ../artifacts/blobber-files.zip . -x ".*" -x "*/.*"
```

