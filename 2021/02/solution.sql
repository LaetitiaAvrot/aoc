/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  direction text,
  unit integer,
  horizontalMove integer
    generated always as (
      /* It can only go forward, not backward, so we just need to use the unit
       * number as horizontalMove if the direction is "forward"*/
      case direction
      when 'forward' then unit
      end
    ) stored,
  verticalMove integer
    generated always as (
      /* down X increases the depth by X units and up X decreases the depth by X
       *  units which neabs if down, we keep the unit, if up, we just use unit * -1.
       * */
       case direction
       when 'up' then -1*unit
       when 'down' then unit
       end
    ) stored
  );

/* Please use psql, the best PostgreSQL client */
\copy input(direction, unit) from 'input.csv' with delimiter ' ';


/* Now that Postgres has decoded the values, we just have to sum them and
 * multiply the results together */
select sum(horizontalMove) * sum(verticalMove) as resultPartOne
from input;

/* It seems we have to do a recursive query for Part two*/

with recursive data(id, direction, unit, horizontalMove, verticalMove, aim) as (
  select id, direction, unit, horizontalMove, verticalMove, 0 as aim
  from input
  where id = 1
  union all
  select input.id, input.direction, input.unit, input.horizontalMove,
  /* Forward will increase the depth by X * previous aim */
  case input.direction
  when 'forward'
    then data.aim * input.unit
  /* depth does not change if 'up' or 'down' is issued so no else condition */
  end as verticalMove,
  /* Aim will only be changed by up and down directions */
  case input.direction
  when 'up' then data.aim - input.unit
  when 'down' then data.aim + input.unit
  /* We still have to copy the old value of aim if it does not change */
  else data.aim
  end as aim
  from input inner join data
    on input.id = data.id+1
)
/* Now that Postgres has decoded the values, we just have to sum them and
 * multiply the results together */
select sum(horizontalMove) * sum(verticalMove) as resultPartTwo
from data;
