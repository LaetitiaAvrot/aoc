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
  blueprintId integer generated always as (
    (
      (regexp_split_to_array(
	(regexp_split_to_array(
	    data,
	    'Blueprint '
          )
        )[2],
	':')
      )[1]
    )::integer
  ) stored unique not null
);

/* Please use psql, the best PostgreSQL client */
\copy input(data) from 'input.csv' with delimiter ',';

create table costs (
  bluePrintId integer not null references input(blueprintId),
  Robottype text not null,
  ore integer not null,
  clay integer not null,
  obsidian integer not null,
  primary key (bluePrintId, Robottype)
);

/* Let's sort all this out */
insert into costs(bluePrintId, robotType, ore, clay, obsidian)
(
  select bluePrintId,
    'ore robot',
    ((regexp_split_to_array(
        (regexp_split_to_array(
          data, 'Each ore robot costs ')
        )[2],
        ' ore.'
      )
    )[1])::integer,
    0,
    0
  from input
);
insert into costs(bluePrintId, robotType, ore, clay, obsidian)
(
  select bluePrintId,
    'clay robot',
    ((regexp_split_to_array(
        (regexp_split_to_array(
          data, 'Each clay robot costs ')
        )[2],
        ' ore.'
      )
    )[1])::integer,
    0,
    0
  from input
);
insert into costs(bluePrintId, robotType, ore, clay, obsidian)
(
  select bluePrintId,
    'obsidian robot',
    ((regexp_split_to_array(
        (regexp_split_to_array(
          data, 'Each obsidian robot costs ')
        )[2],
        ' ore'
      )
    )[1])::integer,
    ((regexp_split_to_array(
        (regexp_split_to_array(
          data, 'Each obsidian robot costs \d+ ore and ')
        )[2],
        ' clay.'
      )
    )[1])::integer,
    0
  from input
);
insert into costs(bluePrintId, robotType, ore, clay, obsidian)
(
  select bluePrintId,
    'geode robot',
    ((regexp_split_to_array(
        (regexp_split_to_array(
          data, 'Each geode robot costs ')
        )[2],
        ' ore'
      )
    )[1])::integer,
    0,
    ((regexp_split_to_array(
        (regexp_split_to_array(
          data, 'Each geode robot costs \d+ ore and ')
        )[2],
        ' obsidian.'
      )
    )[1])::integer
  from input
);

create table production(
  id integer generated always as identity,
  minute integer,
  bluePrintId integer references input(bluePrintId),
  oreRobot integer not null,
  clayRobot integer not null,
  obsidianRobot integer not null,
  geodeRobot integer not null,
  ore integer not null,
  clay integer not null,
  obsidian integer not null,
  geode integer not null
);

create index on production (minute, bluePrintId);

/* Let's initiate the thing */
insert into production(minute, bluePrintId, oreRobot, clayRobot, obsidianRobot,
  geodeRobot, ore, clay, obsidian, geode)
(
  select 0, /* THis is the state at minute 0 */
    bluePrintId,
    1, /* We have exactly one ore-collecting robot in our pack*/
    0, /* clay robot */
    0, /* osbidian robot */
    0, /* geode robot */
    0, /* ore */
    0, /* clay */
    0, /* obsidian */
    0  /* geode */
  from input
);

--create function saveForObsidian(thisBluePrintId integer) returns boolean as
--$saveForObsidian$
--  with costs(ore, clay) as (
--    select ore,
--      clay
--    from costs
--    where blueprintid = thisBluePrintId
--      and robotType = 'obsidian robot'
--  )
--  select
--    /* will we be able to create an obsidian robot next turn if we don't build
--     * a clay robot this turn? */
--    (production.clay + production.clayrobot >= costs.clay
--    and production.ore + production.orerobot >= costs.ore)
--    or
--    /* Will we be able to create an obsidian robot in 2 turns if we don't build
--     * a clay robot this and the next turn? */
--    (production.clay + production.clayrobot + production.clayrobot >= costs.clay
--    and production.ore + production.orerobot + production.orerobot >= costs.ore)
--  from production,
--   /* Cartesain product with a one row table */
--    costs
--  where blueprintid = thisBluePrintId
--  order by minute desc
--  limit 1
--$saveForObsidian$ language sql;
--
--create function saveForGeode(thisBluePrintId integer) returns boolean as
--$saveForGeode$
--  with costs(ore, obsidian) as (
--    select ore,
--      obsidian
--    from costs
--    where blueprintid = thisBluePrintId
--      and robotType = 'geode robot'
--  )
--  select
--    /* will we be able to create a geode robot next turn if we don't build
--     * an obsidian robot this turn? */
--    (production.obsidian + production.obsidianrobot >= costs.obsidian
--    and production.ore + production.orerobot >= costs.ore)
--    or
--    /* Will we be able to create a geode robot in 2 turns if we don't build
--     * an obsidian robot this and the next turn? */
--    (production.obsidian + production.obsidianrobot + production.obsidianrobot >= costs.obsidian
--    and production.ore + production.orerobot + production.orerobot >= costs.ore)
--  from production,
--   /* Cartesain product with a one row table */
--    costs
--  where blueprintid = thisBluePrintId
--  order by minute desc
--  limit 1
--$saveForGeode$ language sql;

