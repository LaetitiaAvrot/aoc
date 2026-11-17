/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc cascade;
create schema aoc;
set search_path to 'aoc';

/* Insert data into  table */
create table input (
  id integer generated always as identity primary key,
  data text not null
);

\copy input(data) from 'input.csv';

/* let's create the map */
create table map (
  x integer not null,
  y integer not null,
  value char(1),
  primary key (x,y)
);

create index on map(x,y) where value = '#';

create view debug as (
  select y, string_agg(value, '')
  from (
    select *
    from map
    order by y,x)
  group by y);

/* As we only look after 10 rounds, we just need 2*100 more x and y (assuming one
 * elf will find it funny to only move in diagonal */
with myRows(y, data) as (
  select id+100 as y, array_agg(c[1])
  from input,
    lateral (select regexp_matches(data, '.', 'g')) chars(c)
  group by id
)
insert into map (x, y, value) (
  select 100+x, y, data[x]
  from myRows,
    /* On purpose cartesian product as we want to generate a grid */
    generate_series(1, cardinality(data)) as t(x)
)
;

create procedure addingEmptyRows() as
$addingEmptyRows$
  /* adding the empty row and column around the elves */
  with extremes (xmin, xmax, ymin, ymax) as (
    select min(x), max(x), min(y), max(y)
    from map
    where value ='#'
  ),
  deletion as (
    /* First remove unnecessary rows and columns */
    delete from map using extremes
    where x<extremes.xmin or x>extremes.xmax or y<extremes.ymin or y>extremes.ymax
    returning x, y, value
  ),
  insertion as (
    insert into map (x, y, value) (
      select x, y ,'.'
      from generate_series((select xmin-1 from extremes), (select xmax+1 from extremes)) as t1(x),
        generate_series((select ymin-1 from extremes), (select ymax+1 from extremes)) as t2(y)
    )
    /* Preventing conflicts */
    on conflict do nothing
    returning x, y, value
  )
  select * from deletion union all select * from insertion;
$addingEmptyRows$ language sql;

create table directions (
  ordering integer,
  direction char(1)
);
insert into directions (ordering, direction) values (1,'N'),(2,'S'),(3,'W'),(4,'E');

/* Rotate ordering of the directions */
create procedure rotateDirectionsOrdering() as
$rotateDirectionsOrdering$
  update directions
  set ordering = (select max(ordering) + 1 from directions)
  where ordering = (select min(ordering) from directions);
$rotateDirectionsOrdering$ language sql;

/* Calculate the move of each elve (if they move) */
create function getDecision(p point) returns point[] as
$getDecision$
  with lookaround(north, south, west, east) as (
    select string_agg(value, '')
        filter(where map.x between p[0]-1 and p[0]+1
         	and map.y = p[1]-1) as North,
      string_agg(value, '')
        filter(where map.x between p[0]-1 and p[0]+1
         	and map.y = p[1]+1) as South,
      string_agg(value, '')
        filter(where map.x = p[0]-1
          and map.y between p[1]-1 and p[1]+1) as West,
      string_agg(value, '')
        filter(where map.x = p[0]+1
          and map.y between p[1]-1 and p[1]+1) as East
    from map
  ),
  decisions(d) as (
    select
        case
          /* If there is no Elf around, the Elf does not move */
          when not regexp_like(North || South || West || East, '#') then p
         /* If there is no Elf in the N, NE, or NW adjacent positions, the Elf
         * proposes moving north one step. */
          when direction = 'N'  and not regexp_like(North, '#') then p-point(0,1)
         /* If there is no Elf in the S, SE, or SW adjacent positions, the Elf
         * proposes moving south one step. */
          when direction = 'S' and not regexp_like(South, '#') then p+point(0,1)
         /* If there is no Elf in the W, NW, or SW adjacent positions, the Elf
         * proposes moving west one step. */
          when direction = 'W' and not regexp_like(West, '#') then p-point(1,0)
         /* If there is no Elf in the E, NE, or SE adjacent positions, the Elf
         * proposes moving east one step. */
          when direction = 'E' and not regexp_like(East, '#') then p+point(1,0)
        end as nextPosition
    from lookaround,
      /* cartesian prodyct with a one-row table */
      directions
    /* the ordering is used to have the decisions in order */
    order by ordering
  )
  select array_agg(d)
  from decisions
  ;
