/* Insert data into  table */
create table input06 (
  id integer generated always as identity,
  rawData text
  );

/* Please use psql, the best PostgreSQL client */
\copy input06(rawData) from 'input.csv';

/* Instead of doing as for Day 4 to assemble the data of each group, I'll use
 * xocolatl's way of doing Day 4 which is more simple and smart. */
/* This first CTE will give me the groups with several rows for each group */
with input (grp, value) as (
    select coalesce(
             max(id) filter (where rawData = '')
               over (order by id),
           1) as grp,
           r as value
    from input06,
         lateral regexp_split_to_table(rawData, ' ') AS r
),
/* This second CTE will aggregate all the answers of each person in the group
 * into one single string, so that after suming the answer will be simple */
groups (grp, data) as (
    select grp, string_agg(value, null)
    from input
    group by grp
)
select
  sum(
    case when data ~ 'a' then 1 else 0 end +
    case when data ~ 'b' then 1 else 0 end +
    case when data ~ 'c' then 1 else 0 end +
    case when data ~ 'd' then 1 else 0 end +
    case when data ~ 'e' then 1 else 0 end +
    case when data ~ 'f' then 1 else 0 end +
    case when data ~ 'g' then 1 else 0 end +
    case when data ~ 'h' then 1 else 0 end +
    case when data ~ 'i' then 1 else 0 end +
    case when data ~ 'j' then 1 else 0 end +
    case when data ~ 'k' then 1 else 0 end +
    case when data ~ 'l' then 1 else 0 end +
    case when data ~ 'm' then 1 else 0 end +
    case when data ~ 'n' then 1 else 0 end +
    case when data ~ 'o' then 1 else 0 end +
    case when data ~ 'p' then 1 else 0 end +
    case when data ~ 'q' then 1 else 0 end +
    case when data ~ 'r' then 1 else 0 end +
    case when data ~ 's' then 1 else 0 end +
    case when data ~ 't' then 1 else 0 end +
    case when data ~ 'u' then 1 else 0 end +
    case when data ~ 'v' then 1 else 0 end +
    case when data ~ 'w' then 1 else 0 end +
    case when data ~ 'x' then 1 else 0 end +
    case when data ~ 'y' then 1 else 0 end +
    case when data ~ 'z' then 1 else 0 end
  ) as resultPartOne
from groups
;

/* For the second star , I'll need to consider each person answer separately */
/* This first CTE will give me the groups with several rows for each group */
with input (id,grp, value) as (
    select
      id,
      coalesce(
        max(id) filter (where rawData = '') 
        over (order by id),
        1) as grp,
      r as value
    from input06,
         lateral regexp_split_to_table(rawData, ' ') as r
),
aggregate (total, grp) as (
  select
  /* Will use the bool_and aggregate function to find out if all the answers
   * of a group contain the same letter, and then we'll sum the values */
    case when bool_and(value ~ 'a') then 1 else 0 end +
    case when bool_and(value ~ 'b') then 1 else 0 end +
    case when bool_and(value ~ 'c') then 1 else 0 end +
    case when bool_and(value ~ 'd') then 1 else 0 end +
    case when bool_and(value ~ 'e') then 1 else 0 end +
    case when bool_and(value ~ 'f') then 1 else 0 end +
    case when bool_and(value ~ 'g') then 1 else 0 end +
    case when bool_and(value ~ 'h') then 1 else 0 end +
    case when bool_and(value ~ 'i') then 1 else 0 end +
    case when bool_and(value ~ 'j') then 1 else 0 end +
    case when bool_and(value ~ 'k') then 1 else 0 end +
    case when bool_and(value ~ 'l') then 1 else 0 end +
    case when bool_and(value ~ 'm') then 1 else 0 end +
    case when bool_and(value ~ 'n') then 1 else 0 end +
    case when bool_and(value ~ 'o') then 1 else 0 end +
    case when bool_and(value ~ 'p') then 1 else 0 end +
    case when bool_and(value ~ 'q') then 1 else 0 end +
    case when bool_and(value ~ 'r') then 1 else 0 end +
    case when bool_and(value ~ 's') then 1 else 0 end +
    case when bool_and(value ~ 't') then 1 else 0 end +
    case when bool_and(value ~ 'u') then 1 else 0 end +
    case when bool_and(value ~ 'v') then 1 else 0 end +
    case when bool_and(value ~ 'w') then 1 else 0 end +
    case when bool_and(value ~ 'x') then 1 else 0 end +
    case when bool_and(value ~ 'y') then 1 else 0 end +
    case when bool_and(value ~ 'z') then 1 else 0 end,
    grp
  from input
  where value <> ''
  group by grp
)
/* We just need to sum all the values */
select sum(total) as resultPartTwo
from aggregate;
