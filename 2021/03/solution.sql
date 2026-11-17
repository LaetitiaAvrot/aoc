/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  diagnostic text
  );

/* Please use psql, the best PostgreSQL client */
\copy input(diagnostic) from 'input.csv' with delimiter ' ';

/* Calculate gamma and epsilon rates.
 * first part will be getting 12 values (one for each of the text column.
 * Then we'll calculate the gamma_rate by concatenating the bits and we'll take
 * the inverse bit string to get the epsilon rate.
 * */
with data(id,v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12) as (
  select id,
    /* This code is totally stupid but don't overcomplicate things. It will only
     * work for at most 12 columns diagnostic reports */
    (regexp_split_to_array(diagnostic,''))[1],
    (regexp_split_to_array(diagnostic,''))[2],
    (regexp_split_to_array(diagnostic,''))[3],
    (regexp_split_to_array(diagnostic,''))[4],
    (regexp_split_to_array(diagnostic,''))[5],
    (regexp_split_to_array(diagnostic,''))[6],
    (regexp_split_to_array(diagnostic,''))[7],
    (regexp_split_to_array(diagnostic,''))[8],
    (regexp_split_to_array(diagnostic,''))[9],
    (regexp_split_to_array(diagnostic,''))[10],
    (regexp_split_to_array(diagnostic,''))[11],
    (regexp_split_to_array(diagnostic,''))[12]
  from input
),
  computed(gamma_rate) as (
  /* We'll use the id to get the position of the numbers computed so we can decode
   * the binary number */
  select
    /* count(*) filter (where v1 = 1) will get the number opf 1 in v1, so we
     * "just" * need to compare it with the number of 0, but 1 should be chosen
     * if there's an equal number, that's why I had to reverse my case when
     * conditions compared to start 1 */
    (case
      when count(*) filter (where v1 = '1') < count(*) filter (where v1 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v2 = '1') < count(*) filter (where v2 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v3 = '1') < count(*) filter (where v3 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v4 = '1') < count(*) filter (where v4 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v5 = '1') < count(*) filter (where v5 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v6 = '1') < count(*) filter (where v6 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v7 = '1') < count(*) filter (where v7 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v8 = '1') < count(*) filter (where v8 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v9 = '1') < count(*) filter (where v9 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v10 = '1') < count(*) filter (where v10 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v11 = '1') < count(*) filter (where v11 = '0') then '0'
      else '1'
    end
    ||
    case
      when count(*) filter (where v12 = '1') < count(*) filter (where v12 = '0') then '0'
      else '1'
    end)::bit(12) as gamma_rate
  from data
)
select gamma_rate::integer *
  /* Use a bitwise exclusive Or to find espilon_rate */
  (gamma_rate # '111111111111'::bit(12))::integer
    as resultPartOne
from computed
;

/* Part 2 is basically calculating epsilon or gamma on a changing input set */
/* We need still need to focus on columns instead of rows.
 *
 * Considering the input
 * 00100
 * 11110
 * 10110
 * 10111
 * 10101
 * 01111
 * 00111
 * 11100
 * 10000
 * 11001
 * 00010
 * 01010
 *
 * We can't use mode as it will take a random value if both values are equals
 * on the first column */

create or replace function compute_oxygen_generator_rating(
  iterration integer,
  pattern text,
  report text[]
)
returns text[] as
$compute_oxygen_generator_rating$
  with computedpattern(x) as (
    select
      /* Computing the nth bit for the pattern of oxygen generator rating */
      case
        when count(*) filter (where (regexp_split_to_array(diagnostic,''))[iterration] = '1')
           < count(*) filter (where (regexp_split_to_array(diagnostic,''))[iterration] = '0')
          then '0'
        else '1'
      end
    from unnest(report) as input(diagnostic)
  )
  select
    case
      /* Stop when there's no row. In that case take the previous row */
      when count(*) = 0 then report
      /* Else we just take the remaining rows aggregated in an array */
      else array_agg(diagnostic)
    end
  from  unnest(report) as input(diagnostic)
    inner join computedpattern
      /* Simple pattern matching with a concatenation of '^' (begin of string)
       * all the bits previsouly computed for the pattern and the newly computed
       * bit */
      on input.diagnostic ~ ('^' || pattern || computedpattern.x)
  ;
$compute_oxygen_generator_rating$
language sql;

create or replace function compute_co2_scrubber_rating(
  iterration integer,
  pattern text,
  report text[]
)
returns text[] as
$compute_co2_scrubber_rating$
  with computedpattern(x) as (
    select
      /* Computing the nth bit for the pattern of oxygen generator rating */
      case
        when count(*) filter (where (regexp_split_to_array(diagnostic,''))[iterration] = '1')
           >= count(*) filter (where (regexp_split_to_array(diagnostic,''))[iterration] = '0')
          then '0'
        else '1'
      end
    from unnest(report) as input(diagnostic)
  )
  select
    case
      /* Stop when there's no row. In that case take the previous row */
      when count(*) = 0 then report
      /* Else we just take the remaining rows aggregated in an array */
      else array_agg(diagnostic)
    end
  from  unnest(report) as input(diagnostic)
    inner join computedpattern
      /* Simple pattern matching with a concatenation of '^' (begin of string)
       * all the bits previsouly computed for the pattern and the newly computed
       * bit */
      on input.diagnostic ~ ('^' || pattern || computedpattern.x)
  ;
$compute_co2_scrubber_rating$
language sql;

with o2_1(diagnostic) as (
  select compute_oxygen_generator_rating( 1, '', array_agg(rpad(diagnostic,12,'0')))
  from input
),
o2_2(diagnostic) as (
  select compute_oxygen_generator_rating( 2,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 1),
    diagnostic)
  from o2_1
),
o2_3(diagnostic) as (
  select compute_oxygen_generator_rating( 3,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 2),
    diagnostic)
  from o2_2
),
o2_4(diagnostic) as (
  select compute_oxygen_generator_rating( 4,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 3),
    diagnostic)
  from o2_3
),
o2_5(diagnostic) as (
  select compute_oxygen_generator_rating( 5,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 4),
    diagnostic)
  from o2_4
),
o2_6(diagnostic) as (
  select compute_oxygen_generator_rating( 6,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 5),
    diagnostic)
  from o2_5
),
o2_7(diagnostic) as (
  select compute_oxygen_generator_rating( 7,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 6),
    diagnostic)
  from o2_6
),
o2_8(diagnostic) as (
  select compute_oxygen_generator_rating( 8,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 7),
    diagnostic)
  from o2_7
),
o2_9(diagnostic) as (
  select compute_oxygen_generator_rating( 9,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 8),
    diagnostic)
  from o2_8
),
o2_10(diagnostic) as (
  select compute_oxygen_generator_rating( 10,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 9),
    diagnostic)
  from o2_9
),
o2_11(diagnostic) as (
  select compute_oxygen_generator_rating( 11,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 10),
    diagnostic)
  from o2_10
),
co2_1(diagnostic) as (
  select compute_co2_scrubber_rating( 1, '', array_agg(rpad(diagnostic,12,'0')))
  from input
),
co2_2(diagnostic) as (
  select compute_co2_scrubber_rating( 2,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 1),
    diagnostic)
  from co2_1
),
co2_3(diagnostic) as (
  select compute_co2_scrubber_rating( 3,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 2),
    diagnostic)
  from co2_2
),
co2_4(diagnostic) as (
  select compute_co2_scrubber_rating( 4,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 3),
    diagnostic)
  from co2_3
),
co2_5(diagnostic) as (
  select compute_co2_scrubber_rating( 5,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 4),
    diagnostic)
  from co2_4
),
co2_6(diagnostic) as (
  select compute_co2_scrubber_rating( 6,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 5),
    diagnostic)
  from co2_5
),
co2_7(diagnostic) as (
  select compute_co2_scrubber_rating( 7,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 6),
    diagnostic)
  from co2_6
),
co2_8(diagnostic) as (
  select compute_co2_scrubber_rating( 8,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 7),
    diagnostic)
  from co2_7
),
co2_9(diagnostic) as (
  select compute_co2_scrubber_rating( 9,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 8),
    diagnostic)
  from co2_8
),
co2_10(diagnostic) as (
  select compute_co2_scrubber_rating( 10,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 9),
    diagnostic)
  from co2_9
),
co2_11(diagnostic) as (
  select compute_co2_scrubber_rating( 11,
    /* normally each string in diagnostic should match the pattern */
    substring(diagnostic[1] from 1 for 10),
    diagnostic)
  from co2_10
)
select
  ((compute_oxygen_generator_rating( 12,
    /* normally each string in diagnostic should match the pattern */
    substring(o2_11.diagnostic[1] from 1 for 11),
    o2_11.diagnostic))[1]::bit(12))::integer
  *
  ((compute_co2_scrubber_rating( 12,
    /* normally each string in diagnostic should match the pattern */
    substring(co2_11.diagnostic[1] from 1 for 11),
    co2_11.diagnostic))[1]::bit(12))::integer
 as resultPartTwo
from co2_11,
  /* Cartesian product with a one row table */
  o2_11
;
