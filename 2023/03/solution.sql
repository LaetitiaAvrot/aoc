/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc03 cascade;
create schema aoc03;
set search_path to 'aoc03';

/* Insert data into  table */
create table input (
	id integer generated always as identity primary key,
	data text not null,
	transformedData text generated always as (
		/* Let's juste make sure we have no number at the beginning or the end of
		 * each line, so there's no edge cases. (It might be totally useless, but
		 * let's say it's a precaution */
		'.' || data || '.'
	) stored
);

\copy input(data) from 'input.csv';

/* Let's create the engine map in a map table with coordinates */
create table map(
	coordinates point,
	value char(1)
);

insert into map (
	select point(x,id), value
	from input
		left join lateral unnest(regexp_split_to_array(transformedData,'')) with ordinality as t(value,x) on true
);

with recursive numbers(x1, x2, y, num, data, n) as (
	/* Let's isolate the numbers and their position on each line first */
	select regexp_instr(data, '\d'),
		regexp_instr(data, '\d') + length((regexp_match(data, '\d+'))[1]),
		id,
		(regexp_match(data, '\d+'))[1],
		substring(data from regexp_instr(data, '\d') + 1+length((regexp_match(data, '\d+'))[1])),
		1
	from input
	where (regexp_match(data, '\d+'))[1] is not null
	union all
	select x2 + regexp_instr(data, '\d'),
		x2 + regexp_instr(data, '\d') + length((regexp_match(data, '\d+'))[1]),
		y,
		(regexp_match(data, '\d+'))[1],
		substring(data from regexp_instr(data, '\d') + 1+length((regexp_match(data, '\d+'))[1])),
		n+1
	from numbers
	where (regexp_match(data, '\d+'))[1] is not null
),
surroundings(num, surrounding) as (
	/* Let's consider the string formed with all the characters surrounding the
	 * numbers (including the numbers */
	select num, surrounding
	from numbers
	  left join lateral (
			select string_agg(value,'')
			from map
			where box(point(x1, y-1),point(x2+1, y+1)) @> map.coordinates
			group by y
		) t(surrounding) on true
)
/* And that's star one */
select sum(num::int) as starOne
from surroundings
where surrounding ~ '[^\d|\.]+'
;

with recursive numbers(x1, x2, y, num, data) as (
	/* Let's isolate the numbers and their position on each line first */
	select regexp_instr(data, '\d'),
		regexp_instr(data, '\d') + length((regexp_match(data, '\d+'))[1]),
		id,
		(regexp_match(data, '\d+'))[1]::int,
		substring(data from regexp_instr(data, '\d') + 1+length((regexp_match(data, '\d+'))[1]))
	from input
	where (regexp_match(data, '\d+'))[1] is not null
	union all
	select x2 + regexp_instr(data, '\d'),
		x2 + regexp_instr(data, '\d') + length((regexp_match(data, '\d+'))[1]),
		y,
		(regexp_match(data, '\d+'))[1]::int,
		substring(data from regexp_instr(data, '\d') + 1+length((regexp_match(data, '\d+'))[1]))
	from numbers
	where (regexp_match(data, '\d+'))[1] is not null
),
potentialGears (coordinates, value) as (
	/* Let's find the * first */
	select *
	from map
	where value = '*'
),
digits(x, y, coords) as (
	/* Is there a digit around? */
	select map.coordinates[0], map.coordinates[1], potentialGears.coordinates
	from map
	  inner join potentialGears
			on
				/* Is it on the previous line but still next to the * ? */
				(map.coordinates[1] = potentialGears.coordinates[1]-1
					and map.coordinates[0] between potentialGears.coordinates[0]-1
						and potentialGears.coordinates[0]+1)
				or
				/* Is it on the current line and next to the * ? */
				(map.coordinates[1] = potentialGears.coordinates[1]
					and map.coordinates[0] between potentialGears.coordinates[0]-1
						and potentialGears.coordinates[0]+1)
				or
				/* Is it on the next line but still next to the * ? */
				(map.coordinates[1] = potentialGears.coordinates[1]+1
					and map.coordinates[0] between potentialGears.coordinates[0]-1
						and potentialGears.coordinates[0]+1)
	where map.value::text ~ '\d'
),
almostThere(num,gearx, geary) as (
select distinct on (x1, numbers.y)
	num,
	coords[0],
	coords[1]
from digits
	inner join numbers
	on digits.y = numbers.y and digits.x between numbers.x1 and numbers.x2
),
realgears(num, coords) as (
	select array_agg(num),
		gearx::text || geary::text
	from almostThere
	group by gearx::text || geary::text
	/* It's only a gear if there's exactly 2 numbers around */
	having count(*) = 2
)
/* and that's startTwo */
select sum(num[1] * num[2]) as starTwo
from realgears
;

/* Things I learned (and improved):
 *
 * - Multiranges are cool. They allow you to compare in onego several ranges
 *   with one
 *
 * - I had forgotten lateral joins syntax... If you don't practice, you forget
 *
 * - There is no consistency: adding a range to a multirange needs the oprartor
 * '+', adding an element to an array needs the operator '||'. (I know I'm not
 * totally fair as the opertor '+' is for union of rangesi, I just want to
 * rant.)
 *
 * - distinct on(...) is very powerful!
 */
