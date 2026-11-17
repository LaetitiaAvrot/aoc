/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  value text,
  /* The first 2 rows are not bingo cards!! */
  /* Some of the rows begin with a space which will create an empty string we
   * don't want. That's why we'll use array_remove.*/
  v1 integer generated always as (case when id > 2 then (array_remove(regexp_split_to_array(value, ' +'), ''))[1]::integer  else null end) stored,
  v2 integer generated always as (case when id > 2 then (array_remove(regexp_split_to_array(value, ' +'), ''))[2]::integer  else null end) stored,
  v3 integer generated always as (case when id > 2 then (array_remove(regexp_split_to_array(value, ' +'), ''))[3]::integer  else null end) stored,
  v4 integer generated always as (case when id > 2 then (array_remove(regexp_split_to_array(value, ' +'), ''))[4]::integer  else null end) stored,
  v5 integer generated always as (case when id > 2 then (array_remove(regexp_split_to_array(value, ' +'), ''))[5]::integer  else null end) stored
  );

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

/* We might need a function to sort an array, here it is */
CREATE OR REPLACE FUNCTION array_sort (ANYARRAY)
RETURNS ANYARRAY LANGUAGE SQL
AS $$
SELECT ARRAY(SELECT unnest($1) ORDER BY 1)
$$;

/* We might need a function to sum a array elements, here it is */
CREATE OR REPLACE FUNCTION array_sum (integer[])
RETURNS integer LANGUAGE SQL
AS $$
SELECT sum(data) from unnest($1) as input(data)
$$;

/* We have to get the data in the right order so that we can after split the
 * array in several sets of columns */
with orderedinput(id, v1, v2, v3, v4, v5) as (
  select
    case
      when id%6 = 3 then id
      when id%6 = 4 then id-1
      when id%6 = 5 then id-2
      when id%6 = 0 then id-3
      when id%6 = 1 then id-4
    else null
    end as id,
    v1,
    v2,
    v3,
    v4,
    v5
  from input
  where v1 is not null
  order by id),
rowsandcolumns(id, v) as (
  /* First, we'll conpute rows and columns in arrays, so that we'll "just" have to
   * find out if the random numbers are there */
  select
    case
      when id%6 = 3 then id
      when id%6 = 4 then id-1
      when id%6 = 5 then id-2
      when id%6 = 0 then id-3
      when id%6 = 1 then id-4
    else null
    end as id,
    array_sort(array[v1,v2,v3,v4,v5])
  from input
  /* If v1 is null, all the others will be */
  where v1 is not null
  union all
  /* Now it's time to compute the columns */
  select id, array_sort(array_agg(v1))
  from orderedinput
  group by id
  union all
  select id, array_sort(array_agg(v2))
  from orderedinput
  group by id
  union all
  select id, array_sort(array_agg(v3))
  from orderedinput
  group by id
  union all
  select id, array_sort(array_agg(v4))
  from orderedinput
  group by id
  union all
  select id, array_sort(array_agg(v5))
  from orderedinput
  group by id
),
/* We'll now compute all the arrays of results that will be taken at random */
/* For example, should we have the values 1,2,3, we'd like to get this result
 * {1}
 * {1,2}
 * {1,2,3}
 * I will use the following array functions:
 * - array_length to find out how many numbers I have (and so how many rows I'll
 * need to get in the result)
 * - trim_array to remove the unwanted numbers
 * - generated_series to generate all numbers between 1 and the total numbers
 * picked at the random by the bingo game */
data(v) as (
  select  (string_to_array(value, ','))::integer[]
  from input
  where id =1
),
draw(v) as (
  select array_sort(trim_array(v, n-1)), n
  from data,
    generate_series(1,array_length(v,1)) as n
  order by n desc
),
bingo(id, v, draw, lastdrawposition) as (
  select id, rowsandcolumns.v, draw.v, array_length(draw.v,1)
  from rowsandcolumns
    inner join draw
    on draw.v @> rowsandcolumns.v
  order by array_length(draw.v,1)
  fetch first 1 row only
),
unmarked(summednumbers) as (
  select sum(numbers)
  from (
      /* Due to rows and columns, we'll get each number twice. We could divide
       * by 2 the sum, but using distinct in that case is fine too */
      select distinct unnest(rowsandcolumns.v)
      from bingo inner join rowsandcolumns
        on bingo.id = rowsandcolumns.id) as card(Numbers)
  where card.numbers not in (
      select unnest(bingo.draw)
      from bingo)
)
select summednumbers
  *
    data.v[lastdrawposition]
  as resultPartOne