$getDecision$ language sql;

create procedure moveElves() as
$moveElves$
  with decisions(x, y, d) as (
    select x, y, getDecision(point(x,y))
    from map
    where value = '#'
  ),
  decision(x, y, d) as (
    select x, y,
      /* Take the first not null decision */
      /* If an elf can't move at all, I'll assume it will simply stay where it is */
      coalesce(d[1], d[2], d[3], d[4], point(x,y))
    from decisions
  ),
  properMoves(x, y) as (
  select d[0], d[1]
  from decision
  group by d[0], d[1]
  having count(d) < 2
  ),
  movingElves (starting, ending) as (
    select point(decision.x, decision.y), d
    from decision
      inner join properMoves
        on properMoves.x = decision.d[0]
          and properMoves.y = decision.d[1]
    /* Let's consider only the elves actually moving */
    where decision.x <> d[0]
      or decision.y <> d[1]
  ),
  deleteOldPositions(x, y, value) as (
    update map
    set value = '.'
    from movingElves
    where map.x = movingElves.starting[0]
      and map.y = movingElves.starting[1]
    returning x, y, value
  ),
  InsertNewPositions(x, y, value) as (
    update map
    set value = '#'
    from movingElves
    where map.x = movingElves.ending[0]
      and map.y = movingElves.ending[1]
    returning x, y, value
  )
  select (select count(*) from deleteOldPositions) + (select count(*) from insertNewPositions) ;
$moveElves$ language sql;

select $$call addingEmptyRows(); call moveElves();call rotateDirectionsOrdering();$$
from generate_series(1,10)
\gexec

/* Remove the extra rows and columns */
with extremes (xmin, xmax, ymin, ymax) as (
  select min(x), max(x), min(y), max(y)
  from map
  where value ='#'
)
/* Remove unnecessary rows and columns */
delete from map using extremes
where x<extremes.xmin or x>extremes.xmax or y<extremes.ymin or y>extremes.ymax
;

select count(*) as firstStar
from map
where value ='.';

/* Let's store the number of rounds */
create table rounds(
  num integer primary key
);
insert into rounds(num) values (10);

/* keep going for second star */
create function numberOfMovingElves() returns integer as
$numberOfMovingElves$
  with decisions(x, y, d) as (
    select x, y, getDecision(point(x,y))
    from map
    where value = '#'
  ),
  decision(x, y, d) as (
    select x, y,
      /* Take the first not null decision */
      /* If an elf can't move at all, I'll assume it will simply stay where it is */
      coalesce(d[1], d[2], d[3], d[4], point(x,y))
    from decisions
  ),
  properMoves(x, y) as (
  select d[0], d[1]
  from decision
  group by d[0], d[1]
  having count(d) < 2
  ),
  movingElves (starting, ending) as (
    select point(decision.x, decision.y), d
    from decision
      inner join properMoves
        on properMoves.x = decision.d[0]
          and properMoves.y = decision.d[1]
    /* Let's consider only the elves actually moving */
    where decision.x <> d[0]
      or decision.y <> d[1]
  )
  select count(*)
  from movingElves;
$numberOfMovingElves$ language sql;

select
    $$update rounds set num = $$ || num || $$ where (select numberOfMovingElves()) > 0;$$ ||
    $$call addingEmptyRows();$$ ||
    $$call moveElves();$$ ||
    $$call rotateDirectionsOrdering();$$
/* that's not smart and slow, but it should work eventually */
from generate_series(11,2000) t(num)
\gexec

select num as SecondStar
from rounds;

-- got 1002 which is too low
