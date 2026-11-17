/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc_YEAR_DAY cascade;
create schema aoc_YEAR_DAY;
set search_path to 'aoc_YEAR_DAY';

/* Insert data into table */
create table input (
  id integer generated always as identity primary key,
  data text not null
);

\copy input(data) from 'input.csv';

/* Part 1 */

/* Part 2 */
