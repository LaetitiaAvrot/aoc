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
  map boolean generated always as (data ~ '[\.|#]') stored
);

\copy input(data) from 'input.csv';

/* let's create the map */
create table map (
  x integer not null,
  y integer not null,
  value char(1) default ('.'),
  primary key (x,y)
);

create view debug as (
  with maxX(value) as (
    select max(length(data))
    from input
    where map
  ),
  maxY(value) as (
    select count(*)
    from input
    where map
  ),
  grid(x,y) as (
    select x,
      y
    from maxX,
      /* cartesian product with a one-row table */
      maxY,
      /* cartesian product with a one-row table */
      generate_series(1,maxX.value) as t(x),
      /* On purpose cartesain product as we need to generate a grid */
      generate_series(1,maxY.value) as t2(y)
  )
  select grid.y, string_agg(coalesce(value::text,' '::text),'' order by grid.x)
  from map
    right join grid
      on map.x = grid.x
      and map.y = grid.y
  group by grid.y
  order by grid.y);

/* Let's add the free space */
with recursive fSpace as (
  select 1 as n,
    id,
    array[regexp_instr(data,'\.',1,1)] as pos
  from input
  where map
  union
  select n+1,
    id,
    pos || array[regexp_instr(data,'\.',1,n+1)]
  from fSpace
    natural join input
  where map
    and regexp_instr(data,'\.',1,n+1) <> 0
)
insert into map (x, y, value) (
  select distinct unnest(pos), id, '.'
  from fSpace);

/* Let's add the walls */
with recursive walls as (
  select 1 as n,
    id,
    array[regexp_instr(data,'#',1,1)] as pos
  from input
  where map
  union
  select n+1,
    id,
    pos || array[regexp_instr(data,'#',1,n+1)]
  from walls
    natural join input
  where map
    and regexp_instr(data,'#',1,n+1) <> 0
)
insert into map (x, y, value) (
  select distinct unnest(pos), id, '#'
  from walls);

/* Let's create a table to  manage direction changes */
create type dir as enum ('right', 'left', 'up', 'down');

create table directions (
  currentDir dir not null,
  turn char(1) not null,
  nextDir dir  not null,
  value integer not null, /* the value is the facing value of the Current direction to be used at the end */
  primary key (currentDir, turn)
);

insert into directions (currentDir, turn, nextDir, value)(
  values
    ('right', 'R', 'down', 0),
    ('left', 'R', 'up', 2),
    ('up', 'R', 'right', 3),
    ('down', 'R', 'left', 1),
    ('right', 'L', 'up', 0),
    ('left', 'L', 'down', 2),
    ('up', 'L', 'left', 3),
    ('down', 'L', 'right', 1));


create function moveRight(startingPoint point, duration integer) returns point as
$moveRight$
  with recursive moveRight(n, x, y, FirstX, XCount) as (
    select 1, x , y,
      (select x from map where y = startingPoint[1] order by x limit 1) as  FirstX,
      (select count(*) from map where y = startingPoint[1]) as XCount
    from map
    where y = startingPoint[1]
      and x = startingPoint[0]
    union all
    select n+1, map.x, map.y, FirstX, XCount
    from map
      inner join moveRight
        on map.y = moveRight.y
	  /* This weird case expression is meant to deal with wrap around */
	  and map.x = case when moveRight.x + 1 = FirstX + XCount then FirstX else moveRight.x + 1 end
    where value = '.'
      and n <= duration
  )
  --update map set value = '>' from moveRight where moveRight.x = map.x and moveRight.y = map.y;
  select point(x,y)
  from moveRight
  order by n desc
  limit 1;
$moveRight$ language sql;

create function moveLeft(startingPoint point, duration integer) returns point as
$moveLeft$
  with recursive moveLeft(n, x, y, FirstX) as (
    select 1, x , y,
      (select x from map where y = startingPoint[1] order by x desc limit 1) as  FirstX
    from map
    where y = startingPoint[1]
      and x = startingPoint[0]
    union all
    select n+1, map.x, map.y, FirstX
    from map
      inner join moveLeft
        on map.y = moveLeft.y
	  /* This weird case expression is meant to deal with wrap around */
	  and map.x = case when moveLeft.x - 1 = 0 then FirstX else moveLeft.x - 1 end
    where value = '.'
      and n <= duration
  )
  --update map set value = '<' from moveLeft where moveLeft.x = map.x and moveLeft.y = map.y;
  select point(x,y)
  from moveLeft
  order by n desc
  limit 1;
