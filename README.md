# Intel Bigdl with PPML workload

## deployment:
The README.MD on gitlab is underconstruction. Please refer to [this page](https://hackmd.io/@3oatvhDfTSqijOwo0tingw/Syp8dnHuj) for temporary instrctions.
1. Preparation:
	- Done preparation of several SGX-enables nodes(in this case, `wn{21,22,11}.openlab`)
	- Done registration of Intel provision certificate and obtained API key
	- Deployed a kubernetes cluster
2. Deploy pccs service:
	- Configured `deployment/pccs/install-bigdl-pccs.sh`
    	  ``` bash
          # replace with your API key
    	  export apiKey="c10a161b3d3847d4a886d880f6e0fe77"

          # use desired namespace
    	  export appNamespace="bigdl-alan"

          # user password for accessing pccs
    	  export pccsUserPassword="admin@QCT"
          # admin password for accessing pccs
    	  export pccsAdminPassword="admin@QCT"

          # some naming rules
          # image
          # port
    	  export pccsCommonName="pccs"
    	  export pccsSvcName="${pccsCommonName}-svc"
    	  export pccsSvcPort="18081"
    	  export pccsStsName="${pccsCommonName}-sts"
    	  export pccsImageName="docker.io/intelanalytics/pccs:0.3.0-SNAPSHOT"

          # pccs service need internet access to contact with intel PCS
    	  #export pccsServerNode="wn11.openlab"
    	  export pccsServerNode="adm01.openlab"

    	  # additional SSl info
    	  export ssl_countryName="TW"
    	  export ssl_cityName="NewTaipei"
    	  export ssl_organizaitonName="QCT"
    	  export ssl_commonName="openlab"
    	  export ssl_emailAddress="alan@qct.io"
    	  export ssl_password="qctRD3"
    	  ```
	- deploy pccs service
	  ``` bash
          bash deployment/pccs/install-bigdl-pccs.sh
	  ```
