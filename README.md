# DomainRadar

This repository contains a Docker Compose setup for a complete DomainRadar testing environment. It includes a Kafka cluster using encrypted communication, the prefilter, the pipeline components (collectors, data merger, feature extractor, classifier), a PostgreSQL database, a MongoDB database, Kafka Connect configured to push data to them, and a web UI for Kafka.

The [*compose.yml*](./compose.yml) Compose file provides several services assigned to several profiles.

## Services with exposed ports

- _kafka1_, the first Kafka broker:
    - Exposed on 31013 (through the `kafka-outside-world` network).
    - Internally, clients use `kafka1:9093`.
    - SSL authentication, see below.
- _kafka-ui_, [Kafbat UI](https://github.com/kafbat/kafka-ui), a web UI for Kafka: 31000
    - No authentication is used!
- _kafka-connect_, the Kafka Connect REST API: 31002
    - No authentication (will be changed).
    - Included in two flavors: _kafka-connect-full_ and _kafka-connect-without-postgres_.
- _postgres_, the PostgreSQL database: 31010
    - Password (SCRAM) authentication (probably will be changed, see below).
- _mongo_, the MongoDB Community database: 31011
    - Password (SCRAM) authentication (probably will be changed, see below).

### Other services

- _initializer_ invokes the [wait_for_startup](kafka_scripts/wait_for_startup.sh) script that exits only when successfuly connected to Kafka, and the [prepare_topics](kafka_scripts/prepare_topics.sh) script that creates or updates the topics.
- _config-manager_ is the configuration manager. It requires the [config_manager_daemon](../src/config_manager/config_manager_daemon.py) script to be executed on the host machine first.
- _standalone-input_ can be executed to load domain names into the system.
- _mongo-domains-refresher_ and _mongo-raw-data-refresher_ execute the [run_periodically](mongo_aggregations/run_periodically.sh) script to run MongoDB aggregations.

## Preparation

### Data

- Obtain your GeoLite2 City & ASN databases and place them in [*geoip\_data*](./geoip_data/).
- Obtain a NERD token and place it in your [*client\_properties/nerd.properties*](./client_properties/nerd.properties).

### Security

You need to generate a CA, broker certificates and client certificates. Ensure that you have OpenSSL and Java installed (JRE is fine). Then you can run:

```bash
./generate_secrets.sh
``` 

You can also use the included Docker image:

```bash
./generate_secrets_docker.sh
```

You can change the certificates' validity and passwords by setting the variables at the top of the *generate_secrets.sh* script. If you do, you have to also change the passwords in the _envs/kafka\*.env_ files, the files in _client\_properties/_ for all the clients and _connect\_properties/10\_main.properties_.

For the love of god, if you use the generated keys and certificates outside of development, change the passwords and store the CA somewhere safe.

The _db_ directory contains configuration for the database, including user passwords. Be sure to change them when actually deploying this somewhere. The passwords must be set accordingly in the services that use them, i.e., Kafka Connect (*connect_properties*), the prefilter, the UI, the ingestion controller (not yet included).

### Component images

You can use a provided script to clone and build all the images at once.

Alternatively, you can build the individual images by hand:

1. Clone the [domainradar-colext](https://github.com/nesfit/domainradar-colext/) repo. Follow its README to build the images!
2. Clone the [domainradar-input](https://github.com/nesfit/domainradar-input) repo and use [*dockerfiles/prefilter.Dockerfile*](./dockerfiles/prefilter.Dockerfile) to build it. Tag it with `domrad/prefilter`.
3. Clone the [domainradar-ui](https://github.com/nesfit/domainradar-ui) repo and use the Dockerfile included in it to build the webui image. Tag it with `domrad/webui`.

### Scaling

You can adjust the scaling of the components by changing the variables in [.env](./.env). Note that to achieve parallelism, the scaling factor must be less or equal to the partition count of the component's input topic. Modify the partitioning accordingly in [prepare_topics](./kafka_scripts/prepare_topics.sh) and set the `UPDATE_EXISTING_TOPICS` environment variable of the _initializer_ service to `1` to update an existing deployment. Note that you can only _increase_ the number of topics (but there can be more partitions than instances).

## Usage (full system)

Start the system using:

```bash
docker compose --profile full up
```

Remember to **always** specify the profile in **all** compose commands. Otherwise, weird things are going to happen.

You can also add the `-d` flag to run the services in the background. The [*follow-component-logs.sh*](./follow-component-logs.sh) script can then be used to “reattach” to the output of all the pipeline components, without the Kafka cluster.

All the included configuration files are set up for the default single-broker Kafka configuration. To use the two-brokers configuration or even extend it to more nodes, follow the instructions in the [Adding a Kafka node](#adding-a-kafka-node) section.

### Using the configuration manager

The configuration manager is not included in the `full` profile. To use it, first refer to its [README](../src/config_manager/README.md) to see how the script should be set up on the host. Then add the `configmanager` profile to the Compose commands:

```bash
docker compose --profile full --profile configmanager up -d config-manager
```

## Usage (standalone)

The “standalone” configurations do not include PostgreSQL and the MongoDB data aggregations. The standalone input controller can be used to send data for processing. First, start the system:

```bash
docker compose --profile col up -d
```

The standalone input controller can be then executed as follows:

```bash
docker compose --profile col run --rm -v /file/to/load.txt:/app/file.txt standalone-input load -d -y /app/file.txt
```

The command mounts the file from `/file/to/load.txt` to the container, where the controller is executed to load this file in the direct mode (i.e. it expects one domain name per line) and with no interaction. The container is deleted after it finishes. 

The `col` profile only starts the collectors. To enable feature extraction, use the `colext` profile instead.

## Kafka

Should you need to connect to Kafka from the outside world, the broker is published to the host machine on port **31013**. You **must** modify your */etc/hosts* file to point `kafka1` to 127.0.0.1 and connect through this name.

Mind that in the default configuration, client authentication is **required** so you have to use one of the generated client certificates. You can also modify the broker configuration to allow plaintext communication (see below).

### Using Kafka with two nodes

The override Compose file changes the setup so that Kafka cluster of two nodes is used. They both run in the combined mode where each instance works both as a controller and as a broker. Node-client communication enforces the use of SSL with client authentication; inter-controller and inter-broker communication are done in plaintext over a separate network (`kafka-inter-node-network`) to reduce overhead.

Before using this setup, you should change the `connection.brokers` setting in all the *client\_properties/\*.toml* client configuration files! 

For some reason, the two-node setup tends to break randomly. I suggest to first start the Kafka nodes, then the initializer, and if it succeeds, start the rest of the services. You can use the *compose_cluster.sh* script which is just a shorthand for `docker compose -f compose.yml -f compose.cluster-override.yml [args]`.

```bash
# If some services were started before, remove them
./compose_cluster.sh down
# Start the databases
./compose_cluster.sh up -d postgres mongo
# Start the cluster
./compose_cluster.sh up -d kafka1 kafka2
# Initialize the cluster
# If this fails, try restarting the cluster
./compose_cluster.sh up initializer
# Start the pipeline services
./service_runner.sh cluster up
```

### Adding a Kafka node

If you want to test with more Kafka nodes, you have to:
- In *generate_secrets.sh*, change `NUM_BROKERS` and add an entry to `BROKER_PASSWORDS`; generate the new certificate(s).
- Add a new _envs/kafka**N**.env_ file:
    - change the IP and hostname in `KAFKA_LISTENERS` and `KAFKA_ADVERTISED_LISTENERS`,
    - change the paths in `KAFKA_SSL_KEYSTORE_LOCATION` and password in `KAFKA_SSL_KEYSTORE_PASSWORD`.
- Add the new internal broker IPs to `KAFKA_CONTROLLER_QUORUM_VOTERS` in **all** the *kafkaN.env* files.
- Add a new service to the Compose file:
    - copy an existing definition,
    - change the IP address in the service.
- Update the `BOOTSTRAP` environment variable for the _initializer_ service (in the Compose file).
- Update the `KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS` env. variable for the _kafka-ui_ service (in the Compose file).
- Update the `-s` argument in all the component services (in the Compose file).
- Preferrably (though the clients should manage with just one bootstrap server):
    - Update the *.toml* configurations for the Python clients (in the *client\_properties/* directory).
    - Update the `bootstrap.servers` property in _connect\_properties/10\_main.properties_.

### Using SSL for inter-broker communication

If you want to use SSL in inter-broker communication as well (for some reason), it should suffice to change `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` in all *envs/kafkaN.env* files. Set the controller and internal listener to use SSL: `CONTROLLER:SSL,INTERNAL:SSL`. Not tested in the current config.

### Enabling plaintext node-client communication

If you want to enable plaintext node-client communication, you can switch the listener to plaintext. Modify the `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` in the *envs/kafka1.env* file to contain `CLIENTS:PLAINTEXT` instead of `CLIENTS:SSL`. This only applies to the _internal_ clients, i.e. the ones connected to the isolated `kafka-clients` network. For this to have effect on the “outside world” clients that connect through the forwarded port 31010, instead modiy `CLIENTSOUT`.

To disable client authentication, change `KAFKA_SSL_CLIENT_AUTH` to `none` or `requested`.

## Debugging the Java components

If you need to debug the Java-based apps, you can enable the Java Debug Wire Protocol. Add this to the target service:

```yaml
environment:
    - JAVA_TOOL_OPTIONS=-agentlib:jdwp=transport=dt_socket,address=0.0.0.0:8111,server=y,suspend=n
ports:
    - "8111:8111"
```

Adjust the host port if you need. In IntelliJ Idea, you can then add a [Remote JVM Debug](https://www.jetbrains.com/help/idea/tutorial-remote-debug.html#create-run-configurations) run configuration.

## Included files breakdown

- *client_properties* contains the configuration files for the pipeline components.
- *connect_plugins* is used to load plugins to the Kafka Connect instance. Note that the MongoDB connector is added to the container at build.
- *connect_properties* contains the definitions of the Kafka Connect connectors.
- *db* contains the initialization scripts and configuration files for the database management systems. The passwords for the users, set only during the first execution of the services, are defined in the _.secrets_ files.
- *dockerfiles* contains supplementary Dockerfiles:
    - *initializer.Dockerfile* builds a simple container with the two scripts from *kafka_scripts/*,
    - *generate_secrets.Dockerfile* builds a container with the JRE to run the secrets generation procedure. It is used through the [generate_secrets_docker](./generate_secrets_docker.sh) script.
    - *kafka_connect.Dockerfile* builds a container based on [domrad/kafka-connect](../src/java_pipeline/connect.Dockerfile) that contains the MongoDB connector.
    - *run_aggregation.Dockerfile* builds a container with the Mongo shell to execute the aggregations.
- *envs* contains the environment variables that control the settings of Kafka and Kafbat UI.
- *extractor_data* contains the data files for the feature extractor, created in the DomainRadar research.
- *geoip_data* contains the [MaxMind GeoLite2 databases](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data).
- *kafka_scripts* contains the scripts for the initializer.
- *misc* contains a list of 400,000 domain names for testing, an SQL that inserts 200 domain names to PostgreSQL for testing, and the configuration for the secrets generation procedure.
- *mongo_aggregations* contains, well, various example MongoDB aggregations and a common script that executes them to create a view.
