# All-in-one Kafka & Pipeline

This folder contains a Docker Compose setup for a DomainRadar testing environment. It includes a Kafka cluster using encrypted communication, the pipeline components (collectors, extractor, classifier), a PostgreSQL database, a MongoDB database, Kafka Connect configured to push data to them, and a web UI.

Three Compose files are included. The default [*docker-compose-yml*](./docker-compose.yml) file provides a single-broker setup, while the[*cluster.docker-compose.yml*](./cluster.docker-compose.yml) file provides a two-brokers setup. The database services are provided by a separate Dockerfile, [*db.docker-compose.yml*](./db.docker-compose.yml).

## Exposed ports and services

- _kafka1_, the first Kafka broker: 9093
    - SSL authentication, see below.
- _kafka2_, the second Kafka broker: 9094 (two-brokers setup only)
- _kafka-ui_, the Kafka web UI: 31000
    - No authentication is used!
- _adminer_, a web tool for accessing Postgres or Mongo: 31001
    - Credentials must be provided manually when opened.
- _kafka-connect_, the Kafka Connect REST API: 31002
    - No authentication (will be changed).
- _postgres_, the PostgreSQL database: 31010
    - Password (SCRAM) authentication (probably will be changed, see below).
- _mongo_, the MongoDB Community database: 31011
    - Password (SCRAM) authentication (probably will be changed, see below).

## Preparation

### Data

- Obtain your GeoLite2 City & ASN databases and place them in *geoip\_data*.
- Obtain a NERD token and place it in your *client\_properties/nerd.properties*.

### Security

You have to generate a CA, broker certificates and client certificates. You need to have openssl and Java installed (JRE is fine). Then you can simply run:

```bash
./generate_secrets.sh
``` 

You can also use the included Docker image:

```bash
./generate_secrets_docker.sh
```

You can change the certificates' validity and passwords by setting the variables at the top of the *generate_secrets.sh* script. If you do, you have to also change the passwords in the _envs/kafka\*.env_ files and the files in _client\_properties/_ for all the clients.

For the love of god, don't use the generated keys and certificates outside of development. (If you do, at least store the CA somewhere safe.)

---

The _db_ directory contains configuration for the database, including user passwords. Be sure to change them when actually deploying this somewhere. The passwords must be set accordingly in the services that use them, i.e., Kafka Connect (*connect_properties*), the prefilter, the UI, the ingestion controller (not yet included).

### Component images

Clone the [domainradar-colext](https://github.com/nesfit/domainradar-colext/) repo and build the Docker images (use `-h` to see the possible flags):

```bash
./build_docker_images.sh
```

## Usage

First, start the database services:

```bash
docker compose -f db.docker-compose.yml up -d
```

Then start the Kafka and DomainRadar pipeline services:

```bash
docker compose up
```

You can also add the `-d` flag to run the services in the background. The [*follow-component-logs.sh*](./follow-component-logs.sh) script can then be used to “reattach” to the output of all the pipeline components, without the Kafka cluster.

The pipeline services use a Docker network called `domainradar-db-network` created by the `db` Compose file. It **won't start** if this network doesn't exist.

### Accessing Kafka

Should you need to connect to Kafka from the outside world, the two brokers are published to the host machine on ports **9093** and **9094**. You must modify your */etc/hosts* file to point `kafka1` and `kafka2` to 127.0.0.1.

The Compose configuration defines a *bridge* network `kafka-client-network`. You can add other containers to it and access Kafka using the same ports. The broker containers have fixed IPs: 192.168.45.10 and 192.168.45.20; however, you must always use the hostnames `kafka1` and `kafka2` to access them.

Mind that in the default configuration, client authentication is **required** so you have to use one of the generated client certificates. You can also modify the broker configuration to allow plaintext communication (see below).

## Pipeline "under the hood" & modifications

The included configuration files are set up for the default single-broker configuration. To use the two-brokers configuration or even extend it to more nodes, follow the instructions in the following paragraphs.

### Using Kafka with two nodes

The *cluster.docker-compose.yml* Compose file builds a Kafka cluster of two nodes. They both run in the combined mode where each instance works both as a controller and as a broker. This is done simply to simulate a small cluster. Node-client communication enforces the use of SSL with client authentication; inter-controller and inter-broker communication are done in plaintext over a separate network (`kafka-inter-node-network`) to reduce overhead.

Before using the , you need to change the `connection.brokers` setting in all the *client\_properties/\*.toml* client configuration files! Then, simply run:

```bash
docker compose -f cluster.docker-compose.yml up
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
- Update the *.toml* configurations for the Python clients (in the *client\_properties/* directory).

### Using SSL for inter-broker communication

If you want to use SSL in inter-broker communication as well (for some reason), it should suffice to change `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` in all *envs/kafkaN.env* files. Set the controller and internal listener to use SSL: `CONTROLLER:SSL,INTERNAL:SSL`. Not tested in the current config.

### Enabling plaintext node-client communication

If you want to enable plaintext node-client communication, you can switch the listener to plaintext. Modify the `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` in all *envs/kafkaN.env* files to `CLIENTS:PLAINTEXT`.

To disable client authentication, change `KAFKA_SSL_CLIENT_AUTH` to `none` or `requested`.

### Debugging the Java components

If you need to debug the Java-based apps, you can enable the Java Debug Wire Protocol. Add this to the target service:

```yaml
environment:
    - JAVA_TOOL_OPTIONS=-agentlib:jdwp=transport=dt_socket,address=0.0.0.0:8111,server=y,suspend=n
ports:
    - "8111:8111"
```

Adjust the host port if you need. In IntelliJ Idea, you can then add a [Remote JVM Debug](https://www.jetbrains.com/help/idea/tutorial-remote-debug.html#create-run-configurations) run configuration.

## The database services

TODO.