/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  v integer
  );

/* Please use psql, the best PostgreSQL client */
\copy input(v) from 'input.csv';

/* We need to compare a row with its previous row which screams window functions
 * and lag function. (see
 * https://www.postgresql.org/docs/current/functions-window.html) fro more
 * details.)
 * */
with mydata(currentv, previousv) as 
  (select v,
    lag(v) over (order by id)
  from input
)
/* We "just" have to select the rows where the depth is increasing */
select count(*) as resultPartOne
from mydata
where currentv > previousv;

/* Reusing previous code  to create the 3 rows window */
with mydata(id, windowdepth) as
  (select id,
    v +
    lead(v) over (order by id) +
    lead(v, 2) over (order by id) 
  from input
),
newdata(currentv, previousv) as (
  select windowdepth,
    lag(windowdepth) over (order by id)
  from mydata
  where windowdepth is not null
)
/* We "just" have to select the rows where the depth is increasing */
select count(*) as resultPartTwo
from newdata
where currentv > previousv;

