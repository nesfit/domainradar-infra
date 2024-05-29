-- Add connect permissions on the database to all three users
grant connect on database :DOMRAD_DB_NAME to :PREFILTER_USER;
grant connect on database :DOMRAD_DB_NAME to :CONNECT_USER;
grant connect on database :DOMRAD_DB_NAME to :INGESTION_USER;

-- Add usage permissions on the default schema to all three users
grant usage on schema public to :PREFILTER_USER;
grant usage on schema public to :CONNECT_USER;
grant usage on schema public to :INGESTION_USER;

grant select, usage on all sequences
    in schema public to :PREFILTER_USER;

-- The input table
grant select, insert, update
    on table domains_input to :PREFILTER_USER;
grant select
    on table domains_input to :CONNECT_USER;
grant select, update
    on table domains_input to :INGESTION_USER;

-- The DN-only collectors state tables
grant select, insert, update
    on table dn_collectors_states to :CONNECT_USER;
grant select
    on table dn_collectors_states to :INGESTION_USER;

-- The IP collectors state tables
grant select, insert, update
    on table ip_collectors_states to :CONNECT_USER;
grant select
    on table ip_collectors_states to :INGESTION_USER;
