const pipeline = [
    // Group by domain name/collector, select the latest entry for each collector.
    {
        $group: {
            "_id": { domainName: "$_id.domainName", collector: "$_id.collector" },
            "latest": {
                "$top": {
                    "sortBy": {
                        "_id.timestamp": -1
                    },
                    "output": "$$ROOT"
                }
            }
        }
    },

    // Stage 3
    {
        $replaceRoot: {
            newRoot: {
                $mergeObjects: [
                    "$_id", "$latest"
                ]
            }
        }
    },

    // Stage 4
    {
        $set: {
            "lastAttempt": { $toLong: "$_id.timestamp" }
        }
    },

    // Stage 5
    {
        $group: {
            _id: "$domainName", // Replace with the field you are grouping by
            dns: {
                $push: {
                    $cond: [
                        { $eq: ["$collector", "dns"] },
                        "$$ROOT",
                        null
                    ]
                }
            },
            tls: {
                $push: {
                    $cond: [
                        { $eq: ["$collector", "tls"] },
                        "$$ROOT",
                        null
                    ]
                }
            },
            rdap: {
                $push: {
                    $cond: [
                        { $eq: ["$collector", "rdap-dn"] },
                        "$$ROOT",
                        null
                    ]
                }
            },
            zone: {
                $push: {
                    $cond: [
                        { $eq: ["$collector", "zone"] },
                        "$$ROOT",
                        null
                    ]
                }
            }
        }
    },

    // Stage 6
    {
        $project: {
            dnsResult: {
                $arrayElemAt: [
                    {
                        $filter: {
                            input: "$dns",
                            as: "item",
                            cond: { $ne: ["$$item", null] }
                        }
                    },
                    0
                ]
            },
            tlsResult: {
                $arrayElemAt: [
                    {
                        $filter: {
                            input: "$tls",
                            as: "item",
                            cond: { $ne: ["$$item", null] }
                        }
                    },
                    0
                ]
            },
            rdapDomainResult: {
                $arrayElemAt: [
                    {
                        $filter: {
                            input: "$rdap",
                            as: "item",
                            cond: { $ne: ["$$item", null] }
                        }
                    },
                    0
                ]
            },
            zone: {
                $arrayElemAt: [
                    {
                        $filter: {
                            input: "$zone",
                            as: "item",
                            cond: { $ne: ["$$item", null] }
                        }
                    },
                    0
                ]
            }
        }
    },

    // Stage 7
    {
        $set: {
            "zone": "$zone.zone",
            "domain_name": "$_id"
        }
    },

    // Stage 8
    {
        $lookup: {
            "from": "ip_data",
            "localField": "_id",
            "foreignField": "_id.domainName",
            "pipeline": [
                // Stage 2
                {
                    $group: {
                        "_id": { domainName: "$_id.domainName", collector: "$_id.collector", ip: "$_id.ip" },
                        "latest": {
                            "$top": {
                                "sortBy": {
                                    "_id.timestamp": 1
                                },
                                "output": "$$ROOT"
                            }
                        }
                    }
                },

                // Stage 3
                {
                    $replaceRoot: {
                        newRoot: {
                            $mergeObjects: [
                                "$_id", "$latest"
                            ]
                        }
                    }
                },

                // Stage 4
                {
                    $set: {
                        "lastAttempt": { $toLong: "$_id.timestamp" }
                    }
                },

                {
                    $unset: ["domainName", "_id", "offset"]
                },

                // Stage 5
                {
                    $group: {
                        _id: "$ip",
                        rtt: {
                            $push: {
                                $cond: [
                                    { $eq: ["$collector", "rtt"] },
                                    "$$ROOT",
                                    null
                                ]
                            }
                        },
                        nerd: {
                            $push: {
                                $cond: [
                                    { $eq: ["$collector", "nerd"] },
                                    "$$ROOT",
                                    null
                                ]
                            }
                        },
                        geo_asn: {
                            $push: {
                                $cond: [
                                    { $eq: ["$collector", "geo_asn"] },
                                    "$$ROOT",
                                    null
                                ]
                            }
                        },
                        rdap: {
                            $push: {
                                $cond: [
                                    { $eq: ["$collector", "rdap_ip"] },
                                    "$$ROOT",
                                    null
                                ]
                            }
                        }
                    }
                },

                // Stage 6
                {
                    $project: {
                        rdap_ip: {
                            $arrayElemAt: [
                                {
                                    $filter: {
                                        input: "$rdap",
                                        as: "item",
                                        cond: { $ne: ["$$item", null] }
                                    }
                                },
                                0
                            ]
                        },
                        rtt: {
                            $arrayElemAt: [
                                {
                                    $filter: {
                                        input: "$rtt",
                                        as: "item",
                                        cond: { $ne: ["$$item", null] }
                                    }
                                },
                                0
                            ]
                        },
                        nerd: {
                            $arrayElemAt: [
                                {
                                    $filter: {
                                        input: "$nerd",
                                        as: "item",
                                        cond: { $ne: ["$$item", null] }
                                    }
                                },
                                0
                            ]
                        },
                        geo_asn: {
                            $arrayElemAt: [
                                {
                                    $filter: {
                                        input: "$geo_asn",
                                        as: "item",
                                        cond: { $ne: ["$$item", null] }
                                    }
                                },
                                0
                            ]
                        }
                    }
                },

                {
                    $unset: ["rdap_ip.collector", "rdap_ip.ip", "rtt.collector", "rtt.ip", "nerd.collector", "nerd.ip", "geo_asn.collector", "geo_asn.ip"]
                }
            ],
            "as": "ip_addresses"
        }
    },
    // Convert the array of IP-related results to an object with the IPs as keys
    {
        $set: {
            "dnsResult.ipResults": {
                $arrayToObject: {
                    $map: {
                        input: "$ip_addresses",
                        as: "ip",
                        in: {
                            k: "$$ip._id",
                            v: {
                                // From each collection entry, remove the IP fields.
                                $setField: {
                                    field: "_id",
                                    input: "$$ip",
                                    value: "$$REMOVE"
                                }
                            }
                        }
                    }
                }
            }
        }
    },
    // Unset the fields that are not a part of the data model
    {
        $unset: [
            "ip_addresses",
            "rdapDomainResult.domainName",
            "rdapDomainResult.collector",
            "rdapDomainResult._id",
            "rdapDomainResult.offset",
            "dnsResult.domainName",
            "dnsResult.collector",
            "dnsResult._id",
            "dnsResult.offset",
            "tlsResult.domainName",
            "tlsResult.collector",
            "tlsResult._id",
            "tlsResult.offset"
        ]
    }
];

db = db.getSiblingDB('domainradar');
db.createCollection("all_raw_data", { "viewOn": "dn_data", "pipeline": pipeline });

// Or run as:
// db.getCollection("db_data").aggregate(pipeline, {allowDiskUse: true})
