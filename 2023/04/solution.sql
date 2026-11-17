/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc04 cascade;
create schema aoc04;
set search_path to 'aoc04';

/* Insert data into  table */
create table input (
	id integer generated always as identity primary key,
	data text not null,
	winningNum int[] generated always as (
		regexp_split_to_array(trim((regexp_split_to_array(regexp_replace(data, 'Card\s+\d+\s*:',''),'\|'))[1]),' +')::int[]
	) stored,
	cardNum int[] generated always as (
		regexp_split_to_array(trim((regexp_split_to_array(regexp_replace(data, 'Card\s+\d+\s*:',''),'\|'))[2]),' +')::int[]
	) stored,
	points bigint,
	winingNumbers int
);

\copy input(data) from 'input.csv';

/* Let's find how many winning numbers we got for each card */
with winning(id, win) as (
	select id, array_positions(cardnum, win)
	from input
		left join lateral unnest(winningnum) as a(win) on true
	where cardinality(array_positions(cardnum, win))> 0
),
/* then we can count the points */
points (id, c, p) as (
	select id, count(win), power(2,count(win)-1)::bigint
	from winning
	group by id
),
updates(p) as (
	update input
	set points = p,
		winingNumbers = c
	from points
	where input.id = points.id
	returning p)
/* And that's star One */
select sum(p) as starOne
from points;

/* Let's find how many winning numbers we got for each card */
with recursive wonCopies (id, n) as (
/* Let's get the copies */
	select cards, 1
	from
		/* Cartesian product with a one row table */
		(select max(id) from input) as m(maximum),
		 input
		left join lateral (
			select *
			from generate_series(id+1, id+winingNumbers) g(cards)
				/* let's remove the cards numbers that don't exist */
			  inner join input on input.id = g.cards
		) as g(cards) on true
	union all
	select cards, n+1
	from
		/* Cartesian product with a one row table */
		(select max(id) from input) as m(maximum),
		wonCopies inner join input on wonCopies.id = input.id
		left join lateral (
			select *
			from generate_series(wonCopies.id+1, wonCopies.id+winingNumbers) g(cards)
				/* let's remove the cards numbers that don't exist */
			  inner join input on input.id = g.cards
		) as g(cards) on true
),
cards(id, n) as (
	select id, count(*)
	from (select id from wonCopies union all select id from input)
	where id is not null
	group by id
)
select sum(n) as starTwo
from cards
;

/* Things I learned (and improved my skills in):
 *
 * - Lateral are sooo powerfull
 *
 * - I love regexp even though I'm not the best at them
 *
 * - A inner join is the best way to remove null values
 *
 */