from bingo,
  /* Cartesian product with a one row table */
  data,
  /* Cartesian product with a one row table */
  unmarked
group by summednumbers, lastdrawposition, data.v
;

/* We have to get the data in the right order so that we can after split the
 * array in several sets of columns */
with orderedinput(id, v1, v2, v3, v4, v5) as (
  select
    case
      when id%6 = 3 then id
      when id%6 = 4 then id-1
      when id%6 = 5 then id-2
      when id%6 = 0 then id-3
      when id%6 = 1 then id-4
    else null
    end as id,
    v1,
    v2,
    v3,
    v4,
    v5
  from input
  where v1 is not null
  order by id),
rowsandcolumns(id, v) as (
  /* First, we'll conpute rows and columns in arrays, so that we'll "just" have to
   * find out if the random numbers are there */
  select
    case
      when id%6 = 3 then id
      when id%6 = 4 then id-1
      when id%6 = 5 then id-2
      when id%6 = 0 then id-3
      when id%6 = 1 then id-4
    else null
    end as id,
    array_sort(array[v1,v2,v3,v4,v5])
  from input
  /* If v1 is null, all the others will be */
  where v1 is not null
  union all
  /* Now it's time to compute the columns */
  select id, array_sort(array_agg(v1))
  from orderedinput
  group by id
  union all
  select id, array_sort(array_agg(v2))
  from orderedinput
  group by id
  union all
  select id, array_sort(array_agg(v3))
  from orderedinput
  group by id
  union all
  select id, array_sort(array_agg(v4))
  from orderedinput
  group by id
  union all
  select id, array_sort(array_agg(v5))
  from orderedinput
  group by id
),
/* We'll now compute all the arrays of results that will be taken at random */
/* For example, should we have the values 1,2,3, we'd like to get this result
 * {1}
 * {1,2}
 * {1,2,3}
 * I will use the following array functions:
 * - array_length to find out how many numbers I have (and so how many rows I'll
 * need to get in the result)
 * - trim_array to remove the unwanted numbers
 * - generated_series to generate all numbers between 1 and the total numbers
 * picked at the random by the bingo game */
data(v) as (
  select  (string_to_array(value, ','))::integer[]
  from input
  where id =1
),
draw(v) as (
  select array_sort(trim_array(v, n-1))
  from data,
    generate_series(1,array_length(v,1)) as n
  order by n desc
),
bingo(id, lastdrawposition) as (
  select id, min(array_length(draw.v,1))
  from rowsandcolumns
    inner join draw
    on draw.v @> rowsandcolumns.v
  /* I guess we just need to reverse the order to get the last winning card */
  group by id
  order by min(array_length(draw.v,1)) desc
  fetch first 1 row only
),
unmarked(summednumbers) as (
  select sum(numbers)
  from (
      /* Due to rows and columns, we'll get each number twice. We could divide
       * by 2 the sum, but using distinct in that case is fine too */
      select distinct unnest(rowsandcolumns.v)
      from bingo inner join rowsandcolumns
        on bingo.id = rowsandcolumns.id) as card(Numbers)
  where card.numbers not in (
      select unnest((draw.v)[:bingo.lastdrawposition])
      from draw
        inner join bingo
        on array_length(draw.v,1) = bingo.lastdrawposition 
    )
)
select (summednumbers *
    data.v[lastdrawposition])
  as resultParTwo
from bingo,
  /* Cartesian product with a one row table */
  data,
  /* Cartesian product with a one row table */
  unmarked
group by summednumbers, lastdrawposition, data.v
;
