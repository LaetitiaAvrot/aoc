/* Insert data into  table */ 
create table input01 (
  id integer generated always as identity,
  v integer
  );

/* Please use psql, the best PostgreSQL client */
\copy input01(v) from 'input.csv';

/* Creating the query, we need to create a cartesian product with the table and
 * the table itself and find out which
 * sum result is 2020. We need to exclude summing a number with itself.
 * The result we want is the multiplication of the 2 numbers found. 
 * The program will calculate the result twice, once with n1.v*n2.v and a second
 * time with n2.v*n1.v */
select distinct n1.v * n2.v as resultPartOne
from input01 as n1
  cross join input01 as n2
where n1.id <> n2.id -- excluding summing a number with itself
  and n1.v + n2.v = 2020;

/* Part 2 is the same, but using 3 numbers instead of 2 */
select distinct n1.v * n2.v * n3.v as resultPartTwo
from input01 as n1
  cross join input01 as n2
  cross join input01 as n3
where n1.id <> n2.id -- excluding summing a number with itself
  and  n3.id <> n2.id -- excluding summing a number with itself
  and  n3.id <> n1.id -- excluding summing a number with itself
  and n1.v + n2.v + n3.v = 2020;

