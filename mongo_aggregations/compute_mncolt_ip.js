const phase = 3;

if (phase == 0)
db.getCollection("dn_data").aggregate([
    {
        $match: {
            "_id.collector": "dns"
        }
    },
    {
        $replaceWith: {
            "domainName": "$_id.domainName",
            "ts": "$_id.timestamp"      
        }
    },
    {
        $out: "tmp_dn_data_dns_only"
    }
]);

if (phase == 1) {
db.getCollection("tmp_dn_data_dns_only").createIndex({"domainName": 1}, {unique: false});
db.getCollection("tmp_dn_data_dns_only").createIndex({"ts": 1}, {unique: false});
}

if (phase == 2)
db.getCollection("ip_data").aggregate([
  {
    // Find the closest DNS result
    $lookup: {
        from: "tmp_dn_data_dns_only",
        let: { "ipTs": "$_id.timestamp" },
        pipeline: [
            { $match: { $expr: { $gt: ["$$ipTs", "$ts"] } } }
        ],
        localField: "_id.domainName",
        foreignField: "domainName",
        as: "relatedDnsResult"
    }
  },
  {
       $out: "tmp_ip_data_with_previous_dns"
  }
]);

if (phase == 3)
db.getCollection("tmp_ip_data_with_previous_dns").aggregate([
  {
      $set: {
          "relatedDnsResult": {
              $arrayElemAt: [ 
                  { $sortArray: { input: "$relatedDnsResult", sortBy: { "_id.timestamp": 1 } } }, 
                  -1 
              ]
          }
      }
  },
  {
      $replaceWith: {
          "collector": "$_id.collector",
          "processingTime": { 
              $subtract: [
                  "$_id.timestamp",
                  "$relatedDnsResult.ts"
              ]    
          }
      }
  },
  {
    $group: {
      _id: "$collector",
      MnColT: { $avg: "$processingTime" }
    }
  },
  {
    $set: {
      MnColT: { $divide: [ "$MnColT", 1000.0 ] },
      ColTPut: { $divide: [ 1000.0, "$MnColT" ] }
    }
  }
]);
