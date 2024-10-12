-- Create Collectors table
CREATE TABLE IF NOT EXISTS Collector
(
    id        SMALLSERIAL PRIMARY KEY,
    collector TEXT NOT NULL UNIQUE
);

-- Create ClassificationCategory table
CREATE TABLE IF NOT EXISTS Classification_Category
(
    id       SMALLSERIAL PRIMARY KEY,
    category TEXT NOT NULL UNIQUE
);

-- Create ClassificationCategory table
CREATE TABLE IF NOT EXISTS Classifier_Type
(
    id         SMALLSERIAL PRIMARY KEY,
    classifier TEXT NOT NULL UNIQUE
);

DROP TABLE IF EXISTS Domain CASCADE;
DROP TABLE IF EXISTS IP CASCADE;
DROP TABLE IF EXISTS Classification_Category_Result CASCADE;
DROP TABLE IF EXISTS Classifier_Output CASCADE;
DROP TABLE IF EXISTS Collection_Result CASCADE;
DROP TABLE IF EXISTS QRadar_Offense_Source CASCADE;
DROP TABLE IF EXISTS QRadar_Offense CASCADE;

-- Create Domain table
CREATE TABLE Domain
(
    id                    BIGSERIAL PRIMARY KEY,
    domain_name           TEXT UNIQUE NOT NULL,
    aggregate_probability REAL        NULL,
    aggregate_description TEXT        NULL
);

-- Create IP table
CREATE TABLE IP
(
    id                       BIGSERIAL PRIMARY KEY,
    domain_id                BIGINT           NOT NULL REFERENCES Domain (id),
    ip                       INET             NOT NULL,
    geo_country_code         TEXT             NULL,
    geo_region               TEXT             NULL,
    geo_region_code          TEXT             NULL,
    geo_city                 TEXT             NULL,
    geo_postal_code          TEXT             NULL,
    geo_latitude             DOUBLE PRECISION NULL,
    geo_longitude            DOUBLE PRECISION NULL,
    geo_timezone             TEXT             NULL,
    asn                      BIGINT           NULL,
    as_org                   TEXT             NULL,
    network_address          TEXT             NULL,
    network_prefix_length    INTEGER          NULL,
    nerd_reputation          DOUBLE PRECISION NULL,
    geo_asn_update_timestamp TIMESTAMP        NULL,
    nerd_update_timestamp    TIMESTAMP        NULL,
    UNIQUE (ip, domain_id)
);

-- Create ClassificationCategoryResult table
CREATE TABLE Classification_Category_Result
(
    id          BIGSERIAL PRIMARY KEY,
    domain_id   BIGINT           NOT NULL REFERENCES Domain (id),
    timestamp   TIMESTAMP        NOT NULL,
    category    SMALLINT         NOT NULL REFERENCES Classification_Category (id),
    probability DOUBLE PRECISION NOT NULL,
    description TEXT             NULL,
    details     JSONB            NULL
);

-- Create ClassifierOutput table
CREATE TABLE Classifier_Output
(
    result_id       BIGINT           NOT NULL REFERENCES Classification_Category_Result (id),
    classifier      SMALLINT         NOT NULL REFERENCES Classifier_Type (id),
    probability     DOUBLE PRECISION NOT NULL,
    additional_info TEXT             NULL,
    PRIMARY KEY (result_id, classifier)
);

-- Create CollectionResult table
CREATE TABLE Collection_Result
(
    id          BIGSERIAL PRIMARY KEY,
    domain_id   BIGINT    NOT NULL REFERENCES Domain (id),
    ip_id       BIGINT    NULL REFERENCES IP (id),
    source      SMALLINT  NOT NULL REFERENCES Collector (id),
    status_code SMALLINT  NOT NULL,
    error       TEXT      NULL,
    timestamp   TIMESTAMP NOT NULL,
    raw_data    JSONB     NULL,
    CONSTRAINT collection_result_unique UNIQUE NULLS NOT DISTINCT (domain_id, ip_id, source, timestamp)
);

-- Create QRadarOffenseSource table
CREATE TABLE QRadar_Offense_Source
(
    id               BIGSERIAL PRIMARY KEY,
    ip_id            BIGINT NOT NULL REFERENCES IP (id),
    qradar_domain_id INTEGER,
    magnitude        REAL
);

-- Create QRadarOffense table
CREATE TABLE QRadar_Offense
(
    id                BIGSERIAL PRIMARY KEY,
    offense_source_id BIGINT    NOT NULL REFERENCES QRadar_Offense_Source (id),
    description       TEXT      NULL,
    event_count       INTEGER   NOT NULL DEFAULT 0,
    flow_count        INTEGER   NOT NULL DEFAULT 0,
    device_count      INTEGER   NOT NULL DEFAULT 0,
    severity          REAL      NOT NULL,
    magnitude         REAL      NOT NULL,
    last_updated_time TIMESTAMP NOT NULL,
    status            TEXT      NULL
);

-- Create FeatureVector table
CREATE TABLE Feature_Vector
(
    id          BIGSERIAL PRIMARY KEY,
    domain_name TEXT  NOT NULL REFERENCES Domain (domain_name),
    data        JSONB NOT NULL
);

