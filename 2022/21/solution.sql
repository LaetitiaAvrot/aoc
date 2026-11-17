/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc cascade;
create schema aoc;
set search_path to 'aoc';

/* Insert data into  table */
create table input (
  id integer generated always as identity primary key,
  data text not null,
  monkey text generated always as ((regexp_split_to_array(data,':'))[1]) stored unique not null,
  /* This column is nullable */
  yell bigint,
  /* previous monkey1 */
  previousMonkey1 text generated always as (
    case when data !~ ': \d+'
      then substring(data from 7 for 4)
    end) stored references input(monkey),
  /* previous monkey2 */
  previousMonkey2 text generated always as (
    case when data !~ ': \d+'
      then substring(data from 14 for 4)
    end) stored references input(monkey),
  operation char(1) generated always as (
    case when data !~ ': \d+'
      then substring(data from 12 for 1)
    end) stored,
  calculate text
);

--/* Please use psql, the best PostgreSQL client */
--\copy input(data) from 'input.csv';
--
--/* First, find the easy monkeys: the ones that yells */
--update input set yell = (
--  case when data ~ ': \d+'
--    then  (regexp_split_to_array(data,': '))[2]::bigint
--  end);
--update input set calculate = yell || '::bigint' where yell is not null;
--update input set calculate = '(' || previousMonkey1 || operation || previousMonkey2 || ')' where yell is null;
--/* Please use psql, the best PostgreSQL client */
--\copy input(data) from 'input.csv';
--
--/* First, find the easy monkeys: the ones that yells */
--update input set yell = (
--  case when data ~ ': \d+'
--    then  (regexp_split_to_array(data,': '))[2]::bigint
--  end);
--update input set calculate = yell || '::bigint' where yell is not null;
--update input set calculate = '(' || previousMonkey1 || operation || previousMonkey2 || ')' where yell is null;
--
--select * from input order by id;
--
--create function makeMonkeyYell(out previousQueries text) as
--$makeMonkeyYell$
--  with readyToYell(id, calculate) as (
--    /* Find the monkeys who has 2 previous monkeys who are yelling monkeys */
--    select input.id,
--      regexp_replace(regexp_replace(input.calculate, i3.monkey, i3.calculate), i2.monkey, i2.calculate)
--    from input inner join input i2
--      on i2.monkey = input.previousMonkey1
--      inner join input i3
--      on i3.monkey = input.previousMonkey2
--    where input.calculate ~ $$[a-z]{4}$$
--      and i3.yell is not null
--      and i2.yell is not null)
--  /* Make those monkeys yell */
--  select string_agg($$update input set yell=$$ || readyToYell.calculate ||
--      $$, calculate=($$ || readyToYell.calculate || $$)::text || '::bigint' where id=$$ || input.id, ';')
--  from input
--    inner join readyToYell on input.id = readyToYell.id
--$makeMonkeyYell$ language sql;
--
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec
--select makeMonkeyYell() \gexec

select yell as PartOne from input where monkey = 'root';

/* Let's start from the beginning again */
--drop table input;
--/* Insert data into  table */
--create table input (
--  id integer generated always as identity primary key,
--  data text not null,
--  monkey text generated always as ((regexp_split_to_array(data,':'))[1]) stored unique not null,
--  /* This column is nullable */
--  yell bigint,
--  /* previous monkey1 */
--  previousMonkeys text[], /*generated always as (
--    case when data !~ ': \d+'
--      then substring(data from 7 for 4)
--    end) stored references input(monkey),
--  /* previous monkey2 */
--  /*previousMonkey2 text generated always as (
--    case when data !~ ': \d+'
--      then substring(data from 14 for 4)
--    end) stored references input(monkey),*/
--  operation char(1) generated always as (
--    case when data !~ ': \d+'
--      then substring(data from 12 for 1)
--    end) stored,
--  calculate text,
--  treated boolean default false
--);
truncate input;

/* Please use psql, the best PostgreSQL client */
\copy input(data) from 'input.csv';

/* First, find the easy monkeys: the ones that yells */
update input set yell = (
  case when data ~ ': \d+'
    then  (regexp_split_to_array(data,': '))[2]::bigint
  end);
update input set calculate = yell || '::bigint' where yell is not null;
update input set calculate = '(' || previousMonkey1 || operation || previousMonkey2 || ')' where yell is null;
update input set calculate = 'x' where monkey= 'humn';
update input set calculate = '(' || previousMonkey1 || '=' || previousMonkey2 || ')' where  monkey='root';

--update input
--set monkeys = array_append(
--  array_append(monkeys,substring(data from 7 for 4)),
--    substring(data from 14 for 4))
--where data !~ ': \d+';

select * from input order by id;

select regexp_replace(regexp_replace(calculate, 'pppw', '(cczh/lfqf)'), 'sjmn', '(drzm*dbpl)')
from (values ('(pppw=sjmn)')) as t(calculate);
/* Find the first monkey chain from root */
with recursive monkeyChain as (
  select monkey,
    previousmonkey1,
    previousmonkey2,
    calculate as yell,
    operation,
    calculate
  from input
  where monkey = 'root'
  union all
  select i1.monkey,
    i1.previousMonkey1,
    i1.previousMonkey2,
    i1.calculate,
    i1.operation,
    regexp_replace(
      regexp_replace(monkeyChain.calculate, i1.monkey, i1.calculate),
      i2.monkey,
      i2.calculate)
  from input as i1
    inner join monkeyChain
      on i1.monkey = monkeyChain.previousMonkey1
    inner join input as i2
      on i2.monkey = monkeyChain.previousMonkey2
)
select * from monkeyChain;
