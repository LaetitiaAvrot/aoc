/* Insert data into  table */ 
create table input02 (
  id integer generated always as identity,
  rawPolicy text,
  rawLetter text,
  password text,
  policy int4range,
  letter text generated always as (substring(rawLetter,1,1)) stored,
  position1 integer,
  position2 integer
  );

/* Please use psql, the best PostgreSQL client */
\copy input02(rawPolicy, rawLetter, password) from 'input.csv' with (delimiter ' ');

/* Cleaning the policy to get an integer range instead of text */
with myPolicyArrays as (
  select id, regexp_split_to_array(rawPolicy, '-') as policyArray
  from input02)
update input02
/* ranges in Postgres are inclusive from the left side and exclusive from the
 * right side */
set policy = int4range(policyArray[1]::integer, policyArray[2]::integer + 1),
/* update tge mustContain and mustNotContain columns (for the second part) */
    position1 = policyArray[1]::integer,
    position2 = policyArray[2]::integer
from myPolicyArrays
where input02.id = myPolicyArrays.id;


/* Find the number of occurence of each letter in each password and compare that
 * to the range given. */
select
  count(*) as resultPartOne
from input02
where
  /* We want to know if the number of occurence of a letter is inside the range
   * */
  policy @>
  /* Array length will give us the size of the array */
  array_length(
    /* We're looking for all the positions of the letter in the password */
    array_positions(
      /* We change our string into an array of characters */
      string_to_array(password, null),
      letter),
    /* We want the size for the first dimension of this array */
    1)
;

select
  count(*) as resultPartTwo
from input02
where
  /* We want the letter to be either at position1 or position2 but not both */
  ((string_to_array(password, null))[position1] = letter
  or
  (string_to_array(password, null))[position2] = letter)
  /* if one of the position is filled with the letter, we simply don't want the
   * second position to be filled with the same letter */
  and (string_to_array(password, null))[position1] <> (string_to_array(password, null))[position2]
;
