# Schema of DomainRadar results

- stores classification results and data to show on the web dashboard
- wip
- nesfit/domainradar-ui will have the actual type definitions in `types/dr.ts`

## Changes
- replaced variable key objects (`{"DNS": {...stuff}}`) with arrays of defined types (`[...{"source": "DNS", ...stuff}]`) for better indexing and querying

```json
{
  "domain_name": "mzeeki.com",
  "ip_addresses": [
    {
      "ip": "2607:f1c0:100f:f000::200",
      "geo": {
        "country": "United States",
        "country_code": null,
        "region": null,
        "region_code": null,
        "city": null,
        "postal_code": null,
        "latitude": 37.751,
        "longitude": -97.822,
        "timezone": null,
        "isp": null,
        "org": null
      },
      "asn": {
        "asn": 8560,
        "as_org": "IONOS SE",
        "network_address": "2607:f1c0:1000::",
        "prefix_len": 36
      },
      "collection_results": [
        {
          "source": "DNS | RDAP | ...etc",
          "result": "<result> string? ok/error?",
          "attempts": ["what is this?"],
          "error": "..."
        }
      ],
      "qradar_offenses": [
        {
          "id": 123456,
          "qradar_domain": "ne to co je normální doména",
          "event_flow_count": 1,
          "magnitude": 1
        }
      ]
    },
    {
      "ip": "74.208.236.68",
      "geo": {
        "country": "United States",
        "country_code": null,
        "region": null,
        "region_code": null,
        "city": null,
        "postal_code": null,
        "latitude": 39.952,
        "longitude": -75.1814,
        "timezone": null,
        "isp": null,
        "org": null
      },
      "asn": {
        "asn": 8560,
        "as_org": "IONOS SE",
        "network_address": "74.208.232.0",
        "prefix_len": 21
      },
      "collection_results": [],
      "qradar_offenses": []
    }
  ],
  "aggregate_probability": 0.7898383552053838,
  "aggregate_description": "...",
  "classification_results": [
    {
      "classifier": "Phishing",
      "probability": 0.05633430716219098,
      "description": "No phishing detected."
    },
    {
      "classifier": "Malware",
      "probability": 0.004824631535984588,
      "description": "No malware detected."
    },
    {
      "classifier": "DGA",
      "probability": 0.8888312407957214,
      "description": "The domain has high level of DGA incidators.",
      "details": {
        "dga:virut": "99.99%"
      }
    }
  ],
  "first_seen": "2023-09-11T14:54:31Z",
  "last_seen": "2023-10-24T13:48:34Z",
  "collection_results": [
    {
      "source": "DNS | RDAP | ...etc",
      "result": "<result> string? ok/error?",
      "attempts": ["what is this?"],
      "error": "..."
    }
  ],
  "prefilter_results": [
    {
      "filter": "<filter>",
      "něco": "něco..."
    }
  ],
  "nějaký_misp": {},
  "additional_info": {"cokoliv": "cokoliv..."}
}
```
