/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity not null,
  value text not null,
  direction char(1) not null generated always as (split_part(value,' ',1)) stored,
  howFar integer not null generated always as (split_part(value,' ',2)::integer) stored,
  /* The position of head, tail and other knots at the beginning */
  ropeBegin point[],
  /* The positions of head, tail and other knots at the end */
  ropeEnd point[]
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

/* Let's put head and tail on start position */
update input set ropeBegin = array[point(0,0),point(0,0)]
where id = 1;

drop table if exists tailPositions;
create table tailPositions (
  id integer generated always as identity not null,
  x integer not null,
  y integer not null,
  unique (x,y));

insert into tailPositions (x,y) values (0,0);

drop function if exists move;
create function move(p point, direction char(1)) returns point as
$move$
  select case when direction = 'R'
      then p + point(1,0)
    when direction = 'L'
      then p + point(-1,0)
    when direction = 'U'
      then p + point(0,1)
    when direction = 'D'
      then p + point(0,-1)
  end;
$move$ language sql;

drop function if exists moveTail;
create function moveTail(tail point, head point) returns point as
$moveTail$
  select
  /* The tail moves only if it's more than 1 appart from the head */
  case when tail <-> head >= 2
  then
    case when (tail[0]=head[0]) and (tail <<| head)
      /* The tail is below the head ? */
      then move(tail,'U')
      when (tail[0]=head[0]) and (tail |>> head)
      /* The tail is above the head ? */
      then move(tail,'D')
      when (tail[1]=head[1]) and (tail << head)
      /* The tail is left to the head ? */
      then move(tail,'R')
      when (tail[1]=head[1]) and (tail >> head)
      /* The tail is left to the head ? */
      then move(tail,'L')
      /* The tail is below and left to the head */
      when (tail <<| head) and (tail << head)
	then move(move(tail,'R'),'U')
      /* The tail is above and left to the head */
      when (tail |>> head) and (tail << head)
	then move(move(tail,'R'),'D')
      /* The tail is below and right to the head */
      when (tail <<| head) and (tail >> head)
	then move(move(tail,'L'),'U')
      /* The tail is below and left to the head */
      when (tail |>> head) and (tail >> head)
	then move(move(tail,'L'),'D')
    end
    /* Else we don't have to move the tail */
  else tail
  end;
$moveTail$ language sql;

drop procedure if exists moveRope;
create procedure moveRope(myid integer) as
$moveRope$
  with updated(rope) as (
    update input set ropeEnd = array[
      move((coalesce(ropeEnd, ropeBegin))[1], direction),
      moveTail((coalesce(ropeEnd, ropeBegin))[2],move((coalesce(ropeEnd, ropeBegin))[1], direction))]
    where id = myid
    returning ropeEnd)
  update input set ropeBegin = updated.rope
  from updated
  where id = myid + 1;
  insert into tailPositions (x,y)
  (select (ropeEnd[2])[0], (ropeEnd[2])[1] from input where id=myid)
  on conflict do nothing;
$moveRope$ language sql;

\set QUIET on
/* Let's move the head */
select $$call moveRope($$ || id || $$);$$
from input,
  generate_series(1,howfar)
order by id
\gexec
\set QUIET off

select count(*) as PartOne from tailPositions;

drop procedure if exists moveRope;
create procedure moveRope(myid integer) as
$moveRope$
  with knot1(rope) as (
    select
      array[move(ropeEnd[1], direction),
        ropeEnd[2],ropeEnd[3], ropeEnd[4], ropeEnd[5], ropeEnd[6], ropeEnd[7],
        ropeEnd[8], ropeEnd[9], ropeEnd[10]]
    from input where id = myid),
  knot2(rope) as (
    select
      array[rope[1], moveTail(rope[2], rope[1]), rope[3], rope[4], rope[5],
        rope[6], rope[7], rope[8], rope[9], rope[10]]
    from knot1),
  knot3(rope) as (
    select
      array[rope[1], rope[2], moveTail(rope[3], rope[2]),
        rope[4], rope[5], rope[6], rope[7], rope[8], rope[9], rope[10]]
    from knot2),
  knot4(rope) as (
    select
      array[rope[1], rope[2], rope[3], moveTail(rope[4], rope[3]), rope[5],
        rope[6], rope[7], rope[8], rope[9], rope[10]]
    from knot3),
  knot5(rope) as (
    select
      array[rope[1], rope[2], rope[3], rope[4], moveTail(rope[5], rope[4]),
        rope[6], rope[7], rope[8], rope[9], rope[10]]
    from knot4),
  knot6(rope) as (
    select
      array[rope[1], rope[2], rope[3], rope[4], rope[5],
        moveTail(rope[6], rope[5]), rope[7], rope[8], rope[9], rope[10]]
    from knot5),
  knot7(rope) as (
    select
      array[rope[1], rope[2], rope[3], rope[4], rope[5], rope[6],
        moveTail(rope[7], rope[6]), rope[8], rope[9], rope[10]]
    from knot6),
  knot8(rope) as (
    select
      array[rope[1], rope[2], rope[3], rope[4], rope[5], rope[6], rope[7],
        moveTail(rope[8], rope[7]), rope[9], rope[10]]
    from knot7),
  knot9(rope) as (
    select
      array[rope[1], rope[2], rope[3], rope[4], rope[5], rope[6], rope[7],
        rope[8], moveTail(rope[9], rope[8]), rope[10]]
    from knot8),
  knot10(rope) as (
    select
      array[rope[1], rope[2], rope[3], rope[4], rope[5], rope[6], rope[7],
        rope[8], rope[9], moveTail(rope[10], rope[9])]
    from knot9)
  update input set ropeEnd = rope from knot10 where id = myId;
  /* Get ready for next instruction if it's the last one */
  update input set ropeBegin = (select ropeEnd from input where id = myId),
   ropeEnd = (select ropeEnd from input where id = myId)
  where id = myid + 1;
  insert into tailPositions (x,y)
  (select (ropeEnd[10])[0], (ropeEnd[10])[1] from input where id=myid)
  on conflict do nothing;
$moveRope$ language sql;

truncate tailPositions;
update input set ropeBegin = null, ropeEnd = null;
update input set ropeBegin =
  array[point(0,0), point(0,0), point(0,0), point(0,0), point(0,0), point(0,0),
    point(0,0), point(0,0), point(0,0), point(0,0)]
where id = 1;
update input set ropeEnd = ropeBegin where id = 1;

\set QUIET on
/* Let's move the head */
select $$call moveRope($$ || id || $$);$$
from input,
  generate_series(1,howfar)
order by id
\gexec

select count(*) as PartTwo from tailPositions;
