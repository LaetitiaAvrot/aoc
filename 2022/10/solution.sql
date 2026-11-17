/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity not null,
  value text not null,
  command text not null generated always as (split_part(value,' ',1)) stored,
  arg integer null generated always as (
    case when split_part(value,' ',1) = 'addx'
      then split_part(value,' ',2)::integer
      else null
    end) stored
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

/* Let's generate our cycles numbers */
with recursive calculation(id, command, X, cycleNumAtTheBeginning, cycleNumAtTheEnd) as (
  select id,
    command,
    case when input.command = 'addx'
      then 1 + input.arg
      else 1
    end as X,
    /* Let's say at the beginning, the cycle number is 0 */
    0,
    /* Let's calculate the end cycle number */
    case when command = 'addx'
      then 2
      else 1
    end
  from input
  where id = 1
  union
  select input.id,
    input.command,
    case when input.command = 'addx'
      then calculation.X + input.arg
      else calculation.X
    end as X,
    calculation.cycleNumAtTheEnd as cycleNumAtTheBeginning,
    case when input.command = 'addx'
      then calculation.cycleNumAtTheEnd+2
      else calculation.cycleNumAtTheEnd+1
    end as cycleNumAtTheEnd
  from input
    inner join calculation on input.id = calculation.id + 1
),
maxCycles (n) as (
  select max(cycleNumAtTheEnd)
  from calculation
),
allData (id, X) as (
  select
     /* Note that if the first command is addx, then I will miss the first
     * 2 rows, but I don't need them */
    t.n+1,
    coalesce(X, lag(X) over w)
  from maxCycles,
    /* Cartesian product with a one row table */
    calculation
  right join generate_series(1,maxCycles.n) as t(n)
    on calculation.cyclenumattheend = t.n
  window w as (order by t.n)
)
select sum(id*X) as partOne
from allData
where id in (20, 60, 100, 140, 180, 220)
;

/* Let's go to part 2 */
with recursive calculation(id, command, X, cycleNumAtTheBeginning, cycleNumAtTheEnd) as (
  select id,
    command,
    case when input.command = 'addx'
      then 1 + input.arg
      else 1
    end as X,
    /* Let's say at the beginning, the cycle number is 0 */
    0,
    /* Let's calculate the end cycle number */
    case when command = 'addx'
      then 2
      else 1
    end
  from input
  where id = 1
  union
  select input.id,
    input.command,
    case when input.command = 'addx'
      then calculation.X + input.arg
      else calculation.X
    end as X,
    calculation.cycleNumAtTheEnd as cycleNumAtTheBeginning,
    case when input.command = 'addx'
      then calculation.cycleNumAtTheEnd+2
      else calculation.cycleNumAtTheEnd+1
    end as cycleNumAtTheEnd
  from input
    inner join calculation on input.id = calculation.id + 1
),
maxCycles (n) as (
  select max(cycleNumAtTheEnd)
  from calculation
),
allData (cycle, position, sprite, X) as (
  select
     /* Note that if the first command is addx, then I will miss the first
     * 2 rows, so I'll add them at the end */
    t.n+1,
    t.n,
    int4range(coalesce(X, lag(X) over w)-1,
      coalesce(X, lag(X) over w)+1,
      '[]'),
    coalesce(X, lag(X) over w)
  from maxCycles,
    /* Cartesian product with a one row table */
    calculation
  right join generate_series(2,maxCycles.n) as t(n)
    on calculation.cyclenumattheend = t.n
  window w as (order by t.n)
  /*Adding the first 2 rows */
  union all
  select t.n, t.n-1, '[0,2]'::int4range,1
  from generate_series(1,2) t(n)
)
select 1, string_agg(pixel, '')
from (select case when sprite @> position then '#' else '.' end as pixel
  from allData
  where cycle between 1 and 40
  order by position)
union all
select 2, string_agg(pixel, '')
from (select case when sprite @> position-40 then '#' else '.' end as pixel
  /* It's the second line, we need to substract 40 from the position as the
   * position means the "horizontal" position */
  from allData
  where cycle between 41 and 80
  order by position)
union all
select 3, string_agg(pixel, '')
from (select case when sprite @> position-80 then '#' else '.' end as pixel
  from allData
  where cycle between 81 and 120
  order by position)
union all
select 4, string_agg(pixel, '')
from (select case when sprite @> position-120 then '#' else '.' end as pixel
  from allData
  where cycle between 121 and 160
  order by position)
union all
select 5, string_agg(pixel, '')
from (select case when sprite @> position-160 then '#' else '.' end as pixel
  from allData
  where cycle between 161 and 200
  order by position)
union all
select 6, string_agg(pixel, '')
from (select case when sprite @> position-200 then '#' else '.' end as pixel
  from allData
  where cycle between 201 and 240
  order by position)
;
