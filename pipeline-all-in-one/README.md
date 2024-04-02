# All-in-one Kafka & Pipeline

This folder contains a Docker Compose file for an all-in-one testing environment with encrypted Kafka cluster, the collectors, the extractor and the classifier.

## Preparation

First (and only once) you have to generate a CA, broker certificates and client certificates. You need to install openssl and Java (JRE is fine). Then you can simply run:

```bash
./generate_secrets.sh
``` 

If you're too lazy to install Java, you can use the included `generate_secrets` Dockerfile:

```bash
docker build . --tag generate-secrets -f generate-secrets.Dockerfile
docker run -v "$PWD/secrets":/pipeline-all-in-one/secrets generate-secrets:latest
```

You can change the certificates' validity and passwords by setting the variables at the top of that script. If you do, you have to also change the passwords in the kafka*.env files and the *.properties files for the initializer and all the clients.

For the love of god, don't use the generated keys and certificates outside of development. (If you do, at least store the CA somewhere safe.)

## Usage

When you have your crypto goodies ready, you can simple start the containers. It should automagically work:

```bash
docker compose up
```

### Accessing Kafka

Should you need to connect to Kafka from the outside world, the two brokers are published to the host machine on ports **9093** and **9094**. You should modify your `/etc/hosts` file to point `kafka1` and `kafka2` to 127.0.0.1.

Mind that in the default configuration, client authentication is **required** so you have to use one of the generated client certificates. You can also modify the broker configuration to allow plaintext communication (see below).


## Under the hood & Modifications

TODO
