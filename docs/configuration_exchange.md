# Runtime configuration exchange

All the components in the system use various configuration properties. This document describes how configuration may be distributed among them at runtime.

Kafka is used as the data bus for storing and distributing the configurations. All configurations are stored in the `system_configurations` topic. All events in this topic must have:
- key: the target component ID,
- value: the entire configuration blob serialized as JSON.

When any component starts, it **must** load its configuration by reading the `system_configurations` topic from the start (offset 0) and applying the *last* event with a key corresponding to the component's ID. The topic is often compacted, so only the most recent configuration event will be stored.

If no configuration event for the component is found in the `system_configurations` topic, the component **must** use apply its predefined defaults and **publish** them to the topic.

This implies that Kafka connection parameters must be configured statically. The components **should** ensure that the Kafka connection parameters cannot be changed using the runtime configuration exchange.

The available component IDs are:
- loader
- collector-zone
- collector-dns
- collector-tls
- collector-nerd
- collector-geoip
- collector-rdap-dn
- collector-rdap-ip
- collector-rtt
- merger
- extractor
- classifier-unit

## Configuration format (loader)

The configuration exchange JSON for the loader looks like this:
```json
{
    "sources": [
        {
            "type": "ELKSource",
            "args": [],
            "kwargs": {
                "elk_url": "[ELK URL]",
            }
        }
    ],
    "filters": [
        {
            "type": "FileBlockListFilter",
            "args": [],
            "kwargs": {
                "filter_result_action": FilterAction.STORE,
                "filename": "block.list"
            }
        },
        {
            "type": "FileBlockListFilter",
            "args": [],
            "kwargs": {
                "filter_result_action": FilterAction.DROP,
                "filename": "block2.list"
            }
        }
    ],
    "outputs": [
        {
            "type": "StdOutput",
            "args": [],
            "kwargs": {},
        },
        {
            "type": "PostgresOutput",
            "args": [],
            "kwargs": {
                "host": "[PostgreSQL Host]",
                "port": 31010,
                "username": "prefilter",
                "password": "[PostgreSQL Password]",
                "database": "domainradar",
            }
        }
    ]
}
```

## Configuration format (Java-based data pipeline components)

For the pipeline components implemented in Java (stages marked by _KS_ or _PC_ in [kafka-pipeline.pdf](img/kafka-pipeline.pdf)), the configuration exchange JSON will be transformed into the Java Properties file accepted by the components. See the [**definition**](https://github.com/nesfit/domainradar-colext/blob/main/java_pipeline/common/src/main/java/cz/vut/fit/domainradar/CollectorConfig.java) for a list of accepted configuration keys. No type checks are performed!

The configuration exchange object has two top-level properties. Its `collector` section maps to the collector-specific configuration keys, as defined in the file linked above. Omit the `collectors.` prefix from the key. \
The `system` section can be used to directly manipulate the options for the Kafka Consumers/Producers. 


The configuration exchange JSON has this format:
```json
{
    "collector": {
        "any property prefixed with collector without the prefix": "value, e.g.",
        "parallel.consumer.max.concurrency": 32,
        "nerd.token": "xyz"
    },
    "system": {
        "any non-collector-specific property": "value, e.g.",
        "producer.compression.type": "zstd",
    }
}
```

For example, the JSON:
```json
{
    "collector": {
        "parallel.consumer.max.concurrency": 32,
        "nerd.token": "xyz",
        "nerd.timeout": 5
    },
    "system": {
        "producer.compression.type": "zstd",
    }
}
```
will be mapped to:
```properties
collectors.parallel.consumer.max.concurrency=32
collectors.nerd.token=xyz
collectors.nerd.timeout=5
producer.compression.type=zstd
```

## Configuration format (Python-based data pipeline components)

For the pipeline components implemented in Python (stages marked by _F_ in [kafka-pipeline.pdf](img/kafka-pipeline.pdf)), the configuration exchange JSON will be transformed into the TOML configuration file accepted by the components. See [**the configuration example**](https://github.com/nesfit/domainradar-colext/blob/main/python_pipeline/config.example.toml) for a list of accepted configuration keys. Generally, the collector-specific options will be properties of a top-level object named by the collector; and another top-level object `faust` passes options directly to the underlying framework.

The configuration exchange JSON will be mapped 1:1 to the target TOML (using [tomli-w](https://pypi.org/project/tomli-w)). However, the `connection` section and the `app_id` keys will be omitted! 

For example:
```json
{
    "faust": {
        "producer_compression_type": "zstd"
    },
    "rdap_ip": {
        "http_timeout_sec": 5,
        "app_id": "this-wont-be-used"
    }
}
```
will be mapped to:
```toml
[faust]
producer_compression_type = "zstd"

[rdap_ip]
http_timeout_sec = 5
```