/* ouput  parameter:
 * an array of robot built (only one) and resources used
 * oreRobot, clayRobot, ObsidianRobot, GeodeRobot, ore, clay, obsidian */
create function whichRobot(thisBluePrintId integer, thisMinute integer) returns integer[] as
$whichRobot$
  select
    case
      /* If we can create a geode Robot, we create it */
      when production.ore >= geodeCosts.ore
	and production.obsidian >= geodeCosts.obsidian
      then array[0,0,0,1,geodeCosts.ore,0,geodeCosts.obsidian]
      /* If we can create an obsidianRobot and that it does not prevent creating
       * a geode Robot in the next 4 minutes */
      when production.ore >= obsidianCosts.ore
	and production.clay >= obsidianCosts.clay
	and not (
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot next minute */
          (production.ore + oreRobot - obsidianCosts.ore >= geodeCosts.ore
	  and production.obsidian + obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot in the next 2 minutes */
          (production.ore + 2*oreRobot - obsidianCosts.ore >= geodeCosts.ore
	  and production.obsidian + 2*obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot in the next 3 minutes */
          (production.ore + 3*oreRobot - obsidianCosts.ore >= geodeCosts.ore
	  and production.obsidian + 3*obsidianRobot >= geodeCosts.obsidian)
	  --or
	  --/* We don't want to take too much ore that would prevent creating
	  -- * a geodeRobot in the next 4 minutes */
          --(production.ore + 4*oreRobot - obsidianCosts.ore >= geodeCosts.ore
	  --and production.obsidian + 4*obsidianRobot >= geodeCosts.obsidian)
        )
      then array[0,0,1,0,obsidianCosts.ore,obsidianCosts.clay,0]
      /* If we can create a clay Robot and that it does not prevent creating
       * a geode Robot in the next 4 minutes */
      when production.ore >= clayCosts.ore
	and not (
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot next minute */
          (production.ore + oreRobot - clayCosts.ore >= geodeCosts.ore
	  and production.obsidian + obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot in the next 2 minutes */
          (production.ore + 2*oreRobot - clayCosts.ore >= geodeCosts.ore
	  and production.obsidian + 2*obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot in the next 3 minutes */
          (production.ore + 3*oreRobot - clayCosts.ore >= geodeCosts.ore
	  and production.obsidian + 3*obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot in the next 4 minutes */
          (production.ore + 4*oreRobot - clayCosts.ore >= geodeCosts.ore
	  and production.obsidian + 4*obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * an obsidianRobot next minute */
          (production.ore + oreRobot - clayCosts.ore >= obsidianCosts.ore
	  and production.clay + clayRobot >= obsidianCosts.clay)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * an obsidianRobot in the next 2 minutes */
          (production.ore + 2*oreRobot - clayCosts.ore >= obsidianCosts.ore
	  and production.clay + 2*clayRobot >= obsidianCosts.clay)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * an obsidianRobot in the next 3 minutes */
          (production.ore + 3*oreRobot - clayCosts.ore >= obsidianCosts.ore
	  and production.clay + 3*clayRobot >= obsidianCosts.clay)
	  --or
	  --/* We don't want to take too much ore that would prevent creating
	  -- * an obsidianRobot in the next 4 minutes */
          --(production.ore + 4*oreRobot - clayCosts.ore >= obsidianCosts.ore
	  --and production.clay + 4*clayRobot >= obsidianCosts.clay)
        )
      then array[0,1,0,0,clayCosts.ore,0,0]
      when production.ore >= oreCosts.ore
	and not (
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot next minute */
          (production.ore + oreRobot - oreCosts.ore >= geodeCosts.ore
	  and production.obsidian + obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot in the next 2 minutes */
          (production.ore + 2*oreRobot - oreCosts.ore >= geodeCosts.ore
	  and production.obsidian + 2*obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot in the next 3 minutes */
          (production.ore + 3*oreRobot - oreCosts.ore >= geodeCosts.ore
	  and production.obsidian + 3*obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a geodeRobot in the next 4 minutes */
          (production.ore + 4*oreRobot - oreCosts.ore >= geodeCosts.ore
	  and production.obsidian + 4*obsidianRobot >= geodeCosts.obsidian)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * an obsidianRobot next minute */
          (production.ore + oreRobot - oreCosts.ore >= obsidianCosts.ore
	  and production.clay + clayRobot >= obsidianCosts.clay)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * an obsidianRobot in the next 2 minutes */
          (production.ore + 2*oreRobot - oreCosts.ore >= obsidianCosts.ore
	  and production.clay + 2*clayRobot >= obsidianCosts.clay)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * an obsidianRobot in the next 3 minutes */
          (production.ore + 3*oreRobot - oreCosts.ore >= obsidianCosts.ore
	  and production.clay + 3*clayRobot >= obsidianCosts.clay)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * an obsidianRobot in the next 4 minutes */
          (production.ore + 4*oreRobot - oreCosts.ore >= obsidianCosts.ore
	  and production.clay + 4*clayRobot >= obsidianCosts.clay)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * an clayRobot next minute */
          (production.ore + oreRobot - oreCosts.ore >= clayCosts.ore)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a clayRobot in the next 2 minutes */
          (production.ore + 2*oreRobot - oreCosts.ore >= clayCosts.ore)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a clayRobot in the next 3 minutes */
          (production.ore + 3*oreRobot - oreCosts.ore >= clayCosts.ore)
	  or
	  /* We don't want to take too much ore that would prevent creating
	   * a clayRobot in the next 4 minutes */
          (production.ore + 4*oreRobot - oreCosts.ore >= clayCosts.ore)
        )
      then array[1,0,0,0,oreCosts.ore,0,0]
      else
        array[0,0,0,0,0,0,0]
    end
  from production
    inner join costs as geodeCosts
      on production.blueprintid = geodeCosts.blueprintid
      and geodeCosts.robottype = 'geode robot'
    inner join costs as obsidianCosts
      on production.blueprintid = obsidianCosts.blueprintid
      and obsidianCosts.robottype = 'obsidian robot'
    inner join costs as clayCosts
      on production.blueprintid = clayCosts.blueprintid
      and clayCosts.robottype = 'clay robot'
    inner join costs as oreCosts
      on production.blueprintid = oreCosts.blueprintid
      and oreCosts.robottype = 'ore robot'
  where minute = thisMinute - 1
    and production.blueprintId = thisBluePrintId
$whichRobot$ language sql;

create procedure produce(thisMinute integer) as
$produce$
  with bestRobot(bluePrintId,
    robot,
    oreRobot,
    clayRobot,
    obsidianRobot,
    geodeRobot,
    ore,
    clay,
    obsidian,
    geode
  ) as
  (
    select bluePrintId,
      whichRobot(bluePrintId, thisMinute),
      oreRobot,
      clayRobot,
      obsidianRobot,
      geodeRobot,
      ore,
      clay,
      obsidian,
      geode
    from production
    where minute = thisMinute - 1
  )
  insert into production (minute, blueprintId, oreRobot, clayRobot, obsidianRobot, geodeRobot,
     ore, clay, obsidian, geode)
  (select thisMinute,
    bluePrintId,
    oreRobot + robot[1],
    clayRobot + robot[2],
    obsidianRobot + robot[3],
    geodeRobot + robot[4],
    ore - robot[5] + oreRobot,
    clay - robot[6] + clayRobot,
    obsidian - robot[7] + obsidianRobot,
    geode + geodeRobot
  from bestRobot);

--  /* The priority is to build a geode robot */
--  with
--  /* Let's produce */
--  produce(bluePrintId, oreRobot, clayRobot, obsidianRobot, geodeRobot,
--    ore, clay, obsidian, geode, produce, parent) as (
--    /* producing geode robot if possible */
--    select distinct /* I don't need to record several times the same result */
--      production.bluePrintId,
--      production.oreRobot,
--      production.clayRobot,
--      production.obsidianRobot,
--      production.geodeRobot + 1,
--      production.ore - costs.ore + production.oreRobot,
--      production.clay + production.clayRobot,
--      production.obsidian - costs.obsidian + production.obsidianRobot,
--      production.geode + production.geodeRobot,
--      1,
--      production.id
--    from production
--      inner join costs
--        on production.bluePrintId = costs.bluePrintId
--    where production.minute = thisMinute - 1
--      and robotType = 'geode robot'
--      and production.ore >= costs.ore
--      and production.obsidian >= costs.obsidian
--    union all
--    /* producing obsidian robot if possible */
--    select distinct /* I don't need to record several times the same result */
--      production.bluePrintId,
--      production.oreRobot,
--      production.clayRobot,
--      production.obsidianRobot + 1,
--      production.geodeRobot,
--      production.ore - costs.ore + production.oreRobot,
--      production.clay - costs.clay + production.clayRobot,
--      production.obsidian + production.obsidianRobot,
--      production.geode + production.geodeRobot,
--      2,
--      production.id
--    from production
--      inner join costs
--        on production.bluePrintId = costs.bluePrintId
--    where production.minute = thisMinute - 1
--      and robotType = 'obsidian robot'
--      and production.ore >= costs.ore
--      and production.clay >= costs.clay
--    union all
--    /* producing clay robot if possible */
--    select distinct /* I don't need to record several times the same result */
--      production.bluePrintId,
--      production.oreRobot,
--      production.clayRobot + 1,
--      production.obsidianRobot,
--      production.geodeRobot,
--      production.ore - costs.ore + production.oreRobot,
--      production.clay + production.clayRobot,
--      production.obsidian + production.obsidianRobot,
--      production.geode + production.geodeRobot,
--      3,
--      production.id
--    from production
--      inner join costs
--        on production.bluePrintId = costs.bluePrintId
--    where production.minute = thisMinute - 1
--      and robotType = 'clay robot'
--      and production.ore >= costs.ore
--    union all
--    /* producing ore robot if possible */
--    select distinct /* I don't need to record several times the same result */
--      production.bluePrintId,
--      production.oreRobot + 1,
--      production.clayRobot,
--      production.obsidianRobot,
--      production.geodeRobot,
--      production.ore - costs.ore + production.oreRobot,
--      production.clay + production.clayRobot,
--      production.obsidian + production.obsidianRobot,
--      production.geode + production.geodeRobot,
--      4,
--      production.id
--    from production
--      inner join costs
--        on production.bluePrintId = costs.bluePrintId
--    where production.minute = thisMinute - 1
--      and robotType = 'ore robot'
--      and production.ore >= costs.ore
--  ),
--  insertion as (
--    insert into production(minute, bluePrintId, oreRobot, clayRobot, obsidianRobot,
--      geodeRobot, ore, clay, obsidian, geode, produce, parent)
--    (
--      select thisMinute,
--        production.bluePrintId,
--        produce.oreRobot, /* ore-collecting robot */
--        produce.clayrobot, /* clay robot */
--        produce.obsidianrobot, /* osbidian robot */
--        produce.geoderobot, /* geode robot */
--        produce.ore, /* ore */
--        produce.clay, /* clay */
--        produce.obsidian, /* obsidian */
--        produce.geode,  /* geode */
--	produce.produce,
--	produce.parent
--      from produce
--        inner join production
--          on produce.bluePrintId = production.bluePrintId
--      where minute = thisMinute - 1
--    )
--    returning *
--  )
--  /* Let's record that we didn't produce any robot if it's the case */
--  insert into production(minute, bluePrintId, oreRobot, clayRobot, obsidianRobot,
--    geodeRobot, ore, clay, obsidian, geode, produce, parent)
--  (
--    select
--      thisMinute,
--      production.bluePrintId,
--      production.oreRobot,
--      production.clayRobot,
--      production.obsidianRobot,
--      production.geodeRobot,
--      production.ore + production.oreRobot, /* ore */
--      production.clay + production.clayRobot, /* clay */
--      production.obsidian + production.obsidianRobot, /* obsidian */
--      production.geode + production.geodeRobot,  /* geode */
--      5,
--      production.id
--    from production
--    where minute = thisMinute - 1
--      and not exists (
--      select 1
--      from insertion
--      where insertion.bluePrintId = production.bluePrintId
--        and insertion.minute = thisMinute
--    )
--  )
--  ;
--
--  /* Let's remove duplicates */
--  delete from production a
--  where exists (
--    select 1
--    from production b
--    where a.minute = b.minute
--      and a.blueprintId = b.blueprintId
--      and a.oreRobot = b.oreRobot
--      and a.clayRobot = b.clayRobot
--      and a.obsidianRobot = b.obsidianRobot
--      and a.geodeRobot = b.geodeRobot
--      and a.ore = b.ore
--      and a.clay = b.clay
--      and a.obsidian = b.obsidian
--      and a.geode = b.geode
--      and b.ctid > a.ctid
--  );
--  /* let's delete the former minute values */
--  delete from production
--  where minute = thisMinute - 2;
--
--  /* let's delete any version where we have enough resources to create
--   * a geodeRobot but didn't */
--  delete from production
--  using costs
--  where robotType = 'geode robot'
--    and costs.blueprintId = production.bluePrintId
--    and production.ore >= costs.ore
--    and production.obsidian >= costs.obsidian;
--
--  /* let's delete any version where we have enough resources to create
--   * an obsidianRobot but didn't */
--  delete from production
--  using costs
--  where robotType = 'obsidian robot'
--    and costs.blueprintId = production.bluePrintId
--    and production.ore >= costs.ore
--    and production.clay >= costs.clay;

$produce$ language sql;


/* Let's run this for 24 minutes */
select 'call produce(' || s || ')'
from generate_series(1,24) t(s)
\gexec

--
--select sum(bluePrintId * geode) as PartOne
--from production
--where minute = 24;
