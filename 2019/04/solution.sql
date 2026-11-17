/* Please use psql, the best postgreSQL client! */
\set input1 178416
\set input2 676461

create temporary table password
(
  p integer,
  a integer generated always as (substring(p::text from 1 for 1)::integer) stored,
  b integer generated always as (substring(p::text from 2 for 1)::integer) stored,
  c integer generated always as (substring(p::text from 3 for 1)::integer) stored,
  d integer generated always as (substring(p::text from 4 for 1)::integer) stored,
  e integer generated always as (substring(p::text from 5 for 1)::integer) stored,
  f integer generated always as (substring(p::text from 6 for 1)::integer) stored
);

insert into  password(p)
(
  select *
  from generate_series(:input1, :input2)
);

select count(*) as part1
from password
where
  /* Two adjacent digits are the same */
  p::text similar to '%(00|11|22|33|44|55|66|77|88|99)%'
and
  /* Going from left to right, the digits never decrease */
  a <= b and b <= c and c <= d and d <= e and e <= f;

select count(*) as part2
from password
where
  /* Two adjacent digits are the same */
  p::text similar to '%(00|11|22|33|44|55|66|77|88|99)%'
and
  /* Going from left to right, the digits never decrease */
  a <= b and b <= c and c <= d and d <= e and e <= f
and
  /* the two adjacent matching digits are not part of a larger group of matching
   * digits */
    (p::text not similar to  '%(000|111|222|333|444|555|666|777|888|999)%'
      or (p::text similar to '%(000|111|222|333|444|555|666|777|888|999)%(00|11|22|33|44|55|66|77|88|99)%'
        and p::text not similar to '%(0000|1111|2222|3333|4444|5555|6666|7777|8888|9999)%'
        and p::text not similar to '(000|111|222|333|444|555|666|777|888|999)%(000|111|222|333|444|555|666|777|888|999)')
      or (p::text similar to '%(00|11|22|33|44|55|66|77|88|99)%(000|111|222|333|444|555|666|777|888|999)%'
        and p::text not similar to '%(0000|1111|2222|3333|4444|5555|6666|7777|8888|9999)%'
        and p::text not similar to '(000|111|222|333|444|555|666|777|888|999)%(000|111|222|333|444|555|666|777|888|999)')
      or (p::text similar to '(0000|1111|2222|3333|4444|5555|6666|7777|8888|9999)(00|11|22|33|44|55|66|77|88|99)'
        and p::text not similar to '%(000000|111111|222222|333333|444444|555555|666666|777777|888888|999999)%')
      or (p::text similar to '(00|11|22|33|44|55|66|77|88|99)(0000|1111|2222|3333|4444|5555|6666|7777|8888|9999)'
        and p::text not similar to '%(000000|111111|222222|333333|444444|555555|666666|777777|888888|999999)%')
    )
;

drop table password;
