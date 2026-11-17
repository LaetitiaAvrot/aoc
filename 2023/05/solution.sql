/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc05 cascade;
create schema aoc05;
set search_path to 'aoc05';

/* Insert data into  table */
create table input (
	id integer generated always as identity primary key,
	data text not null,
	source text generated always as (
		case when data ~ ':' and data !~ 'seeds' then (regexp_split_to_array(data, '-| |:'))[1]  end
	) stored,
	destination text generated always as (
		/* There's no destination for the seeds data */
		case when data ~ ':' and data !~ 'seeds:' then (regexp_split_to_array(data, '-| |:'))[3]  end
	) stored,
	numbers text[] generated always as (
		case when data ~ '\d' and data !~ 'seeds:' then regexp_split_to_array(data, ' ')
			when data ~ 'seeds:' then regexp_split_to_array(substring(data from 8), ' ')
		end
	) stored
);

\copy input(data) from 'input.csv';

create table conversion (
	source text not null,
	destination text not null,
	s int8range not null, /* For source, but I was out of names */
	o bigint not null /* For offset, but that's a keyword */
);

with DataRanges(source, destination, r) as (
	select source,
		destination,
		/* looking for the ids for such conversions */
		/* By default, ranges are '[)' */
		int4range(id+1, lead(id) over() -1)
	from input
	where id > 2
		and source is not null
)
insert into conversion (
	select dataRanges.source,
		dataRanges.destination,
		/* By default, ranges are '[)] */
		int8range(numbers[2]::bigint,numbers[2]::bigint + numbers[3]::bigint - 1, '[]'),
		numbers[1]::bigint - numbers[2]::bigint
	from DataRanges
		inner join input
			on dataRanges.r @> input.id
)
;

/* let's look at the seeds! */
with seeds (seed) as (
	select seed::bigint
	from input
		left join lateral unnest(numbers) t(seed) on true
	where id = 1
),
soil (seed, converted) as (
	select
		seed,
		coalesce(o+seed, seed)
	from seeds s
		/* seed to soil conversion */
		left join conversion
			on source = 'seed'
				and s @> s.seed
),
fertilizer (seed,converted) as (
	select
		seed,
		coalesce(o+converted, converted)
	from soil s
		/* soil to fertilizer conversion */
		left join conversion
			on source = 'soil'
				and s @> converted
),
water (seed,converted) as (
	select
		seed,
		coalesce(o+converted, converted)
	from fertilizer s
		/* fertilizer to water conversion */
		left join conversion
			on source = 'fertilizer'
				and s @> converted
),
light (seed,converted) as (
	select
		seed,
		coalesce(o+converted, converted)
	from water s
		/* water to light conversion */
		left join conversion
			on source = 'water'
				and s @> converted
),
temperature (seed,converted) as (
	select
		seed,
		coalesce(o+converted, converted)
	from light s
		/* light to temperature conversion */
		left join conversion
			on source = 'light'
				and s @> converted
),
humidity (seed,converted) as (
	select
		seed,
		coalesce(o+converted, converted)
	from temperature s
		/* temperature to humidity conversion */
		left join conversion
			on source = 'temperature'
				and s @> converted
),
location (seed,converted) as (
	select
		seed,
		coalesce(o+converted, converted)
	from humidity s
		/* humidity to location conversion */
		left join conversion
			on source = 'humidity'
				and s @> converted
)
select min(converted) as starOne
from location
;

/* Things I learned (and improved my skills in):
 *
 * - Ramges are more powerfull than storing all teh values in a table and
 * performing a join (which shouldn't be a surprise)
 *
 * - I used the little birdie operator again! (@>)
 *
 */
