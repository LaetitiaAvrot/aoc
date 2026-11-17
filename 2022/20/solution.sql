/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc cascade;
create schema aoc;
set search_path to 'aoc';

/* Insert data into  table */
create table input (
  id integer generated always as identity primary key,
  data integer,
  orderBy integer
);

/* Please use psql, the best PostgreSQL client */
\copy input(data) from 'input.csv';

/* It's easier to begin the order with 0 as we will rely on modulos */
update input set orderBy = id - 1;

create function calculateNewRank(newNum integer) returns integer as
$calculateNewRank$
  with extremes(minNum, maxNum) as (
    select 0, count(*)
    from input
  )
  select
    case when newNum <= minNum
        then maxNum + newNum%maxNum - 1
      when newNum > minNum and newNum <= maxNum
	then newNum
      when newNum > maxNum
	then newNum%maxNum + 1
    end
  from extremes;
$calculateNewRank$ language sql;

create procedure mix(myid integer) as
$mix$
  /* Let's create a query result with the new calculated rank for the mixed id
   * */
  with mixed(id, newRank, oldRank) as (
    select id,
      calculateNewRank(orderby + data),
      orderby
    from input
    where id = myId
  ),
  toUpdate(id, orderby) as (
    /* If the newRank is > than the old Rank, then we need to retrieve one to each
     * number between the old rank  and the newRank (inclusive)
     * If the newRank is < than the old Rank, we need to add one to each number
     * between the newRank and the oldRank (onclusive) */
    select input.id,
      case when newRank > oldRank and orderby between oldRank and newRank
        then orderby - 1
        when oldRank > newRank and orderby between newRank and oldRank
        then orderby + 1
        else orderby
      end
    from input,
      /* Cartesian product with a one row table */
      mixed
    where input.id <> myId
    union
    select id, newRank
    from mixed
  )
  update input
  set orderby = toUpdate.orderBy
  from toUpdate
  where input.id = toUpdate.id;
$mix$ language sql;

with num(num) as (
  select count(*)
  from input
)
select 'call mix('||x||')'
from num, generate_series(1,num) t(x)
\gexec

/* Let's calculate the result */
with num(num) as (
  select count(*)
  from input
),
zero(num) as (
  select orderby
  from input
  where data = 0
)
select sum(data)
from input,
  /* Cartesian product with a one row table */
  zero,
  /* Cartesain product with a one row table */
  num
where orderby = (1000 + zero.num)%num.num
  or orderby = (2000 + zero.num)%num.num
  or orderby = (3000 + zero.num)%num.num
;
