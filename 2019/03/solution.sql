/* Insert data into temporary table */
/* The generated column is not mandatory, but I wanted to test that new Postgres
 * feature. */
create temporary table input1
  (id integer generated always as identity,
  value text);

create temporary table input2
  (id integer generated always as identity,
  value text);

/* Please use psql, the best PostgreSQL client */
\copy input1(value) from 'input1.csv';
\copy input2(value) from 'input2.csv';

/* We'll use special geometric types from postgres: points and segments, so that
 * in the end, we just need to find segments intersections. */
/* So first, we need to create a table of points with origin and destination for
 * each instruction. The first point is 0,0 (Central Port). */
create temporary table instructions(id, cableId, direction, howLong, origin, destination) as
(
  select id,
    1,
    substring(value from 1 for 1),
    substring(value from 2)::integer,
    null::point,
    null::point
  from input1
  union all
  select id,
    2,
    substring(value from 1 for 1),
    substring(value from 2)::integer,
    null::point,
    null::point
  from input2
);

/* Setting the first origin */
update instructions set origin=point(0,0) where id=1;

/* Loop to calculate all origins and destinations */
with recursive calculation(origin, dest, cableId, id) as
(
  select
    origin,
    case when direction='R' then origin+point(howLong,0)
      when direction='L' then origin-point(howLong,0)
      when direction='U' then origin+point(0,howLong)
      when direction='D' then origin-point(0,howLong)
    end as dest,
    cableId,
    id
  from instructions
  where id = 1
  union all
  select
    calculation.dest as origin,
    case when direction='R' then calculation.dest+point(howLong,0)
      when direction='L' then calculation.dest-point(howLong,0)
      when direction='U' then calculation.dest+point(0,howLong)
      when direction='D' then calculation.dest-point(0,howLong)
    end as dest,
    calculation.cableId,
    calculation.id+1
  from instructions
    join calculation
      on instructions.id=calculation.id+1
      and instructions.cableId=calculation.cableId
)
update instructions
set origin=calculation.origin,
  destination=calculation.dest
from calculation
where instructions.id=calculation.id
  and instructions.cableId=calculation.cableId;

/* We need to create the segments now that we have the origin and destination
 * points. */
alter table instructions
  add column seg lseg generated always as (lseg(origin,destination)) stored;

--select * from instructions where origin is not null order by cableid, id;


/* Let's calculate the Manhattan distnace from central port for the intersection
 * points. We will remove the central port itself, to get the correct result.*/
with cable1 as
(
  select *
  from instructions
  where cableid=1
),
cable2 as
(
  select *
  from instructions
  where cableid=2
)
select abs((cable1.seg # cable2.seg)[0])+abs((cable1.seg # cable2.seg)[1]) as part1
from cable1
  inner join cable2
    on cable1.seg ?# cable2.seg
where (cable1.seg # cable2.seg) <> point(0,0)
order by part1
limit 1;

/* Calculation for part2 seems obvious now */
with cable1 as
(
  select id,
    seg,
    origin,
    howlong,
    sum(howlong) over (order by id) as steps
  from instructions
  where cableid=1
),
cable2 as
(
  select id,
    seg,
    origin,
    howlong,
    sum(howlong) over (order by id) as steps
  from instructions
  where cableid=2
)
select
  cable1.steps - cable1.howlong + (cable1.origin <-> (cable1.seg # cable2.seg)) +
  cable2.steps - cable2.howlong + (cable2.origin <-> (cable1.seg # cable2.seg)) as part2
from cable1
  inner join cable2
    on cable1.seg ?# cable2.seg
where (cable1.seg # cable2.seg) <> point(0,0)
order by part2
limit 1;

/* Deleting everything afterwards */
/* Not really necessary as temporary objects are dropped at the end of the
 * session, but I'd rather drop my temporary objects explicitely.
 * On the "+" side, this make this script idempotent. */
drop table instructions;
drop table input1;
drop table input2;
