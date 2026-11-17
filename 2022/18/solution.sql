/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc cascade;
create schema aoc;
set search_path to 'aoc';

/* Insert data into  table */
create table input (
  id integer generated always as identity primary key,
  x integer,
  y integer,
  z integer,
  sides integer
);

/* Please use psql, the best PostgreSQL client */
\copy input(x,y,z) from 'input.csv' with delimiter ',';

/* Let's start with 6 visible sides for each cube */
update input set sides = 6;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on x axis ? */
  select i1.x, i1.y, i1.z
  from input i1
    inner join input i2
      on i1.x = i2.x + 1
      and i1.y = i2.y
      and i1.z = i2.z
)
/* If yes, we decrease the number of sizes */
update input set sides = sides - 1
from adjacent
where input.x = adjacent.x1
  and input.y = adjacent.y1
  and input.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on x axis ? */
  select i1.x, i1.y, i1.z
  from input i1
    inner join input i2
      on i1.x = i2.x - 1
      and i1.y = i2.y
      and i1.z = i2.z
)
/* If yes, we decrease the number of sizes */
update input set sides = sides - 1
from adjacent
where input.x = adjacent.x1
  and input.y = adjacent.y1
  and input.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on y axis ? */
  select i1.x, i1.y, i1.z, i2.x, i2.y, i2.z
  from input i1
    inner join input i2
      on i1.x = i2.x
      and i1.y = i2.y + 1
      and i1.z = i2.z
)
/* If yes, we decrease the number of sizes */
update input set sides = sides - 1
from adjacent
where input.x = adjacent.x1
  and input.y = adjacent.y1
  and input.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on y axis ? */
  select i1.x, i1.y, i1.z
  from input i1
    inner join input i2
      on i1.x = i2.x
      and i1.y = i2.y - 1
      and i1.z = i2.z
)
/* If yes, we decrease the number of sizes */
update input set sides = sides - 1
from adjacent
where input.x = adjacent.x1
  and input.y = adjacent.y1
  and input.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on z axis ? */
  select i1.x, i1.y, i1.z
  from input i1
    inner join input i2
      on i1.x = i2.x
      and i1.y = i2.y
      and i1.z = i2.z + 1
)
/* If yes, we decrease the number of sizes */
update input set sides = sides - 1
from adjacent
where input.x = adjacent.x1
  and input.y = adjacent.y1
  and input.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on z axis ? */
  select i1.x, i1.y, i1.z
  from input i1
    inner join input i2
      on i1.x = i2.x
      and i1.y = i2.y
      and i1.z = i2.z - 1
)
/* If yes, we decrease the number of sizes */
update input set sides = sides - 1
from adjacent
where input.x = adjacent.x1
  and input.y = adjacent.y1
  and input.z = adjacent.z1
;

select sum(sides) as PartOne
from input;

/* Let's find the inside cubes of air */
create table insideCubes (id integer generated always as identity,
  x integer,
  y integer,
  z integer,
  sides integer);

/* On x axis */
with boundsx(minx, maxx, z, y) as (
  select min(x), max(x), z, y
  from input
  group by z, y
),
boundsy(miny, maxy, z, x) as (
  select min(y), max(y), z, x
  from input
  group by z, x
),
boundsz(minz, maxz, y, x) as (
  select min(z), max(z), y, x
  from input
  group by y, x
),
bounds(minx,maxx,miny,maxy, minz, maxz) as (
  select min(x), max(x), min(y), max(y), min(z), max(z)
  from input
),
airCubes(x,y,z) as (
  (
    select x, y, z
    from boundsx,
      generate_series(minx,maxx) as t(x)
    union
    select x, y, z
    from boundsy,
      generate_series(miny,maxy) as t(y)
    union
    select x, y, z
    from boundsz,
      generate_series(minz,maxz) as t(z)
  )
  except
  select x,y,z
  from input)
insert into insideCubes (x,y,z) (
  select x,y,z
  from bounds
    inner join airCubes
      on x > minx
      and x < maxx
      and y > miny
      and y < maxy
      and z > minz
      and z < maxz
);

/* Let's begin with 6 sides for each cube */
update insideCubes set sides = 6;

/* Let's do the same adjacent dance we did on Part One for the inside cubes */
with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on x axis ? */
  select i1.x, i1.y, i1.z
  from insideCubes i1
    inner join insideCubes i2
      on i1.x = i2.x + 1
      and i1.y = i2.y
      and i1.z = i2.z
)
/* If yes, we decrease the number of sizes */
update insideCubes set sides = sides - 1
from adjacent
where insideCubes.x = adjacent.x1
  and insideCubes.y = adjacent.y1
  and insideCubes.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on x axis ? */
  select i1.x, i1.y, i1.z
  from insideCubes i1
    inner join insideCubes i2
      on i1.x = i2.x - 1
      and i1.y = i2.y
      and i1.z = i2.z
)
/* If yes, we decrease the number of sizes */
update insideCubes set sides = sides - 1
from adjacent
where insideCubes.x = adjacent.x1
  and insideCubes.y = adjacent.y1
  and insideCubes.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on y axis ? */
  select i1.x, i1.y, i1.z, i2.x, i2.y, i2.z
  from insideCubes i1
    inner join insideCubes i2
      on i1.x = i2.x
      and i1.y = i2.y + 1
      and i1.z = i2.z
)
/* If yes, we decrease the number of sizes */
update insideCubes set sides = sides - 1
from adjacent
where insideCubes.x = adjacent.x1
  and insideCubes.y = adjacent.y1
  and insideCubes.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on y axis ? */
  select i1.x, i1.y, i1.z
  from insideCubes i1
    inner join insideCubes i2
      on i1.x = i2.x
      and i1.y = i2.y - 1
      and i1.z = i2.z
)
/* If yes, we decrease the number of sizes */
update insideCubes set sides = sides - 1
from adjacent
where insideCubes.x = adjacent.x1
  and insideCubes.y = adjacent.y1
  and insideCubes.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on z axis ? */
  select i1.x, i1.y, i1.z
  from insideCubes i1
    inner join insideCubes i2
      on i1.x = i2.x
      and i1.y = i2.y
      and i1.z = i2.z + 1
)
/* If yes, we decrease the number of sizes */
update insideCubes set sides = sides - 1
from adjacent
where insideCubes.x = adjacent.x1
  and insideCubes.y = adjacent.y1
  and insideCubes.z = adjacent.z1
;

with adjacent(x1,y1,z1) as (
  /* Is there a cube adjacent on z axis ? */
  select i1.x, i1.y, i1.z
  from insideCubes i1
    inner join insideCubes i2
      on i1.x = i2.x
      and i1.y = i2.y
      and i1.z = i2.z - 1
)
/* If yes, we decrease the number of sizes */
update insideCubes set sides = sides - 1
from adjacent
where insideCubes.x = adjacent.x1
  and insideCubes.y = adjacent.y1
  and insideCubes.z = adjacent.z1
;

/* Let's finaly get the result */
with sidesLava(num) as (
  select sum(sides)
  from input),
sidesAir(num) as (
  select sum(sides)
  from insideCubes)
select sidesLava.num - sidesAir.num
from sidesLava,
  /* Cartesian product with a one row table */
  sidesAir;

-- 1444 is too low
