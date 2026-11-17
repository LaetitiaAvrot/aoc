/* Insert data into temporary table */
/* The generated column is not mandatory, but I wanted to test that new Postgres
 * feature. */
create temporary table module
  (mass integer,
  fuel integer generated always as ((mass/3)-2) stored);

/* Please use psql, the best PostgreSQL client */
\copy module(mass) from 'input.csv';

/* Creating the query to know how much fuel is needed */
/* Fuel required to launch a given module is based on its mass. Specifically, to
 * find the fuel required for a module, take its mass, divide by three, round
 * down, and subtract 2. */
/* We don't need to round down because when you divide an integer with the
 * / operator, it's already rounded down to the next integer. */
select sum(fuel) as part1
from module;

/* For part 2, we just need to add that to a recursive query */
with recursive fuel_needed(fuel) as (
    /* You can't use the previous result because of rounding up whwn dividing by
     * 3. You need for each module to calculate how much fuel is needed for that
     * module and then the fuel needed for that fuel etc */
    select fuel
    from module
  union all
    /* Calculate then the fuel needed for the fuel and the the fuel needed for
     * the fuel needed for the fuel etc */
    select ((fuel/3)-2)
    from fuel_needed
    where fuel > 0
)
/* We need to add all those numbers, change that select into a select * if you
 * want to see the result of the recursive cte */
select sum(fuel) as part2
from fuel_needed
/* The last value calculated can be a negative number, we need to be sure we
 * won't sum that value or our calculation will be wrong */
where fuel > 0;

/* Deleting everything afterwards */
/* Not really necessary as temporary tables are dropped at the end of the
 * session, but I'd rather drop my temporary tables explicitely.
 * On the "+" side, this make this script idempotent. */
drop table module;
