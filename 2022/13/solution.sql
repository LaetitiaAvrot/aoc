/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity not null,
  value text
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

/* Let's clean the input */
drop table if exists packets;
create table packets (
  id integer generated always as identity not null,
  firstP text,
  secondP text
);

with firstPacket (id, value) as (
  select *
  from input
  where id in (
    /* There is no empty line before the first line */
    select 1
    union all
    select id+1
    from input where value = ''
  )
),
secondPacket (id, value) as (
  select *
  from input
  where id in (
    /* There is no empty line before the first line */
    select 2
    union all
    select id+2
    from input where value = ''
  )
)
select $$ insert into packets (firstP, secondP) values ('$$ ||
  firstPacket.value ||
  $$', '$$ ||
  secondPacket.value ||
  $$');$$
from firstPacket
  inner join secondPacket
    on firstPacket.id + 1 = secondPacket.id;
\gexec
