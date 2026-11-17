/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc11 cascade;
create schema aoc11;
set search_path to 'aoc11';

/* Insert data into  table */
create table input (
  id integer generated always as identity not null,
  value text not null
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

create table monkeys (
  monkey integer,
  worry numeric,
  operation text,
  secondOperand integer,
  divisibleBy integer,
  ifTrue integer,
  ifFalse integer
);

with cleanup (monkey,items, operation, secondOperand, divisibleBy, IfTrue, IfFalse) as (
  select trim(leading 'Monkey ' from trim(trailing ':' from value)),
    replace(trim(leading '  Starting items: ' from lead(value) over w), ' ', ''),
    substring(trim(leading '  Operation: new = old ' from lead(value,2) over w) for 1),
    case
      when substring(trim(leading '  Operation: new = old ' from lead(value,2) over w) from 3)='old'
        then null
      else substring(trim(leading '  Operation: new = old ' from lead(value,2) over w) from 3)
    end,
    trim(leading '  Test: divisible by ' from lead(value,3) over w),
    trim(leading '    If true: throw to monkey ' from lead(value,4) over w),
    trim(leading '    If false: throw to monkey ' from lead(value,5) over w)
  from input
  window w as (order by id)
)
insert into monkeys (monkey, worry, operation, secondOperand, divisibleBy, ifTrue, ifFalse)(
  select monkey::integer,
    string_to_table(items, ',')::numeric,
    operation,
    secondOperand::integer,
    divisibleBy::integer,
    ifTrue::integer,
    ifFalse::integer
  from cleanup
  where monkey ~ '^[0-7]$')
;

with recursive calculate (rounds, monkey, worry, operation, secondOperand,
divisibleBy, ifTrue, ifFalse, nextWorry) as (
  select 1,
    monkey,
    worry,
    operation,
    secondOperand,
    divisibleBy,
    ifTrue,
    ifFalse,
    case
      when operation = '+'
        then  floor((worry + secondoperand)/3)
      when operation = '-'
        then  floor((worry - secondoperand)/3)
      when operation = '*' and secondoperand is not null
        then  floor((worry * secondoperand)/3)
      else  floor((worry * worry)/3)
    end
  from monkeys
  union all
  select rounds+1,
    m.monkey,
    nextWorry,
    m.operation,
    m.secondoperand,
    m.divisibleBy,
    m.iftrue,
    m.iffalse,
    case
      when m.operation = '+'
        then  floor((nextworry + m.secondoperand)/3)
      when m.operation = '-'
        then  floor((nextworry - m.secondoperand)/3)
      when m.operation = '*' and m.secondoperand is not null
        then  floor((nextworry * m.secondoperand)/3)
      else  floor((nextworry * nextworry)/3)
    end
  from calculate as c inner join monkeys as m
    on case when c.nextWorry%c.divisibleby=0
        then c.iftrue
      else c.iffalse end = m.monkey
    /* The monkeys operate in order */
    and m.monkey < c.monkey
  where rounds < 20
)
select count(*), monkey
from calculate
group by monkey
;
--drop function if exists worryLevel;
--create function worryLevel(n numeric, mymonkey integer, relief integer) returns numeric as
--$worryLevel$
--  select
--    case when operation = '* old'
--     	then trunc(n * n/relief)
--      when operation ~ '^\+'
--        then trunc((n + (split_part(operation, ' ', 2))::numeric)/relief)
--      when operation ~ '^\*'
--        then trunc((n * (split_part(operation, ' ', 2))::numeric)/relief)
--    end as result
--  from parameters
--  where parameters.monkey = mymonkey;
--$worryLevel$ language sql;
--
--drop function if exists calculateMonkey;
--create function calculateMonkey(n numeric, mymonkey integer, relief integer) returns numeric as
--$calculateMonkey$
--  select
--    case when (worrylevel(n,mymonkey, relief)%divisibleBy = 0)
--     then ifTrue
--    else ifFalse end as result
--  from parameters
--  where parameters.monkey = mymonkey;
--$calculateMonkey$ language sql;
--
--drop function if exists process;
--create function process(mymonkey integer, myround integer, relief integer) returns text as
--$process$
--select $$with updated(monkey, item) as ($$||
--  $$update monkeys set done = true where not done $$ ||
--  $$ and roundNumber = $$ || myround ||
--  $$ and monkey = $$ || mymonkey ||
--  $$ returning monkey, item),$$ ||
--  $$ calculation(monkey, nextmonkey,worrybegin, worryend) as ($$ ||
--  $$select monkey, calculateMonkey(item,monkey,$$ || relief  || $$), $$ ||
--  $$  item, worryLevel(item,monkey,$$ || relief || $$)$$ ||
--  $$from updated) $$ ||
--  $$insert into monkeys ($$ ||
--  /* The new round only if the monkey has a lower number as the current monkey*/
--  $$select case when nextMonkey > monkey then $$ || myround ||
--  $$ else $$ || myround + 1 || $$ end, nextmonkey, worryend, false$$ ||
--  $$ from calculation)$$ as result;
--$process$ language sql;
--
--/* We don't want all the execution details */
--\set QUIET on
--
--select process(monkey.n,rounds.n,3)
--/* I counted round 0, so I need to go to round 19 to have 20 rounds */
--from generate_series(0,19) rounds(n),
-- generate_series(0,7) monkey(n)
--order by rounds.n, monkey.n
--\gexec
--
--with scores(roundNumber, Monkey, itemCount) as (
--  select roundNumber,
--    monkey,
--   count(item)
--  from monkeys
--  group by roundNumber, monkey
--), busiestMonkeys(monkey, score) as (
--  select monkey,
--    sum(itemCount)
--  from scores
--  where roundNumber < 20 /* We need to retrieve round 20 or we'll have 21 rounds */
--  group by monkey
--  order by sum(itemCount) desc
--  limit 2)
--select
--  (select score from busiestMonkeys limit 1) *
--  (select score from busiestMonkeys limit 1 offset 1) as partOne;
--
--/* Cleanup operation */
--truncate table monkeys;
--
--with cleanup (monkey,items, operation, divisibleBy, IfTrue, IfFalse) as (
--  select trim(leading 'Monkey ' from trim(trailing ':' from value)),
--    replace(trim(leading '  Starting items: ' from lead(value) over w), ' ', ''),
--    trim(leading '  Operation: new = old ' from lead(value,2) over w),
--    trim(leading '  Test: divisible by ' from lead(value,3) over w),
--    trim(leading '    If true: throw to monkey ' from lead(value,4) over w),
--    trim(leading '    If false: throw to monkey ' from lead(value,5) over w)
--  from input
--  window w as (order by id)
--)
--insert into monkeys (
--  select 0,
--    monkey::integer,
--    string_to_table(items, ',')::numeric
--  from cleanup
--  where monkey ~ '^[0-7]$')
--;
--
--select process(monkey.n,rounds.n,1)
--from generate_series(0,9999) rounds(n),
-- generate_series(0,7) monkey(n)
--order by rounds.n, monkey.n
--\gexec
--
--with scores(roundNumber, Monkey, itemCount) as (
--  select roundNumber,
--    monkey,
--   count(item)
--  from monkeys
--  group by roundNumber, monkey
--), busiestMonkeys(monkey, score) as (
--  select monkey,
--    sum(itemCount)
--  from scores
--  where roundNumber < 10000
--  group by monkey
--  order by sum(itemCount) desc
--  limit 2)
--select
--  (select score from busiestMonkeys limit 1) *
--  (select score from busiestMonkeys limit 1 offset 1) as partTwo;


