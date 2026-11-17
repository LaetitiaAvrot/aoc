/* Insert data into  table */
create table input07 (
  id integer generated always as identity,
  rawData text,
  /* This should get the container color */
  containerColor text generated always as (
    (regexp_split_to_array(
      (regexp_split_to_array(rawData, 'contain'))[1], ' bags')
    )[1]
  ) stored,
  /* This should get the bags the container contains, with their numbers and
   * colors */
  contentColors text[] generated always as (
    regexp_split_to_array((regexp_split_to_array(rawData, 'contain'))[2], ',')
  ) stored
  );

/* Please use psql, the best PostgreSQL client */
\copy input07(rawData) from 'input.csv';

/* For part 1, we need to refine the input data to find which bag goes into
 * which other bag */
with recursive bags as (
select
  id,
  containerColor,
  /* This should isolate the color of the bags */
  (regexp_split_to_array(
    (regexp_split_to_array(trim(l), '\d+ '))[2],
    ' bag')
  )[1] as containedColor
from input07,
  lateral unnest(contentColors) as l
),
/* Here is my recursive with list element */
bagsAndContainer as (
  /* First we need to store our shiny gold bag */
  select array_append(array[containedColor], containerColor) as bags,
    containerColor as container
  from bags
  where containedColor = 'shiny gold'
  union all
  /* Then we will find recursively what bag can hold the previous one */
  select array_append(bagsAndContainer.bags, containerColor) as bags,
    bags.containerColor as container
  from bagsAndContainer
    inner join bags
      on bagsAndContainer.bags[cardinality(bagsAndContainer.bags)] = bags.containedColor
)
/* If we simply count the number of rows, we'll  have some duplicates as in the
 * example, the dark orange holing the bright white which then holds the shiny
 * gold one is considered the same as the dark orange holding the muted yellow
 * which then holds the shiny gold bag */
/* So I will consider only the last bag with a distinct to count it only once */
select count(
    distinct bagsAndContainer.bags[cardinality(bagsAndContainer.bags)]
  ) as resultPartOne
from bagsAndContainer;

/* I will need a aggregate function similar to sum, but I'd like to aggregate my
 * values by multiplying them */
create aggregate mul(bigint) ( sfunc = int8mul, stype=bigint );

/* For the second star we need the recursion on the other way around, so we'll
 * change the container and content in our recursive with list element */
with recursive bags as (
select
  id,
  containerColor,
  /* This should isolate the color of the bags */
  (regexp_split_to_array(
    (regexp_split_to_array(trim(l), '\d+ '))[2],
    ' bag')
  )[1] as containedColor,
  /* this shoud isolate the number of bags */
  case when (regexp_split_to_array(trim(l), ' '))[1] = 'no' 
    then 0
    else (regexp_split_to_array(trim(l), ' '))[1]::integer
  end as numberOfBags
from input07,
  lateral unnest(contentColors) as l
),
/* Here is my recursive with list element */
bagsAndContained as (
  select array_append(array[containerColor], containedColor) as bags,
    containedColor as contained,
    /* I'll add the number of bags */
    array_append(array[1], numberOfBags) as numbers
  from bags
  where containerColor = 'shiny gold'
  union all
  select array_append(bagsAndContained.bags, containedColor) as bags,
    bags.containedColor as contained,
    array_append(bagsAndContained.numbers,numberOfBags) as numbers
  from bagsAndContained
    inner join bags
      on bagsAndContained.bags[cardinality(bagsAndContained.bags)] = bags.containerColor
),
numbers as (
select bagsAndContained.numbers,
    row_number() over (order by bagsAndContained.bags) as num
from bagsAndContained
  /* We need the whole sequences only, so the last element of numbers should be
   * 0 (or the last element of containedColor needs to be null */
  where bagsAndContained.numbers[cardinality(bagsAndContained.numbers)] <> 0
),
/* I need to multiply the number of bags by the number of their containers and
 * so on */
multiplied as (
  select mul(l) as m,
    num
  from numbers,
    lateral unnest(array_remove(numbers,0)) as l
  group by num
)
/* And now, I just need to sum them all */
select sum(multiplied.m) as resultPartTow
from multiplied;
;
