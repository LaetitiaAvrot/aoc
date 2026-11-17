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
	value integer generated always as (
		(regexp_substr(data, '\d', 1) ||
		regexp_substr(reverse(data), '\d', 1))::int
		) stored
);

\copy input(data) from 'input.csv';

select sum(value) as firstStar
from input;

create table digits (
	digitValue text,
	textValue text,
	reverse text generated always as (reverse(textValue)) stored
);

insert into digits (digitValue, textValue) values
	('1','one'),
	('2','two'),
	('3','three'),
	('4','four'),
	('5','five'),
	('6','six'),
	('7','seven'),
	('8','eight'),
	('9','nine')
;


/* Second way of doing it: CTEs */
with processingFirst(id, data) as (
	/* I was overcomplicating the problem, trying to change all the occurences of
	 * spelled digits into digits whereas I just need to change the first one and
	 * the last one!!!
	 * No recursive CTE is needed (even though, they are cool) */
	select id,
		coalesce(regexp_replace(data, textValue, digitValue),data)
	from input
		left join digits
			/* This is the coolest join condition I wrote so far */
			on (regexp_match(data, 'one|two|three|four|five|six|seven|eight|nine'))[1] = textValue
),
processingLast(id, data) as (
	/* I was overcomplicating the problem, trying to change all the occurences of
	 * spelled digits into digits whereas I just need to change the first one and
	 * the last one!!!
	 * No recursive CTE is needed (even though, they are cool) */
	select id,
		coalesce(regexp_replace(reverse(data), reverse, digitValue),reverse(data))
	from input
		left join digits
			/* This is the new coolest join condition I wrote so far */
			on (regexp_match(reverse(data), 'eno|owt|eerht|ruof|evif|xis|neves|thgie|enin'))[1] = reverse
)
select sum((regexp_substr(processingFirst.data, '\d') || regexp_substr(processingLast.data, '\d'))::int) as secondStar
from processingFirst inner join processingLast on
	processingFirst.id = processingLast.id
;

/* Things I learned:
 *
 *  - last_value and first_value window functions are uesless without a range
 *  (and I learned how to define a range for a window function. unbounded
 *  preceding means the range starts at the beginning of the partition and
 *  unbounded following means the range stops at the end of the partition. IMHO,
 *  that should be the default, but they never ask me ¯\_(ツ)_/¯
 *
 *  - there is a function to reverse a string. I don't see a straightforward
 *  usage for that in a "normal" data model (meaning, where your text column is
 *  actually human text)
 *
 *  - regexp_substr is cool
 *
 *  - You can't use an outer join to call the CTE in recursive CTE (which kind
 *  of makes sense, once you think of it).
 */
