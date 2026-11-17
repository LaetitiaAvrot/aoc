/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  elf1 text,
  elf2 text,
  elf1range int4range generated always as (
    int4range(
      split_part(elf1,'-',1)::int,
      split_part(elf1,'-',2)::int,
      /* Default for ranges is first bound included, last bound excluded -> [)
       * We want both bounds to be included -> [] */
      '[]')) stored,
  elf2range int4range generated always as (
    int4range(
      split_part(elf2,'-',1)::int,
      split_part(elf2,'-',2)::int,
      /* Default for ranges is first bound included, last bound excluded -> [)
       * We want both bounds to be included -> [] */
      '[]')) stored
);

/* Please use psql, the best PostgreSQL client */
\copy input(elf1,elf2) from 'input.csv' with (delimiter ',');

select count(*) as PartOne
from input
/* The <@ operator checks if a range is fully contained by another */
where elf1range <@ elf2range
  or elf2range <@ elf1range;

select count(*) as PartTwo
from input
/* The <@ operator checks if a range is fully contained by another */
where elf1range && elf2range;
