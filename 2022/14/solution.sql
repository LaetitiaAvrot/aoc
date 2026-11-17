/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity not null,
  value text,
  rocks path
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

/* Let's try to clean up the entry */
/* this seems like a good opportunity to learn geometric data types, I will try
 * to use paths for the rocks */
with points(id, xy) as (
  select id, '(' || string_to_table(value, ' -> ') || ')'
  from input
),
rocks(id, rockpath) as (
select id, ('[' || string_agg(xy,',') || ']')::path
from points
group by id)
update input set rocks = rocks.rockpath
from rocks
where input.id = rocks.id;

drop table if exists cave cascade;
create table cave (
  x integer not null,
  y integer not null,
  value char(1) not null,
  isLast boolean not null
);

/* Creating the cave */
with units (u) as (
  select ('(' || string_to_table(value, ' -> ') || ')')::point
  from input
),
bounds(maxx, minx, maxy, miny) as (
  /* That's a small note at the end of the geometric types documentation pagem
   * but you can access a point's coordinates using [] as if it was an array or
   * 2 double precision numbers.
   * You can also use it to get to points composing a path, a polygon, a box,
   * a segment, the exact same way */
  select max(u[0])::integer, min(u[0])::integer, max(u[1])::integer,0 from units
),
points(x, y) as (
  select x.*, y.*
  from generate_series((select minx from bounds), (select maxx from bounds)) as x(n),
    generate_series((select miny from bounds), (select maxy from bounds)) as y(n)
)
insert into cave(x,y,value,isLast) (
  select x, y, '.', false
  from points
);

/* Add rocks */
update cave set value = '#'
/* We're looking for the points contained in the rock paths */
where point(x,y) <@ any(select rocks from input)
;

/* Let's update the 2 last points before the sand becones floating */
update cave set isLast = true where point(x,y) ~= (
  select point((select min(x) from cave),min(y)-1)
  from cave
  where x = (select min(x) from cave)
    and value = '#')
;
update cave set isLast = true where point(x,y) ~= (
  select point((select max(x) from cave),min(y)-1)
  from cave
  where x = (select max(x) from cave)
    and value = '#')
;

/* Let's begin filling the cave space with sand units! */
drop procedure if exists fillWithSand();
create procedure fillWithSand() as
$fillWithSand$
with recursive nextPosition(x,y) as (
  select x,y
  from cave
  where x = 500
    and y = 0
  union all
  select cave.x,cave.y
  from cave
    inner join nextPosition
      on
        /*Whatever happens the sand unit will go down*/
        cave.y = nextPosition.y+1
      and
	/* It will try to go straight, if not possible left, if not possible
	 * right */
        case when
	    /* is there some rocks or sand below? */
            exists (
	      select 1
	      from cave c
	      where c.x  = nextPosition.x
	      and c.y = nextPosition.y+1
	      and c.value <> '.')
	  then /* try left */
	    case when
	      /* is there some rocks or sand below left ? */
              exists (
	        select 1
	        from cave c
	        where c.x  = nextPosition.x-1
	        and c.y = nextPosition.y+1
	        and c.value <> '.')
	      then /* go right if possible */
	        case when
                  exists (
	            select 1
	            from cave c
	            where c.x  = nextPosition.x+1
	            and c.y = nextPosition.y+1
	            and c.value <> '.')
	          then /* Impossible join condition to get 0 point */
	            cave.x = -1
	          else
                    cave.x = nextPosition.x+1
	        end
	      else /* go left */
                cave.x = nextPosition.x-1
	    end
	  else /* go straight */
	    cave.x = nextPosition.x
	end
    where /* We don't want to get "floating" sand units */
      cave.y <= (select max(y) from cave)
)
update cave set value = 'o' where point(cave.x,cave.y) ~= (
    select point(x,y)
    from nextPosition
    order by y desc
    limit 1
  )
  /* This shoud make sure we stop when the first floating point is filled */
  and (select count(*) from cave where isLast and value='.') = 2;
;
$fillWithSand$ language sql;

