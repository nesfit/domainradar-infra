// This is the MongoDB aggregation pipeline that uses metadata and data from the DNS and IP collectors
// stored in the 'db_data' and 'ip_data' collections to create a single document per domain name
// in the format expected by the UI.

// TODO: Add missing fields:
// - the classification data (join from another collection)
// - the 'last_seen' date – transferred over from Postgres OR calculated from the latest collection date??!
// - the QRadar offense source – should it be stored in 'ip_data' or separately??!

var pipeline = [
    {
        // Group entries from the DN collectors by the domain name
        "$group": {
            "_id": "$_id.domainName",
            // The result will have an array of documents, each representing a collection attempt
            "documents": {
                "$push": {
                    "collection_date": "$_id.timestamp",
                    "source": "$_id.collector",
                    "error": "$error",
                    "statusCode": "$statusCode"
                }
            },
            // Consider the earliest collection date to be the "first seen" date
            "first_seen": {
                "$top": {
                    "sortBy": {
                        "_id.timestamp": 1
                    },
                    "output": "$_id.timestamp"
                }
            }
        }
    },
    {
        // Join the domain names with the entries from the IP collectors
        // and process them to the final format
        "$lookup": {
            "from": "ip_data",
            "localField": "_id",
            "foreignField": "_id.domainName",
            "pipeline": [
                // This internal aggregation pipeline processes the entries
                // selected for each domain name
                {
                    // First group by IP/collector pair to extract the latest entry
                    // This entry will be used to extract the geo and ASN data
                    "$group": {
                        "_id": {
                            "ip": "$_id.ip",
                            "collector": "$_id.collector"
                        },
                        // Extract the latest entry for each collector (for each IP)
                        "latest": {
                            "$top": {
                                "sortBy": {
                                    "_id.timestamp": -1
                                },
                                "output": "$$ROOT"
                            }
                        },
                        // Also store metadata of the collection attempts
                        "all": {
                            "$push": {
                                "collection_date": "$_id.timestamp",
                                "source": "$_id.collector",
                                "error": "$error",
                                "status_code": "$statusCode"
                            }
                        }
                    }
                },
                {
                    // Now group only by IP to get a single document per IP
                    "$group": {
                        "_id": "$_id.ip",
                        // Add an array of the latest results from each collector
                        "latest_data": {
                            "$push": {
                                "k": "$_id.collector",
                                "v": "$latest.data"
                            }
                        },
                        // Also propagate the array of all collection attempt metadata
                        // This will create an array of arrays
                        "all": {
                            "$push": "$all"
                        }
                    }
                },
                {
                    "$project": {
                        "_id": 1,
                        // Convert the array of latest results to an object
                        // Collector names are keys, their data are values
                        "results": {
                            "$arrayToObject": "$latest_data"
                        },
                        // Reduce the array of arrays to a single array
                        "all": {
                            "$reduce": {
                                "input": "$all",
                                "initialValue": [],
                                "in": {
                                    "$concatArrays": [
                                        "$$value",
                                        "$$this"
                                    ]
                                }
                            }
                        }
                    }
                },
                {
                    // Project the IP data to the final format
                    "$project": {
                        "_id": 0,
                        "ip": "$_id",
                        "geo": {
                            "country_code": "$results.geo_asn.countryCode",
                            "region": "$results.geo_asn.region",
                            "region_code": "$results.geo_asn.regionCode",
                            "city": "$results.geo_asn.city",
                            "postal_code": "$results.geo_asn.postalCode",
                            "latitude": "$results.geo_asn.countryCode",
                            "longitude": "$results.geo_asn.countryCode",
                            "timezone": "$results.geo_asn.countryCode",
                        },
                        "asn": {
                            "asn": "$results.geo_asn.asn",
                            "as_org": "$results.geo_asn.asnOrg",
                            "network_address": "$results.geo_asn.networkAddress",
                            "prefix_len": "$results.geo_asn.prefixLength"
                        },
                        "collection_results": {
                            "$sortArray": {
                                "input": "$all",
                                "sortBy": {
                                    "collection_date": 1
                                }
                            }
                        },
                        "qradar_offense_source": null // TODO
                    }
                }
            ],
            "as": "ip_addresses"
        }
    },
    {
        // Project the domain data, joined with the corresponding IPs, to the final format
        "$project": {
            "_id": 0,
            "domain_name": "$_id",
            "ip_addresses": 1,
            "classification_results": null, // TODO
            "first_seen": 1,
            "last_seen": null, // TODO
            "collection_results": {
                "$sortArray": {
                    "input": "$documents",
                    "sortBy": {
                        "collection_date": 1
                    }
                }
            }
        }
    }
];

// Run as: db.getCollection("db_data").aggregate(pipeline, {allowDiskUse: true})
