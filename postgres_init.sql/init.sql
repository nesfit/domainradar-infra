create table domains_input (
    id SERIAL PRIMARY KEY,
    domain VARCHAR(255) NOT NULL,
    added TIMESTAMP NOT NULL,
    filter_output JSONB
);
