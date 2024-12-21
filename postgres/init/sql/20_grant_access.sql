-- Add connect permissions on the database to all the users
grant connect on database :DOMRAD_DB_NAME to :PREFILTER_USER;
grant connect on database :DOMRAD_DB_NAME to :CONNECT_USER;
grant connect on database :DOMRAD_DB_NAME to :INGESTION_USER;
grant connect on database :DOMRAD_DB_NAME to :WEBUI_USER;

-- Add usage permissions on the default schema to all the users
grant usage on schema public to :PREFILTER_USER;
grant usage on schema public to :CONNECT_USER;
grant usage on schema public to :INGESTION_USER;
grant usage on schema public to :WEBUI_USER;

-- Add sequence permissions
grant select, usage on all sequences
    in schema public to :PREFILTER_USER;
grant select, usage on all sequences
    in schema public to :WEBUI_USER;

-- The input table
grant select, insert, update
    on table domains_input to :PREFILTER_USER;
grant select
    on table domains_input to :CONNECT_USER;
grant select, update
    on table domains_input to :INGESTION_USER;
grant select, insert
    on table domains_input to :WEBUI_USER;

-- The custom prefilter tables
grant select
    on table custom_prefilter, custom_prefiltered_domain to :PREFILTER_USER;

-- The dummy input tables for the pipeline sinks
grant select, insert, update
    on table collection_results_dummy_target, classification_results_dummy_target to :CONNECT_USER;

-- The input table for the feature vectors
grant select, insert, update
    on table feature_vector to :CONNECT_USER;

-- The tables on which the database procedures triggered by CONNECT_USER operate
grant select
    on table classification_category, classifier_type, collector to :CONNECT_USER;

grant select, insert, update
    on table domain, ip to :CONNECT_USER;
    
grant select, insert, update
    on table collection_result to :CONNECT_USER;

grant select, insert, update
    on table classification_category_result, classifier_output to :CONNECT_USER;

grant select, insert, update
    on table qradar_offense, qradar_offense_source, qradar_offense_in_source to :CONNECT_USER;

grant insert
    on table domain_errors to :CONNECT_USER;

-- The tables used by the web UI to display the results
grant select
    on table domain, ip, collection_result, classification_category_result, classifier_output,
             qradar_offense, qradar_offense_source, domain_errors, classification_category,
             classifier_type, collector, domains_input, custom_prefilter, custom_prefiltered_domain
    to :WEBUI_USER;

grant insert, update, delete
    on table custom_prefilter, custom_prefiltered_domain
    to :WEBUI_USER;

            