-- CREATE VIEW Collection_Result_Referenced AS
-- SELECT Domain.domain_name,
--        IP.ip::TEXT AS ip,
--        Collector.collector,
--        Collection_Result.status_code,
--        Collection_Result.error,
--        Collection_Result.timestamp,
--        Collection_Result.raw_data::TEXT AS raw_data
-- FROM Collection_Result
--          JOIN Domain ON Collection_Result.domain_id = Domain.id
--          LEFT JOIN IP ON Collection_Result.ip_id = IP.id
--          JOIN Collector ON Collection_Result.source = Collector.id;

CREATE TABLE Collection_Result_Referenced
(
    domain_name TEXT      NOT NULL,
    ip          TEXT      NULL,
    collector   TEXT      NOT NULL,
    status_code SMALLINT  NOT NULL,
    error       TEXT      NULL,
    timestamp   TIMESTAMP NOT NULL,
    raw_data    TEXT      NULL
);

CREATE OR REPLACE FUNCTION insert_collection_result()
    RETURNS trigger AS
$$
DECLARE
    v_domain_id         BIGINT;
    v_ip_id             BIGINT;
    v_collector_id      SMALLINT;
    v_new_ip            INET;
    v_new_record        Collection_Result_Referenced%ROWTYPE;
    v_deserialized_data JSONB;
BEGIN
    -- Insert or get domain
    INSERT INTO Domain (domain_name)
    VALUES (NEW.domain_name)
    ON CONFLICT (domain_name) DO NOTHING;

    SELECT id INTO v_domain_id FROM Domain WHERE domain_name = NEW.domain_name;

    -- Insert or get IP
    IF NEW.ip IS NOT NULL THEN
        SELECT CAST(NEW.ip as INET) INTO v_new_ip;

        INSERT INTO IP (ip, domain_id)
        VALUES (v_new_ip, v_domain_id)
        ON CONFLICT (ip, domain_id) DO NOTHING;

        SELECT id INTO v_ip_id FROM IP WHERE ip = v_new_ip AND domain_id = v_domain_id;
    ELSE
        v_ip_id := NULL;
    END IF;

    -- Deserialize the input JSON
    IF NEW.raw_data IS NOT NULL THEN
        SELECT NEW.raw_data::jsonb INTO v_deserialized_data;
    ELSE
        v_deserialized_data := NULL;
    END IF;

    -- Check collector
    SELECT id INTO v_collector_id FROM Collector WHERE collector = NEW.collector;
    IF v_collector_id IS NULL THEN
        RAISE EXCEPTION 'Collector "%s" does not exist.', NEW.collector;
    END IF;

    -- Update IP data
    IF v_ip_id IS NOT NULL AND v_deserialized_data IS NOT NULL AND NEW.status_code = 0 THEN
        IF NEW.collector = 'geo-asn' THEN
            UPDATE IP
            SET geo_country_code         = (v_deserialized_data #>> '{data,countryCode}'),
                geo_region               = (v_deserialized_data #>> '{data,region}'),
                geo_region_code          = (v_deserialized_data #>> '{data,regionCode}'),
                geo_city                 = (v_deserialized_data #>> '{data,city}'),
                geo_postal_code          = (v_deserialized_data #>> '{data,postalCode}'),
                geo_latitude             = (v_deserialized_data #> '{data,latitude}')::DOUBLE PRECISION,
                geo_longitude            = (v_deserialized_data #> '{data,longitude}')::DOUBLE PRECISION,
                geo_timezone             = (v_deserialized_data #>> '{data,timezone}'),
                asn                      = (v_deserialized_data #> '{data,asn}')::BIGINT,
                as_org                   = (v_deserialized_data #>> '{data,asnOrg}'),
                network_address          = (v_deserialized_data #>> '{data,networkAddress}'),
                network_prefix_length    = (v_deserialized_data #> '{data,prefixLength}')::INTEGER,
                geo_asn_update_timestamp = NEW.timestamp
            WHERE id = v_ip_id
              AND (geo_asn_update_timestamp IS NULL OR geo_asn_update_timestamp <= NEW.timestamp);
        ELSE
            IF NEW.collector = 'nerd' THEN
                UPDATE IP
                SET nerd_reputation       = (v_deserialized_data #> '{data,reputation}')::DOUBLE PRECISION,
                    nerd_update_timestamp = NEW.timestamp
                WHERE id = v_ip_id
                  AND (nerd_update_timestamp IS NULL OR nerd_update_timestamp <= NEW.timestamp);
            END IF;
        END IF;
    END IF;

    -- Step 5: Insert into Collection_Result
    INSERT INTO Collection_Result (domain_id,
                                   ip_id,
                                   source,
                                   status_code,
                                   error,
                                   timestamp,
                                   raw_data)
    VALUES (v_domain_id,
            v_ip_id,
            v_collector_id,
            NEW.status_code,
            NEW.error,
            NEW.timestamp,
            v_deserialized_data)
    ON CONFLICT ON CONSTRAINT collection_result_unique DO UPDATE
        SET status_code = NEW.status_code,
            error       = NEW.error,
            raw_data    = v_deserialized_data;

    /*
    v_new_record.domain_name := NEW.domain_name;
    v_new_record.ip := NEW.ip;
    v_new_record.collector := NEW.collector;
    v_new_record.status_code := NEW.status_code;
    v_new_record.error := NEW.error;
    v_new_record.timestamp := NEW.timestamp;
    v_new_record.raw_data := NEW.raw_data;

    RETURN v_new_record;
    */

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER insert_collection_result_trigger
    -- INSTEAD OF INSERT
    BEFORE INSERT
    ON Collection_Result_Referenced
    FOR EACH ROW
EXECUTE FUNCTION insert_collection_result();