/* I will call the procedure a little more than necessary as it will be called
 * as if the sand could fill all the cave space, but that's ok, the last calls
 * should'nt delete any row */
\set QUIET on
select $$call fillwithsand();$$
from cave where value = '.'
\gexec
\set QUIET off

/* View for debugging purpose only */
create view mycave as (
  select y, string_agg(value,'')
  from (select y,value from cave order by y,x)
  group by y
  order by y
);

/* Don't forget to remove the last sand unit that should be floating */
select count(*) -1 as PartOne
from cave
where value ='o'
;

--/* Let's remove the floating sand unit */
update cave set value ='.' where isLast;

/* Let's add max(y) empty spaces left and right of the original cave */
with boundaries (maxx, minx, maxy) as (
  select max(x), min(x), max(y)
  from cave
)
insert into cave(x,y,value,isLast) (
  select x,y, '.', false
  from boundaries,
    generate_series(minx-maxy-1, minx-1) t(x),
    /* Legitimate use of a cartesian product */
    generate_series(0, maxy) s(y));

with boundaries (maxx, minx, maxy) as (
  select max(x), min(x), max(y)
  from cave
)
insert into cave(x,y,value,isLast) (
  select x,y, '.', false
  from boundaries,
    generate_series(maxx+1, maxx+maxy+1) t(x),
    /* Legitimate use of a cartesian product */
    generate_series(0, maxy) s(y));

/* Let's add the floor */
with boundaries (maxx, minx, maxy) as (
  select max(x), min(x), max(y)
  from cave
)
insert into cave (x,y,value,isLast) (
  select x, maxy+2, '#', false
  from boundaries,
    generate_series(minx, maxx) t(x));

/* and the empty row above the floor */
with boundaries (maxx, minx, maxy) as (
  select max(x), min(x), max(y)
  from cave
)
insert into cave (x,y,value,isLast) (
  select x, maxy-1, '.', false
  from boundaries,
    generate_series(minx, maxx) t(x));

/* Let's begin filling the cave space with sand units! */
drop procedure if exists fillWithSand2();
create procedure fillWithSand2() as
$fillWithSand2$
with recursive nextPosition(x,y) as (
  select x,y
  from cave
  where x = 500
    and y = 0
  union all
  select cave.x,cave.y
  from cave
    inner join nextPosition
      on
        /*Whatever happens the sand unit will go down*/
        cave.y = nextPosition.y+1
      and
	/* It will try to go straight, if not possible left, if not possible
	 * right */
        case when
	    /* is there some rocks or sand below? */
            exists (
	      select 1
	      from cave c
	      where c.x  = nextPosition.x
	      and c.y = nextPosition.y+1
	      and c.value <> '.')
	  then /* try left */
	    case when
	      /* is there some rocks or sand below left ? */
              exists (
	        select 1
	        from cave c
	        where c.x  = nextPosition.x-1
	        and c.y = nextPosition.y+1
	        and c.value <> '.')
	      then /* go right if possible */
	        case when
                  exists (
	            select 1
	            from cave c
	            where c.x  = nextPosition.x+1
	            and c.y = nextPosition.y+1
	            and c.value <> '.')
	          then /* Impossible join condition to get 0 point */
	            cave.x = -1
	          else /* go right */
                    cave.x = nextPosition.x+1
	        end
	      else /* go left */
                cave.x = nextPosition.x-1
	    end
	  else /* go straight */
	    cave.x = nextPosition.x
	end
)
update cave set value = 'o' where point(cave.x,cave.y) ~= (
    select point(x,y)
    from nextPosition
    order by y desc
    limit 1
  )
  /* We don't stop until the position (500,0) is also filled with sand */
  and (select count(*) from cave where x=500 and y=0 and value='.') = 1
;
$fillWithSand2$ language sql;

/* I will call the procedure a little more than necessary as it will be called
 * as if the sand could fill all the cave space, but that's ok, the last calls
 * should'nt delete any row */
\set QUIET on
select $$call fillwithsand2();$$
from cave where value = '.'
\gexec
\set QUIET off

select count(*) as partTwo
from cave
where value = 'o';
