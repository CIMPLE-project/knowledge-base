# 📚 CIMPLE Knowledge Graph (CimpleKG)

[![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg


> The CIMPLE Knowledge Graph (CimpleKG) is a continiousely updated large knowledge graph that has been created to help researchers combat misinformation. CimpleKG links information from fact-checking organizations with other datasets about misinformation, giving researchers a more comprehensive view of the problem. 
>
> This repository contains scripts to deploy the Knowledge Graph developed within the [CIMPLE project](https://www.chistera.eu/projects/cimple).

![Claim reviews per countries (11/04/2024 data)](./CimpleKG_claimreviews_2024_04_11.png)


The data being loaded is available at https://github.com/CIMPLE-project/knowledge-base/releases and is updated on a daily (nightly) basis.

The source code to retrieve the body of the claim review from the specified url is available in the [claimreview-text-extractor repository](https://github.com/CIMPLE-project/claimreview-text-extractor).

We fully document the [URI design pattern](https://github.com/CIMPLE-project/converter/blob/main/URI-patterns.md) that are used to identify all objects in the knowledge graph.

The code that converts the daily updated Claim Reviews into RDF is available in the [converter repository](https://github.com/CIMPLE-project/converter).

The Claim Reviews data integrated in the CimpleKG is available on the [claimreview-data repository](https://github.com/MartinoMensio/claimreview-data).


## 🔍 Knowledge Graph Overview and Documentation
CimpleKG links daily updated data from 70+ fact-checking organisations with over 200k+ documents from static misinformation datasets. The knowledge graph is augmented with textual features and entities extracted from the textual data integrated into the graph. The knowledge graph contains more than 15m triples, including 263k+ distinct entities and 1m textual features with over 203k fact-checked claims, spanning 26 languages and 36 countries.

A public SPARQL endpoint is available at https://data.cimple.eu/sparql and data releases are made available in this repository. The knowledge graph can be also loaded and queried locally (see *Initialising the Knowledge Graph*).

SPARQL Query examples and aditional documentation can be found in the [documentation page](./Documentation.md).

### RDF Namespaces

CimpleKG commonly uses the following namespaces and prefixes:

| Prefix | URI |
| --- | --- |
| dc | <http://purl.org/dc/elements/1.1/> |
| rdf | <http://www.w3.org/1999/02/22-rdf-syntax-ns#> |
| rnews | <http://iptc.org/std/rNews/2011-10-07#> |
| schema | <http://schema.org/> |
| xsd | <http://www.w3.org/2001/XMLSchema#> |

They can be imported into Virtuoso through the isql interface:

```
DB.DBA.XML_SET_NS_DECL ('dc', 'http://purl.org/dc/elements/1.1/', 2);
DB.DBA.XML_SET_NS_DECL ('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 2);
DB.DBA.XML_SET_NS_DECL ('rnews', 'http://iptc.org/std/rNews/2011-10-07#', 2);
DB.DBA.XML_SET_NS_DECL ('schema', 'http://schema.org/', 2);
DB.DBA.XML_SET_NS_DECL ('xsd', 'http://www.w3.org/2001/XMLSchema#', 2);
```

## 🚧 Initialising the Knowledge Graph

This section covers the steps required to set up a new Knowlede Base for the first time.

1. Clone [D2KLab/docker-virtuoso](https://github.com/D2KLab/docker-virtuoso) repository.

    ```bash
    git clone https://github.com/D2KLab/docker-virtuoso.git
    cd docker-virtuoso
    ```

1. Build the docker image.

    ```bash
    docker build -t d2klab/virtuoso .
    ```

1. Run the docker image.

    **Note:** make sure to replace `/var/docker/cimple/virtuoso/data` with the volume path where you want the Virtuoso database to be stored. It is also the path which will be used to copy the RDF files you wish to load into the Knowledge Base.

    ```bash
    docker run --name cimple-virtuoso \
      -p 8890:8890 -p 1111:1111 \
      -e DBA_PASSWORD=myDbaPassword \
      -e SPARQL_UPDATE=true \
      -e VIRT_SPARQL_ResultSetMaxRows=-1 \
      -e VIRT_SPARQL_MaxQueryCostEstimationTime=-1 \
      -e VIRT_SPARQL_MaxQueryExecutionTime=-1 \
      -v /var/docker/cimple/virtuoso/data:/data \
      -d d2klab/virtuoso
    ```

### Loading data into the Knowledge base

1. Copy all your RDF files into the `dumps` folder inside the data directory (e.g., `/var/docker/cimple/virtuoso/data/dumps`).

    Directory structure example:

    - `/var/docker/cimple/virtuoso/data/dumps/`
      - `iptc/*.ttl`
      - `agencefrancepresse/*.ttl`

2. Run the following script to load all dumps:

    The script [deploy_all.sh](scripts/deploy_all.sh) will initialize the prefixes, and load all the vocabularies, IPTC codes, and RDF dumps.

    ```
    cd scripts
    ./deploy_all.sh
    ```

### Manually loading a specific file

You can also load certain files given a pattern using the [load.sh](scripts/load.sh) script.

(Note: make sure that the files you wish to load have been copied to the `dumps` folder inside the Virtuoso data directory).

For example, the following command will load all dumps contained in the folder "agencefrancepresse", starting with "2020_", and ending with ".ttl":

```bash
cd scripts
./load.sh -p5 -g "http://data.cimple.eu/agencefrancepresse/news" "agencefrancepresse" "2020_*.ttl"
```

To load all files from the folder "agencefrancepresse/FRA":

```bash
cd scripts
./load.sh -p5 -g "http://data.cimple.eu/agencefrancepresse/news" "agencefrancepresse/FRA" "*.*"
```

Syntax: `load.sh [options] [graph] [dir path] [file mask]]`

List of parameters:

```
-h --help       Show help
-p --parallel   Number of parallel threads for loading RDF data (through rdf_loader_run())
-g --graph      Name of graph to load the data into
-c --clear      Clear graph before loading
```

### Webhook Setup

1. Generate a password for the webhook server:

    ```bash
    htpasswd -B -c ./webhookd/.htpasswd api
    ```

1. Build the docker image:

    ```bash
    cd ./webhookd
    docker build -t cimple/webhookd .
    ```

1. Run webhookd container:

    ```bash
    docker run --name cimple-webhookd \
      -p 8880:8080 \
      -e DBA_PASSWORD=myDbaPassword \
      -e VIRTUOSO_URL=https://data.cimple.eu \
      -e WHD_PASSWD_FILE=/etc/webhookd/.htpasswd \
      -e WHD_HOOK_TIMEOUT=21600 \
      -v $(pwd)/webhookd/scripts:/scripts \
      -v $(pwd)/webhookd/cache:/data/cache \
      -v $(pwd)/webhookd/.htpasswd:/etc/webhookd/.htpasswd \
      -v /data/cimple-factors-models:/data/cimple-factors-models
      -d cimple/webhookd
    ```

*Webhooks list:*

* http://localhost:8880/redeploy - Executes the delpoyment script.
* http://localhost:8880/status - Returns "OK" if the service is running.

*Example:*

```bash
curl -u api:$API_PASSWORD http://localhost:8880/status
curl -u api:$API_PASSWORD -XPOST http://localhost:8880/redeploy?url=https%3A%2F%2Fgithub.com%2FMartinoMensio%2Fclaimreview-data%2Freleases%2Ftag%2F2023_08_22
```

(replace `$API_PASSWORD` with the password you generated during Setup step)

### Dereferencing

The list of path to be dereferenced is in `dereferencing/config.yml`. See the full list of [URI patterns](URI.patterns.md) for reference.

For exporting the apache config and the script for adding them to Virtuoso, run:

```
cd dereferencing
npx list2dereference config.yml
docker cp "insert_vhost.sql" "cimple-virtuoso:/insert_vhost.sql"
docker exec -i "cimple-virtuoso" sh -c "isql-v -U dba -P \${DBA_PASSWORD} < /insert_vhost.sql"
```

Read more at https://github.com/pasqLisena/list2dereference

### URL Shortening

The service can be accessed at http://cimple.eurecom.fr/c/.

To install the URL shortening service, run the following commands:

```
cd scripts
docker cp "c_uri_dav.vad" "cimple-virtuoso:/usr/local/virtuoso-opensource/share/virtuoso/vad/c_uri_dav.vad"
docker exec -i "cimple-virtuoso" sh -c "isql-v -U dba -P \${DBA_PASSWORD} exec=\"DB.DBA.VAD_INSTALL('/usr/local/virtuoso-opensource/share/virtuoso/vad/c_uri_dav.vad');\""
```

The service is hosted on the route `/c`. You may have to update the apache2 Virtual Host configuration to map the route, for example (assuming Virtuoso is hosted on port 8890):

```
<Location /c>
    ProxyPreserveHost On
    ProxyPass http://localhost:8890/c
    ProxyPassReverse http://localhost:8890/c
</Location>
```
