/* Insert data into  table */
create table input03 (
  id integer generated always as identity,
  pattern text,
  tree_positions integer[] generated always as (
    array_positions(string_to_array(pattern,null), '#')) stored
  );

/* Please use psql, the best PostgreSQL client */
\copy input03(pattern) from 'input.csv';

/* We won't need to store the repeated pattern as we'll play with modulos */
select
  count(*) as resultPartOne
from input03
where
    /* We don't need to look at the first position, obviously */
    id-1 > 0
  and
    /* We need to multiply the line number by 3 and divide it by
     * the pattern length and keep the modulo to find the position where we'll
     * land. We'll then compare that to the tree position.
     * Be carefull, we will begin at position 1, so we need to add 1 to initial
     * position, but our ids are the line numbers, instead of the jump number,
     * so that we need to retrieve 1 to it..
     * Another problem is tghe modulo operator will return 0 instead of 11, so
     * we will fix that with a case when statement.*/
    case when ((1+((id-1)*3)) % length(pattern) = 0) then
      array_position(tree_positions, length(pattern)) is not null
    else
      array_position(tree_positions, (1+((id-1)*3)) % length(pattern)) is not null
    end
;

/* Part 2,  I'll calculate the result for each slope and multiply the answer.
 * It's not smart, but shoul work */
with slope1 as (
  select
    count(*) as trees
  from input03
  where
    id-1 > 0
  and
    /* Adjust the formula for a "Right 1, down 1" slope */
    case when ((1+((id-1)*1)) % length(pattern) = 0) then
      array_position(tree_positions, length(pattern)) is not null
    else
      array_position(tree_positions, (1+((id-1)*1)) % length(pattern)) is not null
    end
  ),
slope2 as (
  select
    count(*) as trees
  from input03
  where
    id-1 > 0
  and
    case when ((1+((id-1)*3)) % length(pattern) = 0) then
      array_position(tree_positions, length(pattern)) is not null
    else
      array_position(tree_positions, (1+((id-1)*3)) % length(pattern)) is not null
    end
  ),
slope3 as (
  select
    count(*) as trees
  from input03
  where
    id-1 > 0
  and
    /* Adjust the formula for a "Right 5, down 1" slope */
    case when ((1+((id-1)*5)) % length(pattern) = 0) then
      array_position(tree_positions, length(pattern)) is not null
    else
      array_position(tree_positions, (1+((id-1)*5)) % length(pattern)) is not null
    end
  ),
slope4 as (
  select
    count(*) as trees
  from input03
  where
    id-1 > 0
  and
    /* Adjust the formula for a "Right 7, down 1" slope */
    case when ((1+((id-1)*7)) % length(pattern) = 0) then
      array_position(tree_positions, length(pattern)) is not null
    else
      array_position(tree_positions, (1+((id-1)*7)) % length(pattern)) is not null
    end
  ),
slope5 as (
  select
    count(*) as trees
  from input03
  where
    id-1 > 0
  and
    /* Adjust the formula for a "Right 1, down 2" slope.
     * We have an arithmetic suite where u(n) = u(n+1) + 0.5
     * And u(3) = 2
     * That means u(n) = 0.5 + n*0.5  */
    case when (((0.5+(id*0.5))::integer) % length(pattern) = 0) then
      array_position(tree_positions, length(pattern)) is not null
    else
      array_position(tree_positions, ((0.5+(id*0.5))::integer) % length(pattern)) is not null
    end
  and
    /* That's for the "down 2 part": we just need uneaven row numbers */
    id % 2 = 1
  )
/* I have to add the distinct due to the 5 cartesian products */
select distinct
  slope1.trees*
  slope2.trees*
  slope3.trees*
  slope4.trees*
  slope5.trees
from slope1, slope2, slope3, slope4, slope5;
