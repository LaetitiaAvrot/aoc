/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on
\set lineNumber 2000000

/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity not null,
  value text,
  sensor point generated always as (
    point((split_part(regexp_replace(value,'Sensor at x=',''),',',1))::integer,
      (split_part(regexp_replace(value,'Sensor at x=-?\d+, y=',''),':',1))::integer))
    stored,
  beacon point generated always as (
    point((split_part(regexp_replace(value,'Sensor at x=-?\d+, y=-?\d+: closest beacon is at x=',''),',',1))::integer,
      (split_part(regexp_replace(value,'Sensor at x=-?\d+, y=-?\d+: closest beacon is at x=-?\d+, y=',''),':',1))::integer))
    stored,
  SBDistance integer,
  isusefull boolean
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

drop function if exists manhattanDistance;
create function manhattanDistance(p1 point, p2 point) returns integer as
$manhattanDistance$
  select abs(p1[0]-p2[0]) + abs(p1[1]-p2[1]) as result;
$manhattanDistance$ language sql;

/* Add some useful data for later */
update input
set SBDistance = manhattanDistance(sensor,beacon);
/* All the sensors not within SBDistance of the :lineNumberth line are useless */
update input
set isUsefull = int4range((sensor[1]-SBDistance)::integer, (sensor[1]+SBDistance)::integer,'[]') @> :lineNumber;

/* Let's create a table to store where the beacon is not  */
drop table if exists map;
create table map (
  x integer not null,
  y integer not null,
  p point not null generated always as (point(x,y)) stored,
  value char(1)
);

/* Creating the line */
with xx(minx, maxx) as (
  select min(sensor[0]-SBDistance),
    max(sensor[0]+SBDistance)
  from input
  where isusefull
)
insert into map(x,y,value) (
  select n, :lineNumber, '.'
  from xx,
    generate_series(minx::integer,maxx::integer) t(n)
);

/* Adding the sensors and beacons */
update map set value= 'S'
from input
where isUsefull
  and sensor ~= p ;
update map set value= 'B'
from input
where isUsefull
  and beacon ~= p ;

/* For each sensor, let's mark on the map where the beacon can't be */
update map set value='#'
from input
where manhattanDistance(sensor,p) <= SBDistance
  and map.value = '.'
  and isusefull;

select count(*) as partOne
from map
where value = '#'
  and y = :lineNumber;

/* Let's recreate the restricted map */
truncate map;
insert into map(x,y,value) (
  select x, y, '.'
  from generate_series(0,4000000) x(x),
    /* Legitimate use of cartesian product */
    generate_series(0,4000000) y(y)
);

/* Adding the sensors and beacons */
update map set value= 'S'
from input
where sensor ~= p ;
update map set value= 'B'
from input
where beacon ~= p ;

/* For each sensor, let's mark on the map where the beacon can't be */
update map set value='#'
from input
where manhattanDistance(sensor,p) <= SBDistance
  and map.value = '.';

select x, y, x*4000000 + y as PartTwo
from map
where x between 0 and 4000000
  and y between 0 and 4000000
  and value = '.';
