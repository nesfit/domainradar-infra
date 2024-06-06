# Kafka pipeline & models

The main pipeline consists of several components that mostly accept a request from a topic, do a thing (e.g. collect some data) and publish the result to another topic (or to multiple topics). 

**See [img/kafka-pipeline.pdf](img/kafka-pipeline.pdf) that contains an overview diagram of the pipeline.**

> KS = Java / Kafka Streams; PC = Java / Parallel Consumer; F = Python / Faust. \
> DN = Domain Name; AS = Autonomous System; RTT = Round-Trip Time (ping).

The components shown in green collect data for a domain name, the blue components collect data for an IP address (though they are keyed with a DN/IP pair). The purple Merger component perform a *gather* operation, merging together all the different results related to a domain name. The thin cylinders represent Kafka topics.

All the events (= Kafka messages) in the intermediary *processed_\** topics and the *classification_results* topic are exported (with varying granularity) to the PostgreSQL and MongoDB databases through Kafka Connect. See [this page](./kafka_connect.md) for more information.


## Models

In this document, the data structures are described using a syntax similar to Python dataclasses. However, in the actual implementation, they are serialized as JSON (this will later be changed to a binary format with pre-defined schemas, probably Avro). The classes implementing the models are [here (Java)](https://github.com/nesfit/domainradar-colext/tree/main/java_pipeline/common/src/main/java/cz/vut/fit/domainradar/models) and [here (Python)](https://github.com/nesfit/domainradar-colext/blob/main/python_pipeline/common/models.py).

The serialized values **must** contain all the specified fields. If `| None` is not present, the field **must** have a non-null value.

The base model for all events stored in the *processed_\** topics is `Result`. Every component adds its own specific fields carrying the actual result data to this base structure.

```python
class Result:
    statusCode: int32
    error: str | None 
    lastAttempt: int64
```

The status codes with descriptions can be found [here](https://github.com/nesfit/domainradar-colext/blob/main/java_pipeline/common/src/main/java/cz/vut/fit/domainradar/models/ResultCodes.java). The value of 0 means success.\
The error field *may* contain a human-readable error message if the status code is not 0.\
The last attempt field contains a UNIX timestamp (in milliseconds) of when the operation was *finished*.

## Domain-based collectors

Process requests sent to the zone, DNS, TLS and RDAP-DN collectors are always keyed by a domain name. The keys of the Kafka events should be pure ASCII-encoded strings.

### Zone collector

- Input topic: *to_process_zone*
    - Key: string – DN
    - Value: empty or `ZoneRequest`
- Output topics:
    - *processed_zone*: zone data
        - Key: string – DN
        - Value: `ZoneResult`
    - *to_process_dns*: request for the [DNS collector](#dns--tls-collector)
    - *to_process_RDAP_DN*: request for the [RDAP-DN collector](#rdap-dn-collector)
- **TODO: Errors**

```python
class ZoneProcessRequest:
    collectDNS: bool
    collectRDAP: bool
    dnsTypesToCollect: list[str] | None
    dnsTypesToProcessIPsFrom: list[str] | None
```

The request body is optional. If present, it may contain two lists passed to the `DNSProcessRequest` (see below) if the zone is discovered. The two booleans control whether a DNS and an RDAP process requests will be sent to the respective *to_process_\** topics.

```python
class ZoneResult(Result):
    zone: ZoneInfo | None  # null iff statusCode != 0

class ZoneInfo:
    zone: str
    soa: SOARecord
    publicSuffix: str
    registrySuffix: str
    primaryNameserverIps: set[str] | None
    secondaryNameservers: set[str] | None
    secondaryNameserverIps: set[str] | None

class SOARecord:
    primaryNs: str
    respMailboxDname: str
    serial: str
    refresh: int64
    retry: int64
    expire: int64
    minTTL: int64
```

The primary/secondary NS IPs lists may be null if the corresponding DNS resolutions failed. See [this wiki page](https://github.com/google/guava/wiki/InternetDomainNameExplained) for an explanation of what public and registry suffixes mean.

### DNS collector

- Input topic: *to_process_DNS*: request for the DNS collector
    - Key: string – DN
    - Value: `DNSRequest`
- Output topics:
    - *processed_DNS*: DNS scan result
        - Key: string – DN
        - Value: `DNSResult`
    - *to_process_TLS*: request for the TLS collector
        - Key: string - DN
        - Value: string - the target IP to connect to
    - *to_process_IP*: request for the IP collectors
        - Key: `IPToProcess` (a DN/IP pair)
        - Value: empty
- **TODO: Errors**

```python
class DNSProcessRequest:
    typesToCollect: list[str] | None
    typesToProcessIPsFrom: list[str] | None
    zoneInfo: ZoneInfo
```

The request body is required. The `zoneInfo` property must contain a valid zone data. 

The `typesToCollect` list is optional and controls which DNS record types will be queried.\
The possible values are: `A, AAAA, CNAME, MX, NS, TXT`, unknown values are ignored.\
If the list is **null or empty**, the value from the collector's configuration will be used.

The `typesToProcessIPsFrom` list is optional and controls the source records types from which IP addresses will be published to *to_process_IP* for further data collection.\
The possible values are: `A, AAAA, CNAME, MX, NS`, unknown values are ignored.\
If the list is **null**, the value from the collector's configuration will be used (unlike in the previous property, non-null but empty value will result in no IPs being published).

```python
class DNSResult(Result):
    dnsData: DNSData | None  # null iff statusCode != 0
    ips: list[IPFromRecord] | None  # null iff statusCode != 0

class IPFromRecord:
    domainName: str
    ip: str

class DNSData:
    A: set[str] | None
    AAAA: set[str] | None
    CNAME: CNAMERecord | None
    MX: list[MXRecord] | None
    NS: list[NSRecord] | None
    TXT: list[str] | None
    hasDNSKEY: bool
    errors: dict[str, str] | None # mappings of "A", "AAAA", ... -> error desc.
    ttlValues: dict[str, int64]   # mappings of "A", "AAAA", ... -> TTL value

class CNAMERecord:
    value: str
    relatedIps: set[str] | None

class MXRecord:
    value: str
    priority: int32
    relatedIps: set[str] | None

class NSRecord:
    nameserver: str
    relatedIps: set[str] | None
```

Each of the `DNSData` properties corresponding to a record type will be non-null iff the record existed in DNS and was fetched sucessfully.\
If DNS returns NXDOMAIN or no answer, the property will be null.\
If other error occurs during the single query, the property will be null and the `errors` dictionary will be populated with a pair keyed by the record type and a value giving a human-readable error description (e.g., "Timeout").

The `ttlValues` dictionary contains mappings where the key is a successfully fetched record type and the value is the TTL value for the corresponding RRset.

The `relatedIps` properties of `CNAMERecord`, `MXRecord`, `NSRecord` may contain a set of IP addresses acquired by querying a common recursive DNS resolver for the A and AAAA records related to the CNAME value / MX value / nameserver.

### TLS collector

- Input topic: *to_process_TLS*: request for the TLS collector
    - Key: string – DN
    - Value: string - an IP address
- Output topic: *processed_TLS*: TLS handshake and certificate result
    - Key: string – DN
    - Value: `TLSResult`
- **TODO: Errors**

The input value must always be a non-null, non-empty, ASCII-encoded string that contains an IP address. The collector will attempt to establish a TLS connection with this IP on port 443, using the domain name from the key as the SNI (Server Name Indication) value.

```python
class TLSResult(Result):
    tlsData: TLSData | None  # null iff statusCode != 0

class TLSData:
    fromIp: str
    protocol: str
    cipher: str
    certificates: list[Certificate]

class Certificate:
    dn: str
    derData: bytes
```
The `protocol` field may contain values `"TLSv1.0", "TLSv1.1", "TLSv1.2", "TLSv1.3"`, according to the protocol determined in the handshake.

The `cipher` property contains an [IANA name (description)](https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml#tls-parameters-4) of the established ciphersuite.

The `certificates` list contains `Certificate` pairs of distinguished name and raw DER data. It is ordered so that the leaf certificate comes first (at index 0).

### RDAP-DN collector

- Input topic: *to_process_RDAP_DN*: request for the RDAP-DN collector
    - Key: string – DN
    - Value: empty or `RDAPDomainRequest`
- Output topic: *processed_RDAP_DN*: RDAP/WHOIS query result
    - Key: string – DN
    - Value: `RDAPDomainResult`
- **TODO: Errors**

```python
class RDAPDomainRequest:
    zone: str | None
```

The request object is not required. If it is provided and it contains a non-null value of the `zone` field, this value will be used as the RDAP (and WHOIS) query target. Otherwise, the source domain name will be used; and, in case of a failure, the "registered domain name" (i.e., one level above the public suffix) will also be tried.

```python
class RDAPDomainResult(Result):
    rdapTarget: str
    rdapData: dict[str, Any] | None  # null iff statusCode != 0
    entities: dict[str, Any] | None  # null iff statusCode != 0

    whoisStatusCode: int  # the default value is -1
    whoisError: str | None  # null iff whoisStatusCode != 0
    whoisRaw: str | None  # null iff whoisStatusCode != 0
    whoisParsed: dict[str, Any] | None  # null iff whoisStatusCode != 0
```

The `statusCode` field corresponds to the RDAP query result. If RDAP succeeds, `rdapTarget` contains the domain name that the result actually succeeded for (either the source DN, or the zone DN); `rdapData` contains the deserialized RDAP response JSON. The `entities` field in the RDAP response, if it exists, is removed from the RDAP data and placed in the `entitites` field of the result. It is further processed by following links (a response for a DN may only contain handles to the entities instead of their full details).

A non-zero value of `statusCode` may not signalise a total failure. When (and only if) RDAP fails, WHOIS is tried instead. In this case, `whoisStatusCode` will not be -1, `whoisRaw` may contain the raw WHOIS data, `whoisParsed` may contain a dictionary of parsed WHOIS data (as determined by the [pogzyb/whodap](https://github.com/pogzyb/whodap) library). If `whoisStatusCode` is not 0 nor -1, the `whoisError` field will contain a human-readable error message.

## IP-based collectors

Process requests sent to the RDAP-DN, NERD, RTT and GEO-ASN collectors are always keyed by an `IPToProcess` object, which is essentially a domain name/IP address pair. The IP is transferred in its common string form, both IPv4 and IPv6 addresses are supported.

The request body may be null or an instance of `IPRequest`. It serves as a means of specifying which collectors should run. If the `collectors` list is non-null and empty, no collectors will be triggered. If the field or the body are null, all collectors will be triggered.
```python
class IPToProcess:
    domainName: str
    ip: str

class IPRequest:
    collectors: list[str] | None
```



The base result model for all IP collector results is `CommonIPResult of TData`.
```python
class CommonIPResult[TData](Result):
    collector: str
    data: TData | None  # null iff statusCode != 0
```

These results carry a string identifier of the collector that created them. The actual data is always stored in field called `data`.

---

- Common input topic for all IP-based collectors: *to_process_IP*
    - Key: `IPToProcess`
    - Value: empty or `IPRequest`
- Common output topic for all IP-based collectors: *collected_IP_data*
    - Key: `IPToProcess`
    - Value: `CommonIPResult of TData` (`TData` is a collector-specific data model)


### RDAP-IP collector

- Output value: `RDAPIPResult` ~ `CommonIPResult of dict[str, Any]`
- **TODO: Errors**

TODO

### NERD collector

TODO


### GeoIP & Autonomous System collector

TODO

### RTT (ping) collector

TODO

## All data merger

TODO