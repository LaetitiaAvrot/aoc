/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc cascade;
create schema aoc;
set search_path to 'aoc';

/* Insert data into  table */
create table input (
  id integer generated always as identity primary key,
  value text,
  valve text generated always as (substring(value from 7 for 2)) stored,
  nextValves text[] generated always as (
    string_to_array(
      regexp_replace(
	value,
	'Valve [A-Z]{2} has flow rate=\d+; tunnels? leads? to valves? ',
	''
      ),
      ', '
    )
  ) stored,
  pressure integer generated always as
    (substring(value from 24 for (position(';' in value)-24))::integer) stored
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

create function shortestPath(A text, B text) returns text[] as
$shortestPath$
  with recursive paths(n,p, stop) as (
    ( select 1, array[B] , false
      from input
      where B = any(input.nextvalves))
    union all
    ( select n+1,
        valve || p,
        valve = A
      from paths
        inner join input next
          on paths.p[1] = any(next.nextValves)
      where n < 30 /* Doing more than 30 jumps is useless as we have only 30 minutes */
        and not stop
        /* Preventing cycling */
        and valve <> all(p))
  )
  select p
  from paths
  where stop
  order by cardinality(p)
  limit 1;
$shortestPath$ language sql;

/* Let's create a table to store all the possible paths */
create table shortestPath (
  startv text not null,
  endv text not null,
  shortestPath text[] not null,
  jumps integer generated always as (cardinality(shortestPath)-1) stored,
  pressure integer,
  primary key (startv, endv)
);
comment on column shortestPath.pressure is $$pressure released by the end valve once it is open$$;

insert into shortestPath(startv, endv, shortestPath, pressure)
(
  select startv.valve,
    endv.valve,
    shortestPath(startv.valve, endv.valve),
    endv.pressure
  from input startv
    inner join input endv
    on startv.id <> endv.id
  /* We don't want to lose time with broken valves */
  where endv.pressure > 0
);

/* Let's generate all paths we can do in 30 minutes */
with recursive allPaths(iteration, p, minutes, pressureReleased, pressurePerMin, newValvePressure) as (
  select 1, array['AA'], 0, 0, 0, 0
  union all
  select iteration + 1,
    p || endv,
    /* Previous time + time to go there + time to open the valve */
    minutes + jumps + 1,
    /* How much pressure did we already realeased ?
     * It's the ipressure already released + previous pressure per min
     * multiplied by the sum of the time we * need to travel to the valve and 
     * the time to open the new valve */
    pressureReleased + (pressurePerMin + newValvePressure) * (jumps + 1),
    /* How much pressure did we release each minute */
   (pressurePerMin + newValvePressure),
    pressure
  from shortestPath
  inner join allPaths
    on shortestPath.startv = p[cardinality(p)]
    /* We will try not to waste time trying to open an already open valve */
    and shortestPath.endv <> all(p)
  /* Remember we only have 30 minutes */
  where minutes + jumps < 30
)
select
  /* We need to add the extra minutes */
  case when minutes < 30
    then pressurereleased + (30-minutes)*(pressurepermin+newValvePressure)
    else pressurereleased
  end as PartOne
from allPaths
order by case when minutes < 30
    then pressurereleased + (30-minutes)*pressurepermin
    else pressurereleased
  end desc
limit 1
;

/* 2762 is too low */

/* Let's generate all paths we can do in 30 minutes while taking 4 minutes to
 * teach an elephant how to open a valve */
with recursive allPaths(iteration, p, minutesMe, minutesElephant,
  pressureReleasedMe, pressureReleasedElephant,
  pressurePerMinMe, pressurePerMinElephant, newValvePressureMe, newValvePressureElephant) as (
  select 1, array['AA','AA'], 0, 0, 0, 0, 0, 0, 0, 0
  union all
  select iteration + 1,
    (p || me.endv) || elephant.endv,
    /* Previous time + time to go there + time to open the valve */
    minutesMe + me.jumps + 1,
    minutesElephant + elephant.jumps + 1,
    /* How much pressure did we already realeased ?
     * It's the ipressure already released + previous pressure per min
     * multiplied by the sum of the time we * need to travel to the valve and 
     * the time to open the new valve */
    pressureReleasedMe + (pressurePerMinMe + newValvePressureMe) * (me.jumps + 1),
    pressureReleasedElephant + (pressurePerMinElephant + newValvePressureElephant) * (elephant.jumps + 1),
    /* How much pressure did we release each minute */
    pressurePerMinMe + newValvePressureMe,
    pressurePerMinElephant + newValvePressureElephant,
    me.pressure,
    elephant.pressure
  from shortestPath as me
  inner join shortestPath as elephant
  on me.endv <> elephant.endv
  inner join allPaths
    on me.startv = p[cardinality(p)-1]
    /* We will try not to waste time trying to open an already open valve */
    and me.endv <> all(p)
    and elephant.startv = p[cardinality(p)]
    /* We will try not to waste time trying to open an already open valve */
    and elephant.endv <> all(p)
  /* Remember we only have 30 minutes */
  where minutesMe + me.jumps < 30 - 4
    and minutesElephant + elephant.jumps < 30 - 4
)
select
  /* We need to add the extra minutes */
  case when minutesMe < 30 - 4
    then case when minutesElephant < 26 - 4 
      then
        pressurereleasedMe + (30-4-minutesMe)*(pressureperminMe+newValvePressureMe) +
        pressurereleasedElephant + (30-4-minutesElephant)*(pressureperminElephant+newValvePressureElephant)
      else pressurereleasedMe + (30-4-minutesMe)*(pressureperminMe+newValvePressureMe) +
	pressurereleasedElephant
      end
    else  case when minutesElephant < 26 - 4
     then pressurereleasedMe +
        pressurereleasedElephant + (30-4-minutesElephant)*(pressureperminElephant+newValvePressureElephant)
      else pressurereleasedMe + pressurereleasedElephant
      end
  end as PartTwo
from allPaths
order by 
  case when minutesMe < 30 - 4
    then case when minutesElephant < 26 - 4 
      then
        pressurereleasedMe + (30-4-minutesMe)*(pressureperminMe+newValvePressureMe) +
        pressurereleasedElephant + (30-4-minutesElephant)*(pressureperminElephant+newValvePressureElephant)
      else pressurereleasedMe + (30-4-minutesMe)*(pressureperminMe+newValvePressureMe) +
	pressurereleasedElephant
      end
    else  case when minutesElephant < 26 - 4
     then pressurereleasedMe +
        pressurereleasedElephant + (30-4-minutesElephant)*(pressureperminElephant+newValvePressureElephant)
      else pressurereleasedMe + pressurereleasedElephant
      end
  end desc
limit 1
;

