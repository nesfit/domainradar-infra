-- The input table (filled by the loader)
CREATE TABLE IF NOT EXISTS Domains_Input
(
    id            BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    domain        TEXT        NOT NULL UNIQUE,
    first_seen    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen     TIMESTAMPTZ NOT NULL,
    filter_output JSONB
);

-- User-specified input filters
CREATE TABLE IF NOT EXISTS Custom_Prefilter
(
    id                     INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name                   TEXT        NOT NULL,
    description            TEXT,
    enabled                BOOLEAN              DEFAULT TRUE,
    action                 INT                  DEFAULT 0 CHECK (action >= 0 AND action <= 3),
    last_updated_timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS Custom_Prefiltered_Domain
(
    custom_prefilter_id INT  NOT NULL REFERENCES Custom_Prefilter (id) ON DELETE CASCADE,
    domain_name         TEXT NOT NULL,
    PRIMARY KEY (custom_prefilter_id, domain_name)
);

-- Enums
CREATE TABLE IF NOT EXISTS Collector
(
    id              SMALLINT PRIMARY KEY,
    collector       TEXT    NOT NULL UNIQUE,
    is_ip_collector BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS Classification_Category
(
    id       SMALLINT PRIMARY KEY,
    category TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS Classifier_Type
(
    id          SMALLINT PRIMARY KEY,
    category_id SMALLINT REFERENCES Classification_Category (id) ON DELETE RESTRICT,
    classifier  TEXT NOT NULL,
    UNIQUE (category_id, classifier)
);

CREATE TABLE IF NOT EXISTS Collector_Status_Type
(
    status_code SMALLINT PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT NULL
);

DROP TABLE IF EXISTS Domain CASCADE;
DROP TABLE IF EXISTS Domain_Errors CASCADE;
DROP TABLE IF EXISTS IP CASCADE;
DROP TABLE IF EXISTS Classification_Category_Result CASCADE;
DROP TABLE IF EXISTS Classifier_Output CASCADE;
DROP TABLE IF EXISTS Collection_Result CASCADE;
DROP TABLE IF EXISTS QRadar_Offense_In_Source CASCADE;
DROP TABLE IF EXISTS QRadar_Offense_Source CASCADE;
DROP TABLE IF EXISTS QRadar_Offense CASCADE;
DROP TABLE IF EXISTS Feature_Vector CASCADE;
DROP TABLE IF EXISTS Collection_Results_Dummy_Target CASCADE;
DROP TABLE IF EXISTS Classification_Results_Dummy_Target CASCADE;

-- Domains
CREATE TABLE Domain
(
    id                    BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    domain_name           TEXT UNIQUE NOT NULL,
    aggregate_probability REAL        NULL,
    aggregate_description TEXT        NULL,
    last_update           TIMESTAMPTZ NOT NULL
);

CREATE TABLE Domain_Errors
(
    domain_id         BIGINT      NOT NULL REFERENCES Domain (id) ON DELETE CASCADE,
    discriminator     UUID        NOT NULL DEFAULT gen_random_uuid(),
    timestamp         TIMESTAMPTZ NOT NULL,
    source            TEXT        NOT NULL,
    error             TEXT        NOT NULL,
    sql_error_code    TEXT        NULL,
    sql_error_message TEXT        NULL,
    PRIMARY KEY (domain_id, discriminator)
);

CREATE TABLE Discarded_Domain
(
    domain_name           TEXT        NOT NULL,
    aggregate_probability REAL        NULL,
    discarded_at          TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (domain_name, discarded_at)
);

-- IPs
CREATE TABLE IP
(
    id                       BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    domain_id                BIGINT           NOT NULL REFERENCES Domain (id) ON DELETE CASCADE,
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
    geo_asn_update_timestamp TIMESTAMPTZ      NULL,
    nerd_update_timestamp    TIMESTAMPTZ      NULL,
    UNIQUE (domain_id, ip)
);

-- Classification results
CREATE TABLE Classification_Category_Result
(
    id          BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    domain_id   BIGINT           NOT NULL REFERENCES Domain (id) ON DELETE CASCADE,
    timestamp   TIMESTAMPTZ      NOT NULL,
    category_id SMALLINT         NOT NULL REFERENCES Classification_Category (id) ON DELETE RESTRICT,
    probability DOUBLE PRECISION NOT NULL,
    description TEXT             NULL,
    details     JSONB            NULL,
    CONSTRAINT Classification_Category_Result_Unique UNIQUE (domain_id, timestamp, category_id)
);

CREATE TABLE Classifier_Output
(
    result_id       BIGINT           NOT NULL REFERENCES Classification_Category_Result (id) ON DELETE CASCADE,
    classifier_id   SMALLINT         NOT NULL REFERENCES Classifier_Type (id) ON DELETE RESTRICT,
    probability     DOUBLE PRECISION NOT NULL,
    additional_info TEXT             NULL,
    PRIMARY KEY (result_id, classifier_id)
);

-- Collection results
CREATE TABLE Collection_Result
(
    id          BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    domain_id   BIGINT      NOT NULL REFERENCES Domain (id) ON DELETE CASCADE,
    ip_id       BIGINT      NULL REFERENCES IP (id) ON DELETE CASCADE,
    source_id   SMALLINT    NOT NULL REFERENCES Collector (id) ON DELETE RESTRICT,
    status_code SMALLINT    NOT NULL REFERENCES Collector_Status_Type (status_code) ON DELETE RESTRICT,
    error       TEXT        NULL,
    timestamp   TIMESTAMPTZ NOT NULL,
    raw_data    JSONB       NULL,
    CONSTRAINT Collection_Result_Unique UNIQUE NULLS NOT DISTINCT (domain_id, ip_id, source_id, timestamp)
);

-- QRadar
CREATE TABLE QRadar_Offense_Source
(
    id               BIGINT PRIMARY KEY,
    ip               INET    NULL,
    qradar_domain_id INTEGER NOT NULL,
    magnitude        REAL    NOT NULL
);

CREATE TABLE QRadar_Offense
(
    id                BIGINT PRIMARY KEY,
    description       TEXT        NULL,
    event_count       INTEGER     NOT NULL DEFAULT 0,
    flow_count        INTEGER     NOT NULL DEFAULT 0,
    device_count      INTEGER     NOT NULL DEFAULT 0,
    severity          REAL        NOT NULL,
    magnitude         REAL        NOT NULL,
    last_updated_time TIMESTAMPTZ NOT NULL,
    status            TEXT        NULL
);

CREATE TABLE QRadar_Offense_In_Source
(
    offense_source_id BIGINT NOT NULL REFERENCES QRadar_Offense_Source (id) ON DELETE CASCADE,
    offense_id        BIGINT NOT NULL REFERENCES QRadar_Offense (id) ON DELETE CASCADE,
    PRIMARY KEY (offense_id, offense_source_id)
);

-- Feature vectors
CREATE TABLE Feature_Vector
(
    id          BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    domain_name TEXT  NOT NULL,
    data        JSONB NOT NULL
);

--- Indices ---

-- Enable trigram indices
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Misc
CREATE INDEX ON Classifier_Type USING HASH (classifier);
CREATE INDEX ON Collector USING HASH (collector);
-- Joins IPs with QRadar data
CREATE INDEX ON QRadar_Offense_Source (ip);
-- Domain data lookups
CREATE INDEX ON Classification_Category_Result (domain_id DESC);
CREATE INDEX ON Classification_Category_Result (category_id);
CREATE INDEX ON Classification_Category_Result (probability DESC);
CREATE INDEX ON Classification_Category_Result (category_id, probability DESC);
-- Domain/IP data lookups
CREATE INDEX ON IP (domain_id DESC);
CREATE INDEX ON IP (ip DESC);
-- Collection result lookups
CREATE INDEX ON Collection_Result (domain_id);
CREATE INDEX ON Collection_Result (ip_id);
-- Sorting in the UI
CREATE INDEX ON Domain (aggregate_probability DESC);
CREATE INDEX ON Domain (last_update DESC);
CREATE INDEX domain_names_trigram_index ON Domain USING GIST (domain_name gist_trgm_ops(siglen=32));
-- Stats and cleanup
CREATE INDEX ON Domains_Input (first_seen DESC);

--- Inserting classification results ---

-- A dummy target table for the classification results Kafka Connect sink
CREATE TABLE Classification_Results_Dummy_Target
(
    domain_name TEXT NOT NULL,
    raw_data    TEXT NOT NULL
);

-- A procedure to insert all the pending classification results in batch
CREATE OR REPLACE PROCEDURE process_classification_results()
    LANGUAGE plpgsql
AS
$$
DECLARE
    rec                      RECORD;
    v_domain_id              BIGINT;
    v_deserialized_data      JSONB;
    v_aggregate_prob         DOUBLE PRECISION;
    v_aggregate_desc         TEXT;
    v_timestamp              TIMESTAMPTZ;
    v_classification_results JSONB;
    v_classification_result  JSONB;
    v_category               SMALLINT;
    v_probability            DOUBLE PRECISION;
    v_description            TEXT;
    v_details                JSONB;
    v_result_id              BIGINT;
    v_detail_rec             RECORD;
    v_error                  TEXT;
    v_sql_error_code         TEXT;
    v_sql_error_message      TEXT;
BEGIN
    -- lock the dummy target so concurrent jobs don’t overlap
    LOCK TABLE Classification_Results_Dummy_Target IN EXCLUSIVE MODE;

    FOR rec IN
        SELECT domain_name, raw_data
        FROM Classification_Results_Dummy_Target
        LOOP
            BEGIN
                v_sql_error_code := NULL;
                v_sql_error_message := NULL;
                -- deserialize the input JSON
                v_deserialized_data := rec.raw_data::JSONB;
                -- parse top‐level fields
                v_aggregate_prob := COALESCE((v_deserialized_data ->> 'aggregate_probability')::DOUBLE PRECISION, -1.0);
                v_aggregate_desc := v_deserialized_data ->> 'aggregate_description';
                v_error := v_deserialized_data ->> 'error';
                v_timestamp := COALESCE(
                        (timestamptz 'epoch' +
                         (((v_deserialized_data ->> 'timestamp')::BIGINT) * interval '1 millisecond')),
                        now()
                               );
            EXCEPTION
                WHEN OTHERS THEN
                    v_aggregate_prob := -1;
                    v_aggregate_desc := NULL;
                    v_error := 'Cannot parse JSON.';
                    v_timestamp := now();
                    v_sql_error_code := SQLSTATE;
                    v_sql_error_message := SQLERRM;
            END;

            -- upsert Domain with aggregate results
            INSERT INTO Domain(domain_name, aggregate_probability, aggregate_description, last_update)
            VALUES (rec.domain_name, v_aggregate_prob, v_aggregate_desc, v_timestamp)
            ON CONFLICT (domain_name) DO UPDATE
                SET aggregate_probability = EXCLUDED.aggregate_probability,
                    aggregate_description = EXCLUDED.aggregate_description,
                    last_update           = EXCLUDED.last_update
            RETURNING id INTO v_domain_id;

            -- if parse error, record and skip
            IF v_error IS NOT NULL THEN
                INSERT INTO Domain_Errors(domain_id, timestamp, source, error, sql_error_code, sql_error_message)
                VALUES (v_domain_id, v_timestamp, 'process_classification_results', v_error, v_sql_error_code,
                        v_sql_error_message);
                CONTINUE;
            END IF;

            -- extract the array of per‐category results
            v_classification_results := v_deserialized_data -> 'classification_results';
            IF v_classification_results IS NULL OR jsonb_typeof(v_classification_results) <> 'array' THEN
                INSERT INTO Domain_Errors(domain_id, timestamp, source, error)
                VALUES (v_domain_id, v_timestamp, 'process_classification_results', 'No classification results in the input data.');
                CONTINUE;
            END IF;

            -- loop through each classification result
            FOR v_classification_result IN
                SELECT value
                FROM jsonb_array_elements(v_classification_results) AS t(value)
                LOOP
                    BEGIN
                        -- Extract fields from the classification_result JSON object
                        v_category := (v_classification_result ->> 'category')::SMALLINT;
                        v_probability := (v_classification_result ->> 'probability')::DOUBLE PRECISION;
                        v_description := v_classification_result ->> 'description';
                        v_details := v_classification_result -> 'details';

                        -- Insert into Classification_Category_Result, handle conflict if entry exists
                        INSERT INTO Classification_Category_Result(domain_id, timestamp, category_id, probability,
                                                                   description, details)
                        VALUES (v_domain_id, v_timestamp, v_category, v_probability, v_description, NULL)
                        ON CONFLICT ON CONSTRAINT classification_category_result_unique DO UPDATE
                            SET probability = EXCLUDED.probability,
                                description = EXCLUDED.description,
                                details     = EXCLUDED.details
                        RETURNING id INTO v_result_id;

                        -- if there are classifier outputs, write those too
                        IF v_details IS NOT NULL AND jsonb_typeof(v_details) = 'object' THEN
                            FOR v_detail_rec IN SELECT key, value FROM jsonb_each(v_details)
                                LOOP
                                    -- Insert into Classifier_Output, handle conflict if entry exists
                                    INSERT INTO Classifier_Output(result_id, classifier_id, probability, additional_info)
                                    VALUES (v_result_id,
                                            v_detail_rec.key::SMALLINT,
                                            v_detail_rec.value::DOUBLE PRECISION,
                                            NULL)
                                    ON CONFLICT (result_id, classifier_id) DO UPDATE
                                        SET probability     = EXCLUDED.probability,
                                            additional_info = EXCLUDED.additional_info;
                                END LOOP;
                        END IF;

                    EXCEPTION
                        WHEN OTHERS THEN
                            INSERT INTO Domain_Errors(domain_id, timestamp, source, error, sql_error_code,
                                                      sql_error_message)
                            VALUES (v_domain_id, v_timestamp, 'process_classification_results',
                                    'Cannot process one result.', SQLSTATE, SQLERRM);
                            EXIT; -- skip remaining sub‐results for this domain
                    END;
                END LOOP;
        END LOOP;

    -- clear out everything that was just processed
    DELETE FROM Classification_Results_Dummy_Target;
END;
$$;

--- Old entries cleanup ---

CREATE OR REPLACE PROCEDURE clear_old_results()
    LANGUAGE plpgsql
AS
$$
BEGIN
    -- First, delete all pre-filtered names older than 21 days
    -- (so every domain name can be classified at least once in 21 days)
    delete
    from domains_input
    where first_seen < now() - (interval '21' day);

    -- Domain names with aggregated risk <= 0.4:
    --   - Collection results are removed after 2 days
    --   - The domain entry (incl. classification results by cascade) are removed after 4 days
    with thresholded as (select id, domain_name, last_update from domain where aggregate_probability <= 0.4),
         _ as (delete from collection_result where
             domain_id in (select id from thresholded where last_update < now() - (interval '2' day))),
         removed as (delete from domain where
             id in (select id from thresholded where last_update < now() - (interval '4' day))
             returning domain_name, aggregate_probability)
    insert
    into discarded_domain (domain_name, aggregate_probability, discarded_at)
    select domain_name, aggregate_probability, now()
    from removed;

    -- Domain names with 0.4 < aggregated risk <= 0.6:
    --   - Collection results are removed after 4 days
    --   - The domain entry (incl. classification results by cascade) are removed after 7 days
    --   - The domain can be re-classified (if seen again) after 7 days
    with thresholded as (select id, domain_name, last_update
                         from domain
                         where aggregate_probability <= 0.6
                           and aggregate_probability > 0.4),
         _ as (delete from collection_result where
             domain_id in (select id from thresholded where last_update < now() - (interval '4' day))),
         __ as (delete from domains_input where first_seen < now() - (interval '7' day)
             and domain in (select domain_name from thresholded)),
         removed as (delete from domain where
             id in (select id from thresholded where last_update < now() - (interval '7' day))
             returning domain_name, aggregate_probability)
    insert
    into discarded_domain (domain_name, aggregate_probability, discarded_at)
    select domain_name, aggregate_probability, now()
    from removed;

    -- Domain names with 0.6 < aggregated risk <= 0.8:
    --   - Collection results are removed after 7 days
    --   - The domain entry (incl. classification results by cascade) are removed after 14 days
    --   - The domain can be re-classified (if seen again) after 5 days
    with thresholded as (select id, domain_name, last_update
                         from domain
                         where aggregate_probability <= 0.8
                           and aggregate_probability > 0.6),
         _ as (delete from collection_result where
             domain_id in (select id from thresholded where last_update < now() - (interval '7' day))),
         __ as (delete from domains_input where first_seen < now() - (interval '5' day)
             and domain in (select domain_name from thresholded)),
         removed as (delete from domain where
             id in (select id from thresholded where last_update < now() - (interval '14' day))
             returning domain_name, aggregate_probability)
    insert
    into discarded_domain (domain_name, aggregate_probability, discarded_at)
    select domain_name, aggregate_probability, now()
    from removed;

    -- Domain names with 0.8 < aggregated risk <= 1.0:
    --   - Collection results are removed after 30 days
    --   - The domain entry (incl. classification results by cascade) are removed after 60 days
    --   - The domain can be re-classified (if seen again) after 3 days
    with thresholded as (select id, domain_name, last_update
                         from domain
                         where aggregate_probability is not null
                           and aggregate_probability > 0.8),
         _ as (delete from collection_result where
             domain_id in (select id from thresholded where last_update < now() - (interval '30' day))),
         __ as (delete from domains_input where first_seen < now() - (interval '3' day)
             and domain in (select domain_name from thresholded)),
         removed as (delete from domain where
             id in (select id from thresholded where last_update < now() - (interval '60' day))
             returning domain_name, aggregate_probability)
    insert
    into discarded_domain (domain_name, aggregate_probability, discarded_at)
    select domain_name, aggregate_probability, now()
    from removed;

    -- Domain names that are collected but unclassified for some reason (i.e. system failure)
    -- will be removed from the database after 7 days, and they may be re-classified (if seen
    -- again) after 1 day
    with thresholded as (select id, domain_name, last_update from domain where aggregate_probability is null),
         __ as (delete from domains_input where first_seen < now() - (interval '1' day)
             and domain in (select domain_name from thresholded)),
         removed as (delete from domain where
             id in (select id from thresholded where last_update < now() - (interval '7' day))
             returning domain_name, aggregate_probability)
    insert
    into discarded_domain (domain_name, aggregate_probability, discarded_at)
    select domain_name, aggregate_probability, now()
    from removed;
END;
$$;

--- LEGACY collection results insertion ---
--- This table and the functions are kept for reference or as a backup.
--- The insertion is now handled by the Flink pipeline instead.

-- A dummy target table for the collection results Kafka Connect sink
CREATE TABLE Collection_Results_Dummy_Target
(
    domain_name TEXT     NOT NULL,
    ip          TEXT     NULL,
    collector   TEXT     NOT NULL,
    status_code SMALLINT NOT NULL,
    error       TEXT     NULL,
    timestamp   BIGINT   NOT NULL, -- Unix time in ms
    raw_data    TEXT     NULL
);

CREATE OR REPLACE FUNCTION insert_or_get_domain_and_ip(p_domain_name TEXT, p_ip TEXT, p_update_timestamp TIMESTAMPTZ,
                                                       OUT r_domain_id BIGINT, OUT r_ip_id BIGINT)
AS
$$
DECLARE
    v_new_ip INET;
BEGIN
    SELECT id
    INTO r_domain_id
    FROM Domain
    WHERE domain_name = p_domain_name;

    IF NOT FOUND THEN
        INSERT INTO Domain (domain_name, last_update)
        VALUES (p_domain_name, p_update_timestamp)
        ON CONFLICT (domain_name) DO NOTHING
        RETURNING id INTO r_domain_id;

        IF r_domain_id IS NULL THEN
            SELECT id
            INTO r_domain_id
            FROM Domain
            WHERE domain_name = p_domain_name;
        END IF;
    END IF;

    -- Insert or get IP, if provided.
    IF p_ip IS NOT NULL THEN
        -- Safe cast to inet (a collector result might be INVALID_ADDRESS)
        BEGIN
            v_new_ip := p_ip::INET;
        EXCEPTION
            WHEN OTHERS THEN
                v_new_ip := '0.0.0.0'::INET;
        END;

        INSERT INTO IP (ip, domain_id)
        VALUES (v_new_ip, r_domain_id)
        ON CONFLICT (ip, domain_id) DO NOTHING
        RETURNING id INTO r_ip_id;

        IF r_ip_id IS NULL THEN
            SELECT id
            INTO r_ip_id
            FROM IP
            WHERE domain_id = r_domain_id AND IP.ip = v_new_ip;
        END IF;
    ELSE
        r_ip_id := NULL;
    END IF;

    RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_ip_data(
    p_ip_id BIGINT,
    p_collector_name TEXT,
    p_data JSONB,
    p_timestamp TIMESTAMPTZ,
    p_status_code INT
)
    RETURNS VOID
AS
$$
BEGIN
    IF p_ip_id IS NOT NULL AND p_data IS NOT NULL AND p_status_code = 0 THEN
        IF p_collector_name = 'geo-asn' THEN
            p_data := p_data -> 'data';
            IF p_data IS NULL OR jsonb_typeof(p_data) != 'object' THEN
                RETURN;
            END IF;

            UPDATE IP
            SET geo_country_code         = p_data ->> 'countryCode',
                geo_region               = p_data ->> 'region',
                geo_region_code          = p_data ->> 'regionCode',
                geo_city                 = p_data ->> 'city',
                geo_postal_code          = p_data ->> 'postalCode',
                geo_latitude             = NULLIF(p_data -> 'latitude', 'null'::jsonb)::DOUBLE PRECISION,
                geo_longitude            = NULLIF(p_data -> 'longitude', 'null'::jsonb)::DOUBLE PRECISION,
                geo_timezone             = p_data ->> 'timezone',
                asn                      = NULLIF(p_data -> 'asn', 'null'::jsonb)::BIGINT,
                as_org                   = p_data ->> 'asnOrg',
                network_address          = p_data ->> 'networkAddress',
                network_prefix_length    = NULLIF(p_data -> 'prefixLength', 'null'::jsonb)::INTEGER,
                geo_asn_update_timestamp = p_timestamp
            WHERE id = p_ip_id
              AND (geo_asn_update_timestamp IS NULL OR geo_asn_update_timestamp <= p_timestamp);
        ELSIF p_collector_name = 'nerd' THEN
            UPDATE IP
            SET nerd_reputation       = NULLIF(p_data -> 'data' -> 'reputation', 'null'::jsonb)::DOUBLE PRECISION,
                nerd_update_timestamp = p_timestamp
            WHERE id = p_ip_id
              AND (nerd_update_timestamp IS NULL OR nerd_update_timestamp <= p_timestamp);
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_qradar_data(
    p_domain_id BIGINT,
    p_ip        TEXT,
    p_timestamp TIMESTAMPTZ,
    p_data      JSONB
)
    RETURNS VOID
LANGUAGE plpgsql
AS
$$
DECLARE
    v_data       JSONB;
    v_offenses   JSONB;
    v_offense    JSONB;
    v_all_source_addresses JSONB;
    v_source_address_ip_id JSONB;
    v_src_addr_id BIGINT;
    v_inet       INET := NULLIF(p_ip, '')::INET;
BEGIN
    -- Extract the top-level "data" object
    v_data := p_data -> 'data';
    IF v_data IS NULL OR jsonb_typeof(v_data) != 'object' THEN
        RETURN;
    END IF;

    -- Insert/update into QRadar_Offense_Source
    INSERT INTO QRadar_Offense_Source (id, ip, qradar_domain_id, magnitude)
    VALUES (
        (v_data ->> 'sourceAddressId')::BIGINT,
        v_inet,
        (v_data ->> 'qradarDomainId')::INTEGER,
        COALESCE((v_data ->> 'magnitude')::REAL, 0.0)
    )
    ON CONFLICT (id) DO UPDATE
        SET ip               = EXCLUDED.ip,
            qradar_domain_id = EXCLUDED.qradar_domain_id,
            magnitude        = EXCLUDED.magnitude;

    -- Process offenses array
    v_offenses := v_data -> 'offenses';
    IF v_offenses IS NULL OR jsonb_typeof(v_offenses) != 'array' THEN
        RETURN;
    END IF;

    -- Loop through each offense
    FOR v_offense IN
        SELECT value
        FROM jsonb_array_elements(v_offenses) AS t(value)
    LOOP
        BEGIN
            INSERT INTO QRadar_Offense (
                id,
                "description",
                event_count,
                flow_count,
                device_count,
                severity,
                magnitude,
                last_updated_time,
                "status"
            )
            VALUES (
                (v_offense ->> 'id')::BIGINT,
                v_offense ->> 'description',
                (v_offense ->> 'eventCount')::INTEGER,
                (v_offense ->> 'flowCount')::INTEGER,
                (v_offense ->> 'deviceCount')::INTEGER,
                (v_offense ->> 'severity')::REAL,
                (v_offense ->> 'magnitude')::REAL,
                (timestamptz 'epoch' + (
                    ((v_offense ->> 'lastUpdatedTime')::BIGINT)
                    * interval '1 millisecond'
                )),
                v_offense ->> 'status'
            )
            ON CONFLICT (id) DO UPDATE
                SET "description"     = EXCLUDED.description,
                    event_count       = EXCLUDED.event_count,
                    flow_count        = EXCLUDED.flow_count,
                    device_count      = EXCLUDED.device_count,
                    severity          = EXCLUDED.severity,
                    magnitude         = EXCLUDED.magnitude,
                    last_updated_time = EXCLUDED.last_updated_time,
                    "status"          = EXCLUDED.status;

            -- Process sourceAddressIds nested array to insert additional offense sources
            -- and link the offenses to these sources
            v_all_source_addresses := v_offense -> 'sourceAddressIds';
            IF v_all_source_addresses IS NULL OR jsonb_typeof(v_all_source_addresses) != 'array' THEN
                RETURN;
            END IF;

            FOR v_source_address_ip_id IN
                SELECT value
                FROM jsonb_array_elements(v_all_source_addresses) AS t(value)
            LOOP
                BEGIN
                    v_src_addr_id := v_source_address_ip_id::BIGINT;

                    INSERT INTO QRadar_Offense_Source (id, ip, qradar_domain_id, magnitude)
                    VALUES (v_src_addr_id, NULL, -1, -1.0)
                    ON CONFLICT (id) DO NOTHING;

                    INSERT INTO QRadar_Offense_In_Source (offense_source_id, offense_id)
                    VALUES (v_src_addr_id, (v_offense ->> 'id')::BIGINT)
                    ON CONFLICT (offense_id, offense_source_id) DO NOTHING;
                END;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO Domain_Errors (
                    domain_id,
                    timestamp,
                    source,
                    error,
                    sql_error_code,
                    sql_error_message
                )
                VALUES (
                    p_domain_id,
                    now(),
                    'add_qradar_data',
                    'Cannot process QRadar offense data.',
                    SQLSTATE,
                    SQLERRM
                );
                RETURN;
        END;
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE process_collection_results()
    LANGUAGE plpgsql
AS
$$
DECLARE
    rec                 RECORD;
    v_domain_id         BIGINT;
    v_ip_id             BIGINT;
    v_collector_id      SMALLINT;
    v_collector_for_ip  BOOLEAN;
    v_timestamp         TIMESTAMPTZ;
    v_deserialized_data JSONB;
BEGIN
    -- lock the dummy target so concurrent jobs don’t overlap
    LOCK TABLE Collection_Results_Dummy_Target IN EXCLUSIVE MODE;

    FOR rec IN
        SELECT domain_name, ip, collector, status_code, error, timestamp, raw_data
        FROM Collection_Results_Dummy_Target
        LOOP
            -- convert ms-since-epoch into a TIMESTAMPTZ
            v_timestamp := (timestamptz 'epoch' + (rec.timestamp * interval '1 millisecond'));

            -- insert or look up Domain and IP
            SELECT r_domain_id, r_ip_id
            INTO v_domain_id, v_ip_id
            FROM insert_or_get_domain_and_ip(rec.domain_name, rec.ip, v_timestamp);

            -- parse raw_data JSON, capturing parse errors
            BEGIN
                v_deserialized_data := rec.raw_data::JSONB;
            EXCEPTION
                WHEN OTHERS THEN
                    INSERT INTO Domain_Errors(domain_id, timestamp, source, error, sql_error_code, sql_error_message)
                    VALUES (v_domain_id, v_timestamp, 'process_collection_results',
                            'Cannot parse JSON.', SQLSTATE, SQLERRM);
                    v_deserialized_data := NULL;
            END;

            -- if this is QRadar data and succeeded, process it
            IF rec.collector = 'qradar' AND rec.status_code = 0 THEN
                PERFORM add_qradar_data(v_domain_id, rec.ip, v_timestamp, v_deserialized_data);
            END IF;

            -- look up collector metadata
            SELECT id, is_ip_collector
            INTO v_collector_id, v_collector_for_ip
            FROM Collector
            WHERE collector = rec.collector;

            IF NOT FOUND THEN
                INSERT INTO Domain_Errors(domain_id, timestamp, source, error)
                VALUES (v_domain_id, v_timestamp, 'process_collection_results',
                        'Unknown collector: ' || rec.collector);
                CONTINUE;
            END IF;

            -- if appropriate, update IP-specific fields
            IF v_collector_for_ip AND v_ip_id IS NOT NULL AND v_deserialized_data IS NOT NULL THEN
                PERFORM update_ip_data(
                        v_ip_id,
                        rec.collector,
                        v_deserialized_data,
                        v_timestamp,
                        rec.status_code
                        );
            END IF;

            -- Insert into Collection_Result
            -- IMPORTANT: Change the two occurrences of 'v_deserialized_data' to 'NULL' to disable storing raw data

            -- _template_start_
            INSERT INTO Collection_Result(domain_id, ip_id, source_id, status_code, error, timestamp, raw_data)
            VALUES (v_domain_id, v_ip_id, v_collector_id,
                    rec.status_code, rec.error,
                    v_timestamp, v_deserialized_data)
            ON CONFLICT ON CONSTRAINT collection_result_unique DO UPDATE
                SET status_code = EXCLUDED.status_code,
                    error       = EXCLUDED.error,
                    raw_data    = EXCLUDED.raw_data;
            -- _template_end_
        END LOOP;

    -- clear out everything that was just processed
    DELETE FROM Collection_Results_Dummy_Target;
END;
$$;
