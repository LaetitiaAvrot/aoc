/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc01 cascade;
create schema aoc01;
set search_path to 'aoc01';

/* Insert data into  table */
create table input (
	id integer generated always as identity primary key,
	data text not null,
	game integer generated always as (
		substring(data from 6 for (strpos(data,':')-6))::int) stored
);

\copy input(data) from 'input.csv';

with games(game, cubes) as (
	/* First, let split the games into multiple rows */
	select game,
	  regexp_split_to_table(substring(data from (strpos(data,':')+1)), ';')
	from input
),
cubes(game, blue, green, red) as (
	/* Let's grab the number of cube of each color for each set for each game */
	select game,
		coalesce(regexp_substr(regexp_substr(cubes, '\d+ blue'), '\d+')::int,0) as blue,
		coalesce(regexp_substr(regexp_substr(cubes, '\d+ green'), '\d+')::int,0) as green,
		coalesce(regexp_substr(regexp_substr(cubes, '\d+ red'), '\d+')::int,0) as red
	from games),
impossible(game) as (
	/* Then we can find the impossible games */
	select distinct game
	from cubes
	where blue > 14 or green > 13 or red > 12
)
/* It's now easy to find the possible games and sum them up */
select sum(game) as firstStar
from input
where not exists (select 1 from impossible where input.game = impossible.game)
;

with games(game, cubes) as (
	/* First, let split the games into multiple rows */
	select game,
	  regexp_split_to_table(substring(data from (strpos(data,':')+1)), ';')
	from input
),
cubes(game, blue, green, red) as (
	/* Let's grab the number of cube of each color for each set for each game */
	select game,
		coalesce(regexp_substr(regexp_substr(cubes, '\d+ blue'), '\d+')::int,0) as blue,
		coalesce(regexp_substr(regexp_substr(cubes, '\d+ green'), '\d+')::int,0) as green,
		coalesce(regexp_substr(regexp_substr(cubes, '\d+ red'), '\d+')::int,0) as red
	from games),
fewestCubes(game, blue, green, red) as (
	/* get the max of each cube for all sets in each game */
	select distinct game,
		max(blue) over (partition by game),
		max(green) over (partition by game),
		max(red) over (partition by game)
	from cubes)
/* Calculate the "power of the sets of cubes" */
select sum(blue*green*red) as secondStar
from fewestCubes;

/* Things I learned (and improved):
 *
 * - Window functions are powerfull, but when you aggregate, you might wasnt to
 * use a distinct to remove duplicates.
 *
 * - The function regexp_substr is great, allowing you to isolate a substring
 * based on a regexp pattern. It will give a null value if the pattern is not
 * found, which is great too.
 *
 * - I love generated columns, they really simplify my life in thios game.
 * I could have generated a "cubes" column to remove one of the CTEs.
 */
