# All-in-one Kafka & Pipeline

This folder contains a Docker Compose setup for an all-in-one testing environment with a Kafka cluster using encrypted communication, the collectors, the extractor and the classifier.

## Preparation

### Data

- Obtain your GeoLite2 City & ASN databases and place them in *geoip\_data*.
- Obtain a NERD token and place it in your *client\_properties/nerd.properties*.

### Security

You have to generate a CA, broker certificates and client certificates. You need to install openssl and Java (JRE is fine). Then you can simply run:

```bash
./generate_secrets.sh
``` 

If you're too lazy to install Java, you can use the included `generate_secrets` Dockerfile:

```bash
docker build . --tag generate-secrets -f generate_secrets.Dockerfile
docker run -v $PWD/secrets:/pipeline-all-in-one/secrets generate-secrets:latest
```

You can change the certificates' validity and passwords by setting the variables at the top of that script. If you do, you have to also change the passwords in the _kafka\*.env_ files and the files in _client\_properties/_ for all the clients.

For the love of god, don't use the generated keys and certificates outside of development. (If you do, at least store the CA somewhere safe.)

### Component images

Clone the [domainradar-colext](https://github.com/nesfit/domainradar-colext/) repo and build the Docker images:

```bash
cd java_pipeline
docker build --target streams -t domrad-java-streams .
docker build --target standalone -t domrad-java-standalone .
cd ../python_pipeline
docker build --target production -t domrad-python .
```

## Usage

When you have your setup and crypto goodies ready, you can simply start the containers. It should automagically work:

```bash
docker compose up
```

### Accessing Kafka

Should you need to connect to Kafka from the outside world, the two brokers are published to the host machine on ports **9093** and **9094**. You must modify your */etc/hosts* file to point `kafka1` and `kafka2` to 127.0.0.1.

The Compose configuration defines a *bridge* network `kafka-client-network`. You can add other containers to it and access Kafka using the same ports. The broker containers have fixed IPs: 192.168.45.10 and 192.168.45.20; however, you must always use the hostnames `kafka1` and `kafka2` to access them.

Mind that in the default configuration, client authentication is **required** so you have to use one of the generated client certificates. You can also modify the broker configuration to allow plaintext communication (see below).

## Under the hood & Modifications

The Compose file builds a Kafka cluster of two nodes. They both run in the combined mode where each instance works both as a controller and as a broker. This is done simply to simulate a small cluster. Node-client communication enforces the use of SSL with client authentication; inter-controller and inter-broker communication are done in plaintext over a separate network (`kafka-inter-node-network`) to reduce overhead.

### Adding a Kafka node

If you want to test with more Kafka nodes, you have to:
- In *generate_secrets.sh*, change `NUM_BROKERS` and add an entry to `BROKER_PASSWORDS`; generate the new certificate(s).
- Add a new _kafka**N**.env_ file:
    - change the IP and hostname in `KAFKA_LISTENERS` and `KAFKA_ADVERTISED_LISTENERS`,
    - change the paths in `KAFKA_SSL_KEYSTORE_LOCATION` and password in `KAFKA_SSL_KEYSTORE_PASSWORD`.
- Add the new internal broker IPs to `KAFKA_CONTROLLER_QUORUM_VOTERS` in **all** the *kafkaN.env* files.
- Add a new service to the Compose file:
    - copy an existing definition,
    - change the IP address in the service.
- Update the `BOOTSTRAP` environment variable for the _initializer_ service (in the Compose file).
- Update the `-s` argument in all the component services.
- Update the *.toml* configurations for the Python clients.

### Using single-node Kafka

The repo comes with a pre-made Compose file *docker-compose.single.yml* for a single-node configuration. Before using it, you need to change the `connection.brokers` setting in all the *client\_properties/.toml* client configuration files and the *kafka\_ui.env* file. Then, simply run:

```bash
docker compose -f docker-compose.single.yml up
```

### Using SSL for inter-broker communication

If you want to use SSL in inter-broker communication as well (for some reason), it should suffice to change `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` in all *kafkaN.env* files. Set the controller and internal listener to use SSL: `CONTROLLER:SSL,INTERNAL:SSL`. Not tested in the current config.

### Enabling plaintext node-client communication

If you want to enable plaintext node-client communication, you can switch the listener to plaintext. Modify the `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` in all *kafkaN.env* files to `CLIENTS:PLAINTEXT`.

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