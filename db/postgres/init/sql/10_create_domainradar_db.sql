create table domains_input (
    id            serial    primary key,
    domain        text      not null,
    added         timestamp not null,
    filter_output jsonb
);

create table dn_collectors_states
(
    domain_name  text      not null,
    collector    text      not null,
    last_attempt timestamp not null,
    status_code  smallint  not null,
    error        text,
    constraint dn_collectors_states_pk
        primary key (domain_name, collector)
);

create index dn_collectors_states_domain_name_index
    on dn_collectors_states (domain_name);

create table ip_collectors_states
(
    domain_name  text      not null,
    ip           text      not null,
    collector    text      not null,
    last_attempt timestamp not null,
    status_code  smallint  not null,
    error        text,
    constraint ip_collectors_states_pk
        primary key (domain_name, ip, collector)
);

create index ip_collectors_states_domain_name_index
    on ip_collectors_states (domain_name);
