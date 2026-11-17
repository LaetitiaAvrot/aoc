/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc cascade;
create schema aoc;
set search_path to 'aoc';

/* Insert data into  table */
create table input (
  id integer generated always as identity primary key,
  value text
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

/* Let's create a map.
 * The cave is 7 units wide. The floor is the 7 points with height 0). We'll
 * also add 5 free lines. 
 * Thanks to my dad pointing that out, as the rocks first moves right/left and
 * then down, we have to code the last movement differently. This is not very
 * smart. My dad suggested that we instead make the rock appear on the 5th line
 * after the highest rock which should make all moves behave the same way (and
 * is possible because the rock will always be able to go down on the first move
 */
create table map (
  p point,
  value char(1) default ('.')
);

insert into map (p) (
  select point(x,y)
  from generate_series(1,7) as x(x),
    generate_series(0,4) as y(y)
);
/* We will consider the floor is rock as it behaves like rock */
update map set value = '#' where p[1]=0;

/* let's create some indexes */
/* We will some time refer to only the y composite of a point (poin[1]),
 * sometime to y and x (point[1] and point[0]), so this index makes sense */
create index on map ((p[1]),(p[0]));
/* We will focus on the occupied zones, so indexing them makes sens. Of course
 * as we're indexing zones, we can't use a btree index (without defining an
 * equality operator), but a gist index is appropriate */
create index on aoc.map using gist (p) where value='#';
/* I;m less sure about this index usage. We'll know after running the code */
create index on aoc.map using gist (p);

create function produceShape(iteration integer) returns point[] as
$produceShape$
  /* We need to first add rows depending on the shape kind */
  with currentRows(ymax,l) as (
    select max(p[1])::integer,
      case when iteration % 5 = 1
        /* The '-' shape */
        then 0
        when iteration % 5 = 2
        /* The '+' shape */
        then 2
        when iteration % 5 = 3
        /* The reverse 'L' shape */
        then 2
        when iteration % 5 = 4
        /* The 'I' shape */
        then 3
        when iteration % 5 = 0
        /* The 'square' shape */
        then 1
      end
    from map
  )
  insert into  map(p) (
    select point(x,y)
    from currentRows,
    /* Cartesian product with a onerow table */
    generate_series(1,7) as x(x),
    /* Legitimate use of cartesian product */
    generate_series(ymax + 1, ymax + l) as y(y));

  select
    case when iteration % 5 = 1
      /* The '-' shape */
      then array[point(3,n),point(4,n),point(5,n),point(6,n)]
      when iteration % 5 = 2
      /* The '+' shape */
      then array[point(4,n),point(3,n-1),point(4,n-1),point(5,n-1),point(4,n-2)]
      when iteration % 5 = 3
      /* The reverse 'L' shape */
      then array[point(5,n),point(5,n-1),point(3,n-2),point(4,n-2),point(5,n-2)]
      when iteration % 5 = 4
      /* The 'I' shape */
      then array[point(3,n),point(3,n-1),point(3,n-2),point(3,n-3)]
      when iteration % 5 = 0
      /* The 'square' shape */
      then array[point(3,n),point(4,n),point(3,n-1),point(4,n-1)]
    end
    from (select max(p[1]) from map) t(n);
$produceShape$ language sql;

create function isFree(rock point[]) returns boolean as
$isFree$
  with points(p) as (
    select p from unnest(rock) t(p)),
  freepoints(p)  as (
    select array_agg(map.p)
    from map
      inner join points
        on map.p ~= points.p
    where map.value <> '#')
  select case when freepoints.p is null
      then false
      else cardinality(freepoints.p) = cardinality(rock)
    end
  from freepoints;
$isFree$ language sql;

/* Let's create a function that will move rock using a point to translate it */
create function moveRock(rock point[], move point) returns point[] as 
$moveRock$
  with desiredMove(r) as (
    select array_agg( p + move )
    from unnest(rock) t(p))
  select 
    /* We only move the rock if the space is available */
    case when p is null
      then
	case when move[1]::integer=-1 then
	  /* if we were moving downward then we need to send an "empty rock" to
	  * make sure we stop the recursive query */
	  array[null::point,null::point,null::point,null::point]
	else
	  /* We simply don't move the rock right/left */
          rock
	end
      else r
    end
  from desiredMove
    left join map
    on isFree(r)
  ;
$moveRock$ language sql;

/* Let's create a function that will move left or right depending on
 * the jet direction provided */
create function moveRock(rock point[], jet char(1)) returns point[] as
$moveRock$
  select
    moveRock(
      array_agg(p),
      point(
        case when jet = '<'
        then
          case when (select min(p[0])) > 1
            then -1
            else 0
          end
        else
          case when (select max(p[0])) < 7
            then 1
            else 0
          end
        end,
        0))
  from unnest(rock) as t(p);
$moveRock$ language sql;

create table jets(jetNumber integer);
/* We really need to begin to 0 or we'll be in trouble once we got after the
 * length of the jet value */
insert into jets (jetNumber) (select 0);

create procedure fallingrock(rockNumber integer) as
$fallingrock$

  /* The rock first tries to move left/right and then tries to move down.
   * It means that odd iteration numbers means moving right/left and even
   * iteration numbers means falling down. */
  with recursive fallingrock (
    jet,
    rock,
    jets,
    n
  ) as (
    select (select jetNumber from jets) as jet,
      produceShape(rockNumber) as rock,
      value as jets,
      1 as n
    from input
    union all
    select 
      case when n%2 = 0
	/* even number : we're falling, we don't need to update the jet number
	 * */
	then jet
	else jet+1
      end,
      case when n%2 = 0
	/* even number : we're falling down */
	then moveRock(rock, point(0,-1))
	else
	  /* odd number : we're going left/right */
          moveRock(rock, substring(jets from (jet%length(jets))+1 for 1))
      end,
      jets,
      n+1
    from fallingrock
    where
      /* We'll stop when the next rock move gives a null points array */
     ( case when n%2 = 0
	/* even number : we're falling down */
	then moveRock(rock, point(0,-1))
	when n%2 = 1
	/* odd number : we're going left/right */
        then moveRock(rock, substring(jets from (jet%length(jets))+1 for 1))
      end)[1] is not null
  ),
  fallenRock (jet, rock) as (
    select jet, rock
    from fallingRock
    order by n desc
    limit 1
  ),
  updateJets (rock) as (
    update jets set jetNumber=jet
    from fallenRock
    returning (rock)
  )
  update map set value = '#'
  from updateJets
  where map.p ~= any(rock)
  ;
  /* Let's make sure we have at least 4 free rows above the highest rock, so that we
   * can produce a new rock and it will have time to fall */
  with freeRows(l, ymax) as (
    select
      case
        when
          (
            max(p[1]) filter (where value = '.') -
            max(p[1]) filter (where value = '#')
          ) < 5
        then 5 -
	  (max(p[1]) filter (where value = '.'))::integer +
	  (max(p[1]) filter (where value = '#'))::integer
        else 0 /* We don't need to create new lines */
      end,
      (max(p[1]) filter (where value = '.'))::integer
    from map)
  insert into map(p) (
  select point(x,y)
  from freeRows,
    /* Cartesian product with a onerow table */
    generate_series(1,7) as x(x),
    /* Legitimate use of cartesian product */
    generate_series(ymax + 1, ymax + l) as y(y));
  /* Let's make sure we have at most 4 free rows above the highest rock, so that we
   * can produce a new rock at the right place */
  with freeRows(ymin) as (
    select min(p[1]) over()
    from map
    group by p[1]
    having string_agg(value,'' order by p[0]) = '.......'
    limit 1)
  delete from map using freeRows
  where map.p[1] >= freeRows.ymin + 4;

  /* Let's try to optimize by removing the useless rows */
  with blockedRows(y,x) as(
    select max(p[1]), p[0]
    from map
    where rockNumber%50 = 0
      and value ='#'
    group by p[0]
  ),
  useless(y) as (
    select min(y)
    from blockedRows
  )
  delete from map where p[1] < (select y from useless);

  /* Let's try to optimize by removing the useless rows */
  with blockedRows(y,x) as(
    select max(p[1]), p[0]
    from map
    where rockNumber%50 = 0
      and value ='#'
    group by p[0]
  ),
  useless(y) as (
    select min(y)
    from blockedRows
  )
  delete from map where p[1] < (select y from useless);

$fallingrock$ language sql;

create view debug as (
  select p[1], string_agg(value,'' order by p[0])
  from map
  group by p[1]
  order by p[1] desc);

\set QUIET on
/* Let's make those rocks fall 2022 times! */
select $$call fallingrock($$ || i || $$);$$
from generate_series(1,2022) as t(i)
\gexec
\set QUIET off

select max(p[1]) as partOne
from map
where value = '#';

/* Let's reinitiate the map */
drop table map cascade;

create table map (
  p point,
  value char(1) default ('.')
);

insert into map (p) (
  select point(x,y)
  from generate_series(1,7) as x(x),
    generate_series(0,4) as y(y)
);
/* We will consider the floor is rock as it behaves like rock */
update map set value = '#' where p[1]=0;

create view debug as (
  select p[1], string_agg(value,'' order by p[0])
  from map
  group by p[1]
  order by p[1] desc);

\set QUIET on
select $$call fallingrock($$ || i || $$);$$
from generate_series(1,1000000000000) as t(i)
\gexec
\set QUIET off

select max(p[1]) as partTwo
from map
where value = '#';

