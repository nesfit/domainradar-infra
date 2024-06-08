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

The status codes with descriptions can be found [here](https://github.com/nesfit/domainradar-colext/blob/main/java_pipeline/common/src/main/java/cz/vut/fit/domainradar/models/ResultCodes.java). The value of 0 means success. All collectors may return the INTERNAL_ERROR code that signalises an unexpected error.\
The error field *may* contain a human-readable error message if the status code is not 0.\
The last attempt field contains a UNIX timestamp (in milliseconds) of when the operation was *finished*.

## Domain-based collectors

Process requests sent to the zone, DNS, TLS and RDAP-DN collectors are always keyed by a domain name. The keys of the Kafka events should be pure ASCII-encoded strings.

### Zone collector

The zone collector accepts the domain name and finds the SOA record of the zone that contains this domain name. When the SOA is found, finds the addresses of the primary nameserver, secondary nameserver hostnames and their addresses.

When the input is a public suffix (e.g. 'cz', 'co.uk' or 'hakodate.hokkaido.jp'), the resolution is performed so the result is the SOA record of the suffix. Otherwise, the public suffix is skipped (e.g., for 'fit.vut.cz', the query is made for 'vut.cz' and 'fit.vut.cz' but not 'cz').

- Input topic: *to_process_zone*
    - Key: string – DN
    - Value: empty or `ZoneRequest`
- Output topics:
    - *processed_zone*: zone data
        - Key: string – DN
        - Value: `ZoneResult`
    - *to_process_dns*: request for the [DNS collector](#dns--tls-collector)
    - *to_process_RDAP_DN*: request for the [RDAP-DN collector](#rdap-dn-collector)
- Errors:
    - CANNOT_FETCH: Timed out when waiting for a DNS response.
    - NOT_FOUND: No zone found (probably a dead domain name).

```python
class ZoneProcessRequest:
    collectDNS: bool
    collectRDAP: bool
    dnsTypesToCollect: set[str] | None
    dnsTypesToProcessIPsFrom: set[str] | None
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

The primary/secondary NS IPs lists may be null if the corresponding DNS resolutions failed. See [this wiki page](https://github.com/google/guava/wiki/InternetDomainNameExplained) for an explanation of what public and registry suffixes mean. **Registry suffixes currently don't work and are always set to the public suffix.**

### DNS collector

The DNS collector queries the primary nameservers of the input domain name for the requested or pre-configured record types. It also checks the presence of a DNSKEY in the zone. For record types that carry a hostname (CNAME, MX, NS), it also finds the target IP addresses using a common recursive resolver.

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
- Errors:
    - INVALID_DOMAIN_NAME: Could not parse the input domain name.
    - OTHER_DNS_ERROR: All issued queries (for all RRtypes) failed. `dnsData` is not null, its `errors` field is set.
    - TIMEOUT: All issued queries (for all RRtypes) timed out.
    - In addition to the common status and error fields, `dnsData` bears information on per-query errors (see below).  

```python
class DNSProcessRequest:
    typesToCollect: set[str] | None
    typesToProcessIPsFrom: set[str] | None
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
    dnsData: DNSData | None  # null iff statusCode not in (0, OTHER_DNS_ERROR)
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

Each of the `DNSData` properties corresponding to a record type will be non-null iff the record existed in DNS and was fetched sucessfully. If DNS returns NXDOMAIN or no answer, the property will be null.

If another kind of error occurs during a single DNS query, the corresponding property will be null. The `errors` dictionary will be populated with a pair keyed by the record type and a value giving a human-readable error description (e.g., "Timeout"). If all queries fail and at least one of the errors is not a timeout, the response will have the OTHER_DNS_ERROR status code but the data object with the `errors` dictionary will be present. If all queries fail with a timeout, `dnsData` will be null and the overall status code will be TIMEOUT.

|                         | Property not null | Property null                         |
| ----------------------- | ----------------- | ------------------------------------- |
| **Key not in** `errors` | record exists     | record doesn't exist or not requested |
| **Key in** `errors`     | cannot happen     | error processing the record type      |

The `ttlValues` dictionary contains mappings where the key is a successfully fetched record type and the value is the TTL value for the corresponding RRset.

The `relatedIps` properties of `CNAMERecord`, `MXRecord`, `NSRecord` may contain a set of IP addresses acquired by querying a common recursive DNS resolver for the A and AAAA records related to the CNAME value / MX value / nameserver.

### TLS collector

The TLS collector opens a TCP connection on an input IP address, port 443, attempts to perform a TLS handshake and, if successful, outputs data on the used protocol, ciphersuite and a list of DER-encoded certificates presented by the server.

- Input topic: *to_process_TLS*: request for the TLS collector
    - Key: string – DN
    - Value: string - an IP address
- Output topic: *processed_TLS*: TLS handshake and certificate result
    - Key: string – DN
    - Value: `TLSResult`
- Errors:
    - TIMEOUT: Connection or socket I/O timed out.
    - CANNOT_FETCH: Other socket error occurred.

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
The `protocol` field may contain values `"TLSv1", "TLSv1.1", "TLSv1.1", "TLSv1.2", "TLSv1.3"`, according to the protocol determined in the handshake.

The `cipher` property contains an [IANA name (description)](https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml#tls-parameters-4) of the established ciphersuite.

The `certificates` list contains `Certificate` pairs of distinguished name and raw DER data. It is ordered so that the leaf certificate comes first (at index 0).

### RDAP-DN collector

The RDAP-DN collector looks up domain registration data using the Registration Data Access Protocol. The legacy WHOIS service is used as a fallback in case the TLD does not provide RDAP access or when an error occurs.

- Input topic: *to_process_RDAP_DN*: request for the RDAP-DN collector
    - Key: string – DN
    - Value: empty or `RDAPDomainRequest`
- Output topic: *processed_RDAP_DN*: RDAP/WHOIS query result
    - Key: string – DN
    - Value: `RDAPDomainResult`
- Errors (`statusCode`):
    - RDAP_NOT_AVAILABLE: An RDAP service is not provided for the TLD.
    - NOT_FOUND: The RDAP entity was not found (i.e., the DN does not exist in RDAP).
    - RATE_LIMITED: Too many requests to the target RDAP server.
    - OTHER_EXTERNAL_ERROR: Other error happened (such as non-OK RDAP status code).
- Erros (`whoisStatusCode`, see below):
    - WHOIS_NOT_PERFORMED: RDAP succeeded, no WHOIS query was made.
    - NOT_FOUND: As above.
    - RATE_LIMITED: As above.
    - OTHER_EXTERNAL_ERROR: As above.

```python
class RDAPDomainRequest:
    zone: str | None
```

The request object is not required. If it is provided and it contains a non-null value of the `zone` field, this value will be used as the RDAP (and WHOIS) query target. Otherwise, the source domain name will be used; and, in case of a failure, the DN one level above the public suffix (a "possibly registered domain name") will also be tried.

```python
class RDAPDomainResult(Result):
    rdapTarget: str
    rdapData: dict[str, Any] | None  # null iff statusCode != 0
    entities: dict[str, Any] | None  # null iff statusCode != 0

    whoisStatusCode: int32  # the default value is -1
    whoisError: str | None  # null iff whoisStatusCode != 0
    whoisRaw: str | None  # null iff whoisStatusCode != 0
    whoisParsed: dict[str, Any] | None  # null iff whoisStatusCode != 0
```

The `statusCode` field corresponds to the RDAP query result. If RDAP succeeds, `rdapTarget` contains the domain name that the result actually succeeded for (the source DN, the zone DN or the "registered DN"); `rdapData` contains the deserialized RDAP response JSON. The `entities` field in the RDAP response, if it exists, is removed from the RDAP data and placed in the `entitites` field of the result. It is further processed by following links (a response for a DN may only contain handles to the entities instead of their full details).

A non-zero value of `statusCode` may not signalise a total failure. When (and only if) RDAP fails, WHOIS is tried instead. In this case, `whoisStatusCode` will not be -1, `whoisRaw` may contain the raw WHOIS data, `whoisParsed` may contain a dictionary of parsed WHOIS data (as determined by the [pogzyb/whodap](https://github.com/pogzyb/whodap) library). If `whoisStatusCode` is not 0 nor -1, the `whoisError` field will contain a human-readable error message.

## IP-based collectors

Process requests sent to the RDAP-DN, NERD, RTT and GEO-ASN collectors are always keyed by an `IPToProcess` object, which is essentially a domain name/IP address pair. The IP is transferred in its common string form, both IPv4 and IPv6 addresses are supported.

The request body may be null or an instance of `IPRequest`. It serves as a means of specifying which collectors should run. If the `collectors` list is not null and empty, no collectors will be triggered. If the field or the body are null, all collectors will be triggered.
```python
class IPToProcess:
    domainName: str
    ip: str

class IPRequest:
    collectors: set[str] | None
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

The RDAP-DN collector looks up IP registration data using the Registration Data Access Protocol. Both v4 and v6 are supported.

- Output value: `RDAPIPResult` ~ `CommonIPResult of dict[str, Any]`
- Errors:
    - INVALID_ADDRESS: Could not parse the input string as an IP address.
    - NOT_FOUND: The RDAP entity was not found (i.e., the IP does not exist in RDAP).
    - RATE_LIMITED: Too many requests to the target RDAP server.
    - OTHER_EXTERNAL_ERROR: Other error happened (such as non-OK RDAP status code).

The `data` field of an `RDAPIPResult` is the deserialized JSON response from RDAP. It is taken as-is without any further processing.

### NERD collector

The NERD collectors retrieves the reputation score for the input IP address from CESNET's [NERD](https://nerd.cesnet.cz/) reputation system. 

- Output value: `NERDResult` ~ `CommonIPResult of NERDData`
- Errors:
    - INVALID_FORMAT: Invalid NERD response (content length mismatch).
    - CANNOT_FETCH: NERD responded with a non-OK status code.
    - TIMEOUT: Connection to NERD timed out or waited too long for the answer.

```python
class NERDData:
    reputation: float64  # the default value is 0.0
```

The `data` field of a `NERDResult` is `NERDData`, a container with a single floating-point value representing the reputation. If the address doesn't exist in NERD, the value will be 0. This data model may be extended in the future.

### GeoIP & Autonomous System collector

The GEO-ASN collector looks up information on the geographical location and autonomous system of the input IP address by querying MaxMind's [GeoIP](https://dev.maxmind.com/geoip) databases (locally stored). 

- Output value: `GeoIPResult` ~ `CommonIPResult of GeoIPData`

```python
class GeoIPData:
    continentCode: str | None
    countryCode: str | None
    region: str | None
    regionCode: str | None
    city: str | None
    postalCode: str | None
    latitude: float64 | None
    longitude: float64 | None
    timezone: str | None
    registeredCountryGeoNameId: int64 | None
    representedCountryGeoNameId: int64 | None
    asn: int64 | None
    asnOrg: str | None
    networkAddress: str | None
    prefixLength: int32 | None
```
The `data` field of a `NERDResult` is `NERDData`, a container with values retrieved from the GeoIP (GeoLite2) databases.

### Round-trip time (ping) collector

The RTT collector performs a common ping: it sends a number of ICMP Echo messages to the input IP address, waits for the ICMP Echo Reply answers and outputs basic statistics of the process.

- Output value: `RTTResult` ~ `CommonIPResult of RTTData`
- Errors:
    - ICMP_DESTINATION_UNREACHABLE: The remote host or its inbound gateway indicated that the destination is unreachable for some reason.
    - ICMP_TIME_EXCEEDED: The datagram was discarded due to the time to live field reaching zero.

```python
class RTTData:
    min: float64
    avg: float64
    max: float64
    sent: int32
    received: int32
    jitter: float64
``` 

## Merging the data

The data are being continuously collected and stored in the corresponding *processed_\** topics. Before invoking the feature extractor, they must be merged into a single data object.

The [data merger pipeline component](https://github.com/nesfit/domainradar-colext/blob/main/java_pipeline/streams-components/src/main/java/cz/vut/fit/domainradar/streams/mergers/CollectedDataMergerComponent.java) based on Kafka Streams works by transforming the result topics into logical tables and perfoming joins between them. For more information on the concept, see the Kafka documentation on the [Duality of Streams and Tables](https://kafka.apache.org/37/documentation/streams/core-concepts#streams_concepts_duality). 

Symbolically, the merging operation does this:
```
all_IP_data_for_DN <- collected_IP_data
  .group by key: get groups of IP-collector results keyed by a (DN, IP) pair
  .aggregate: for each (DN, IP) group, make a map of <IP-coll. name -> IP-coll. result>
  .group by DN: get groups of maps keyed by a DN
  .aggregate: for each DN group, make a map of <IP -> map of <IP-coll. name -> IP-coll. result>>

zone_table <- table from processed_zone
DNS_table <- table from processed_DNS
RDAP_DN_table <- table from processed_RDAP_DN
TLS_table <- table from processed_TLS 

merged_DNS_IP_table <- DNS_table
  .left join with all_IP_data_for_DN

final_result_table <- merged_DNS_IP_table
  .join with zone_table
  .left join with TLS_table
  .left join with RDAP_DN_table
```

The output topic for the merged data is *all_collected_data*. The final data model is `FinalResult`:
```python
class FinalResult:
    zone: ZoneInfo
    dnsResult: ExtendedDNSResult
    tlsResult: TLSResult | None
    rdapDomainResult: RDAPDomainResult | None

class ExtendedDNSResult(DNSResult):
    # Map of IP address -> (map of IP collector name -> collection result)
    ipResults: dict[str, dict[str, CommonIPResult of Any]]
```

Observe that the joining process starts with entries in the *processed_DNS* topic. If zone/SOA resolution fails and the entry is not processed by the DNS collector, the merger is **not** triggered for the domain name and no `FinalResult` is produced. Such entries may be handled by a separate channel picking up failed `ZoneResult`s from *processed_zone*.

## Feature extractor

TODO