/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc25 cascade;
create schema aoc25;
set search_path to 'aoc25';

/* Insert data into  table */
create table input (
  id integer generated always as identity primary key,
  data text not null
);

\copy input(data) from 'input.csv';

create function snafuToDec(snafu text) returns bigint as
$snafuToDec$
  with snafu(num, l) as (
    select string_to_array(snafu, null),
      char_length(snafu)
  )
  select sum(
      (case when element = '-' then '-1'
      when element = '=' then '-2'
      else element
      end)::bigint
      *
      power(5, l-idx)
    )
  from snafu, unnest(num) with ordinality as a(element, idx);
$snafuToDec$ immutable language sql;

alter table input add column decNumber bigint generated always as (
  snafuToDec(data)) stored;
create table power5 (num bigint, pow integer);
insert into power5 (num,pow) (
  select power(5,n), n
  from generate_series(1,26) t(n)
);

create function pow5(myNumber bigint) returns text as
$pow5$
  with recursive processignpow5(x, num, pow, div, remain, snafu) as (
    (
      /* Get the highest power of 5 */
      select myNumber as x,
        num,
        pow,
        myNumber/num as div,
        myNumber%num as remain,
        (myNumber/num)::text as snafu
      from power5
      where myNumber/num > 0
      order by num desc
      limit 1)
    union all
    (
      select x,
        power5.num,
        power5.pow,
        processignpow5.remain/power5.num as div,
        processignpow5.remain%power5.num as remain,
        processignpow5.snafu || (processignpow5.remain/power5.num)::text
      from processignpow5
        inner join power5
          on processignpow5.pow-1 = power5.pow)
  )
  /* To make the snafu conversion easier, let's add a 0 in the front */
  select '0' || snafu || remain::text
  from processignpow5
  order by num
  limit 1
  ;
$pow5$ language sql;

create function snafu(mydec5 text) returns text as 
$snafu$
  with recursive snafu(n, pow5, snafu) as (
    select 1 as n,
      /* If we have a number over 2 as a last digit, then we need to increase
       * the "new" last digit.
       * By increasing that number we might reach 5, which is bad, obvisouly as
       * this is a number on base 5.
       * So, we then need to increate the next digit and put 0 instead as a last
       * digit.
       * That way, we should never get 5 in the snafu digit */
      case when pow5[array_length(pow5,1)]::int > 2 and array_length(pow5,1) > 3
	/* Now we can safely take into account what happens should we have
	 * a 5 digit as a last number in our array */
        then
          case
            when pow5[array_length(pow5,1)-1] = '4'
	      then pow5[1:array_length(pow5,1)-3] || (pow5[array_length(pow5,1)-2]::int+1)::text || array['0']
	    else pow5[1:array_length(pow5,1)-2] || (pow5[array_length(pow5,1)-1]::int+1)::text
	  end
      /* We know we will never get 5 as the digit last digit shouldthe array
       * length be 1 because we on purpose added a 0 in front of the base
       * 5 number we had converted. */	
      when pow5[array_length(pow5,1)]::int > 2 and array_length(pow5,1) = 2
	then array[pow5[1]] || (pow5[2]::int+1)::text
      when pow5[array_length(pow5,1)]::int > 2 and array_length(pow5,1) = 3
        then
          case
            when pow5[array_length(pow5,1)-1] = '4'
	      then array[pow5[1]] || (pow5[2]::int+1)::text || array['0']
	    else array[pow5[1]] || (pow5[2]::int+1)::text || pow5[3]
	  end
      else pow5[1:array_length(pow5,1)-1]
      end as pow5,
      case when pow5[array_length(pow5,1)]::int < 3 then pow5[array_length(pow5,1)]
        when pow5[array_length(pow5,1)]::int = 3 then '='
        when pow5[array_length(pow5,1)]::int = 4 then '-'
      end as snafu
    from (select string_to_array('013140400422344032342', null)) as finalpow5(pow5)
    union all
    select n+1,
      case when pow5[array_length(pow5,1)]::int > 2
        then pow5[1:array_length(pow5,1)-2] || (pow5[array_length(pow5,1)-1]::int+1)::text
      else pow5[1:array_length(pow5,1)-1]
      end as pow5,
      (case when pow5[array_length(pow5,1)]::int < 3 then pow5[array_length(pow5,1)]
        when pow5[array_length(pow5,1)]::int = 3 then '='
        when pow5[array_length(pow5,1)]::int = 4 then '-'
	/* Due to the treatment from before round, we can end up with 5, so we
	 * need to take that into account */
        when pow5[array_length(pow5,1)]::int = 5 then '0'
      end) || snafu.snafu as snafu
    from snafu
    where array_length(pow5,1) > 0
  )
  select
    case when substring(snafu from 1 for 1) = '0'
      then substring(snafu from 2)
    else snafu
    end as firstStar
  from snafu
  where snafu is not null
  order by n desc
  limit 1
  ;
$snafu$ language sql;

select snafu(pow5(sum(decNumber)::bigint)) as firstStar
from input;