$moveLeft$ language sql;

create function moveUp(startingPoint point, duration integer) returns point as
$moveUp$
  with recursive moveUp(n, x, y, FirstY) as (
    select 1, x , y,
      (select y from map where x = startingPoint[0] order by y desc limit 1) as  FirstY
    from map
    where y = startingPoint[1]
      and x = startingPoint[0]
    union all
    select n+1, map.x, map.y, FirstY
    from map
      inner join moveUp
        on map.x = moveUp.x
	  /* This weird case expression is meant to deal with wrap around */
	  and map.y = case when moveUp.y - 1 = 0 then FirstY else moveUp.y - 1 end
    where value = '.'
      and n <= duration
  )
  --update map set value = '^' from moveUp where moveUp.x = map.x and moveUp.y = map.y;
  select point(x,y)
  from moveUp
  order by n desc
  limit 1;
$moveUp$ language sql;

create function moveDown(startingPoint point, duration integer) returns point as
$moveDown$
  with recursive moveDown(n, x, y, FirstY, YCount) as (
    select 1, x , y,
      (select y from map where x = startingPoint[0] order by y limit 1) as  FirstY,
      (select count(*) from map where x = startingPoint[0]) as YCount
    from map
    where y = startingPoint[1]
      and x = startingPoint[0]
    union all
    select n+1, map.x, map.y, FirstY, YCount
    from map
      inner join moveDown
        on map.x = moveDown.x
	  /* This weird case expression is meant to deal with wrap around */
	  and map.y = case when moveDown.y + 1 = FirstY + YCount then FirstY else moveDown.y + 1 end
    where value = '.'
      and n <= duration
  )
  --update map set value = 'v' from moveDown where moveDown.x = map.x and moveDown.y = map.y;
  select point(x,y)
  from moveDown
  order by n desc
  limit 1;
$moveDown$ language sql;

with recursive instr1(d) as (
  /* get the duration instructions */
  select array_agg(durations.d[1]::integer)
  from (select data from input where not map and data <> '') as input(data),
    lateral (select regexp_matches(data, '\d+', 'g')) as durations(d)
),
instr2(d) as (
  /* get the turns instructions */
  select array_agg(directions.d[1])
  from (select data from input where not map and data <> '') as input(data),
    lateral (select regexp_matches(data, '[RL]', 'g')) as directions(d)
),
startingPoint(p) as (
  /* Get the starting point */
  select point(x, y)
  from map
  where y = 1
    and value = '.'
  order by x
  limit 1
),
findRoute(n, endingPoint, nextDirection, facingValue) as (
  select 1 as n,
    moveRight(startingPoint.p, instr1.d[1]) as endingPoint,
    nextDir as nextDirection,
    value as facingValue
  from instr1,
    /* cartesian product with a one-row table */
    instr2,
    /* cartesian product with a one-row table */
    startingPoint
    inner join directions
      on currentDir = 'right'
  where turn =  instr2.d[1]

  union all

  select n+1,
    case when nextDirection = 'right' then
      moveRight(endingPoint, instr1.d[n+1])
         when nextDirection = 'left' then
      moveLeft(endingPoint, instr1.d[n+1])
         when nextDirection = 'up' then
      moveUp(endingPoint, instr1.d[n+1])
         when nextDirection = 'down' then
      moveDown(endingPoint, instr1.d[n+1])
    end as endingPoint,
      coalesce(nextDir, nextDirection) as nextDirection,
      coalesce(value, facingValue)
  from instr1,
    /* cartesian product with a one-row table */
    instr2,
    /* cartesian product with a one-row table */
    findRoute
    inner join directions
      on currentDir = nextDirection
  /* we need to stop one round after the first null in instr2 */
  where turn =  coalesce(instr2.d[n+1], instr2.d[n])
)
/* calculation of the password: 8 times the row of the ending point plus
 * 4 times the column of the ending point plus
 * faceingValue */
select 1000 * endingPoint[1] + 4 * endingPoint[0] + facingValue as FirstStar
from findRoute
order by n desc
limit 1
;

--3326 too low
