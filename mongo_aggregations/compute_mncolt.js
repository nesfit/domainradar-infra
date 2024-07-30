const start = ISODate("2024-07-24T17:50Z");
const stop =  ISODate("2024-07-26T06:00Z");

var firstRecord = db.dn_data.findOne({"_id.collector": "zone", "_id.timestamp": 
        { $gte: start, $lte: stop }}, {"ts": "$_id.timestamp"}, {sort: {"_id.timestamp": 1}}).ts;
console.info(firstRecord);

db.dn_data.aggregate([
  {
    $match: {
      "_id.timestamp": { $gte: start, $lte: stop }
    }
  },
  {
    // Stage 1: Sort by domainName and timestamp
    $sort: { "_id.domainName": 1, "_id.timestamp": 1 }
  },
  {
    // Stage 2: Group by domainName to collect all documents for a domain in an array
    $group: {
      _id: "$_id.domainName",
      docs: { $push: "$$ROOT" }
    }
  },
  /*{
      $out: "dn_data_grouped"
  }
]);

db.getCollection("dn_data_grouped").aggregate([*/
  { $addFields: { docsx: "$docs" } },
  { $unwind: "$docs" },
  {
    // Create a new field with the previous document's timestamp
    $set: {
      previousDoc: {
        $arrayElemAt: [
          {
            $filter: {
              input: "$docsx",
              as: "doc",
              cond: {
                $and: [  { $lt: ["$$doc._id.timestamp", "$docs._id.timestamp"] },
                {$or: [
                    {
                        
                        
                        $and: [
                          { $eq: ["$docs._id.collector", "dns"] },
                          { $eq: ["$$doc._id.collector", "zone"] }
                        ]

                    },
                    {
                      
                        $and: [
                          { $eq: ["$docs._id.collector", "tls"] },
                          { $eq: ["$$doc._id.collector", "dns"] }
                        ]
                      
                    },
                    {
                      
                        $and: [
                          { $eq: ["$docs._id.collector", "rdap-dn"] },
                          { $eq: ["$$doc._id.collector", "zone"] }
                        ]
                     
                    }
                  ] } ]
              }
            }
          },
          -1
        ]
      }
    }
  },
  {
      $replaceWith: {
          //"domainName": "$docs._id.domainName",
          //"end": "$docs._id.timestamp",
          //"start": { $ifNull: [ "$previousDoc._id.timestamp", ISODate("2024-07-11T18:46:40.035+0000") ] },
          //"previous": "$previousDoc",
          //"this": "$$ROOT",
          "collector": "$docs._id.collector",
          "processingTime": { 
              $subtract: [
                  "$docs._id.timestamp",
                  { $ifNull: [ "$previousDoc._id.timestamp", firstRecord ] } 
              ]    
          }
      }
  },
  {
    // Group by collector to calculate the average processing time
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