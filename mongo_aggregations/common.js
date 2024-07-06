function makeView(name, inputCollection, pipeline, materialized) {
    db = db.getSiblingDB('domainradar');

    if (materialized) {
        const outStage = [
            {
                $out: name
            }
        ];

        db.getCollection(inputCollection)
            .aggregate(pipeline.concat(outStage), { allowDiskUse: true });

        // in case this was called for the first time, create the indexes
        // if they already exist, these will be no-ops
        // $out keeps the old indexes
        db.getCollection(name)
            .createIndex({ "domain_name": 1 }, { unique: true });
        db.getCollection(name)
            .createIndex({ "aggregate_probability": 1 }, { unique: false});
    } else {
        db.createCollection(name, { "viewOn": inputCollection, "pipeline": pipeline });
    }
}
