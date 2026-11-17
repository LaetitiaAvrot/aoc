/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  value text,
  pocket1 text generated always as (substring(value for length(value)/2)) stored,
  pocket2 text generated always as (substring(value from length(value)/2+1)) stored
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

with missplaced(item) as (
  select regexp_substr(pocket1,'[' || pocket2 || ']')
  from input
)
select
  sum(
    /* Ascii values for a to z are 97 to 122 */
    /* Ascii values for A to Z are 65 to 90 */
    case when upper(item) = item
      then ascii(item) - 38
      else ascii(item) - 96
    end
  ) as firstStar
from missplaced;

with badgefirstIteration(id,common) as (
  select
    id,
    /* Looking for the common item between the 2 first elves' bags */
    regexp_matches(
      value,
      '[' || lead(value) over(order by id) || ']',
      'g') as common
  from input
),
badge(id, priority) as (
  select
    input.id,
    regexp_substr(
      lead(value,2) over(order by input.id),
      '[' ||
      string_agg(array_to_string(common,''),'')
      || ']') as priority
  from badgefirstIteration
    /* to get the last value, we need to right join with input */
    right join input
      on badgefirstIteration.id = input.id
  group by input.id, value
)
select 
  sum(
    /* Ascii values for a to z are 97 to 122 */
    /* Ascii values for A to Z are 65 to 90 */
    case when upper(priority) = priority
      then ascii(priority) - 38
      else ascii(priority) - 96
    end
  ) as partTwo
from badge
where id%3=1;
