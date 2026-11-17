/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  value integer
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv' with (null '');

/* get the lastId of the range + the range number (also known as eflNumber) */
with lastId(id, elfNumber) as (
  select lastId, row_number() over(order by lastId)
  from
  (
    select id as lastId
    from input
    where value is null
    union
    select max(id) as lastId
    from input
  )
),
/* get the firstId of the range + the range number (also known as eflNumber) */
firstId(id, elfNumber) as (
  Select firstId, row_number() over(order by firstId)
  From
  (
    select id+1 as firstId
    from input
    where value is null
    union
    select min(id) as firstId
    from input
  )
),
/* get the elfNumber for each value */
elfNumbers(id, elfNumber) as (
  select
    id,
    elfNumber

  from
    (select generate_series(1,max(id))from input) as generated(id) inner join
    (
      select firstid.id as firstId, lastid.id as lastId, firstId.elfNumber
      from lastId inner join firstId
          on lastId.elfNumber = firstId.elfNumber
    ) as idRanges
      on  generated.id >= idRanges.firstId
        and generated.id <= idRanges.lastId -- we can include the null value in the sum
),
/* get the total calories for each elf */
totalCalories(value) as (
  select sum(value) as totalcalories
  from elfNumbers
    inner join input
      on elfNumbers.id = input.id
  group by elfNumber
)

select max(value) as PartOne
from totalCalories;

select sum(value) as first_star
from (
    select value,
           count(*) filter (where value is null) over (order by id) as grp
    from input
)
group by grp
order by first_star desc
fetch first row only
;

/****************************** PART TWO *************************************/

/* get the lastId of the range + the range number (also known as eflNumber) */
with lastId(id, elfNumber) as (
  select lastId, row_number() over(order by lastId)
  from
  (
    select id as lastId
    from input
    where value is null
    union
    select max(id) as lastId
    from input
  )
),
/* get the firstId of the range + the range number (also known as eflNumber) */
firstId(id, elfNumber) as (
  Select firstId, row_number() over(order by firstId)
  From
  (
    select id+1 as firstId
    from input
    where value is null
    union
    select min(id) as firstId
    from input
  )
),
/* get the elfNumber for each value */
elfNumbers(id, elfNumber) as (
  select
    id,
    elfNumber

  from
    (select generate_series(1,max(id))from input) as generated(id) inner join
    (
      select firstid.id as firstId, lastid.id as lastId, firstId.elfNumber
      from lastId inner join firstId
          on lastId.elfNumber = firstId.elfNumber
    ) as idRanges
      on  generated.id >= idRanges.firstId
        and generated.id <= idRanges.lastId
),
/* get the total calories for each elf */
totalCalories(value) as (
  select sum(value) as totalcalories
  from elfNumbers
    inner join input
      on elfNumbers.id = input.id
  group by elfNumber
)

select sum(value) as PartTwo
from (
  select *
  from totalCalories
  order by value desc
  limit 3
);
