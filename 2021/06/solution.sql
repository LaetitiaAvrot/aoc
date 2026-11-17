/* Making the script idempotent */
drop table if exists input;
drop table if exists work;
drop function if exists fishCounter(integer);

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  value text
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv' with (delimiter ';');

create function fishCounter(counter integer)
returns integer as
$fishCounter$
  select case when counter=0 then 6
    else counter-1
    end as result;
$fishCounter$
language sql immutable;

/* Generating a work table */
select string_agg(mysql,' ')
from
(
  select
  $sql1$create table work(
    id integer generated always as identity,$sql1$ as mysql
  union all
  select
  $sql2$
    day$sql2$
  || n ||
  $sql3$ integer,$sql3$ as mysql
  from generate_series(0,255) as t(n)
  union all
  select $sql4$ day256 integer);$sql4$ as mysql
) as sqlCreation
\gexec


insert into work (day0)
(
  /* Getting the first state of the fishes */
  select string_to_table(value,',')::integer as counter
  from input
);

/* Generate the queries to create the new fishes and calculate the next day*/
select $sql1$insert into work ( day$sql1$
  || n::text ||
$sql2$) ( select 8 from work where day$sql2$
  || (n-1)::text ||
$sql3$ = 0);

update work set day$sql3$
  || n::text ||
$sql4$ = fishCounter(day$sql4$
  || (n-1)::text ||
$sql5$) where day$sql5$
  || (n-1)::text ||
$sql6$ is not null ;$sql6$
from generate_series(1,256) as t(n)
/* Use psql, the best PostgreSQL client */
--;
\gexec

select count(*) as partOne
from work
where day80 is not null;

select count(*) as partTwo
from work
where day256 is not null;

/*PartTwo is just a little longer */
