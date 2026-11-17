/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  opponent text,
  me text,
  shapePointsPartOne integer generated always as (
    case when me='X' then 1
      when me='Y' then 2
      else 3
    end) stored,
  resultPointsPartOne integer generated always as (
    case when (
        opponent='A' and me='Y' or
        opponent='B' and me='Z' or
        opponent='C' and me='X' )
      then 6
      when (
	opponent='A' and me='X' or
	opponent='B' and me='Y' or
	opponent='C' and me='Z' )
      then 3
      else 0
    end) stored,
    PointsPartTwo integer generated always as (
    case when opponent='A' and me='X' then 3
      when opponent='A' and me='Y' then 4
      when opponent='A' and me='Z' then 8
      when opponent='B' and me='X' then 1
      when opponent='B' and me='Y' then 5
      when opponent='B' and me='Z' then 9
      when opponent='C' and me='X' then 2
      when opponent='C' and me='Y' then 6
      when opponent='C' and me='Z' then 7
    end) stored
);

/* Please use psql, the best PostgreSQL client */
\copy input(opponent, me) from 'input.csv' with (delimiter ' ');

/* sum shape and result points */
select sum(shapePointsPartOne) + sum(resultPointsPartOne) as PartOne
from input;

/* sum points part Two */
select sum(PointsPartTwo) as PartTwo from input;
