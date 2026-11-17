drop table input04;
/* Insert data into  table */
create table input04 (
  id integer generated always as identity,
  rawData text
  );

/* Please use psql, the best PostgreSQL client */
\copy input04(rawData) from 'input.csv';


/* Add a blank line at the end just to consider the last passport record.*/
insert into input04(rawData) values ('');

/* The difficulty is to consider the empty line as a sepration. So I need to
 * find the blank lines ids */
with blank_lines as (
  select id,
    coalesce(lag(id) over (order by id), 0) as previousId
  from input04
  where rawData = ''
  order by id
),
/* With the blank line ids, I'm able to select the records for a password */
data as (
  select blank_lines.id,
         /* I need a rank for each blank_line id, so that means window functions
         * */
         dense_rank() over (partition by blank_lines.id order by input04.id) as num,
         input04.rawData
  from input04
    inner join
       blank_lines
    on input04.id > blank_lines.previousId
    and input04.id < blank_lines.id
  order by input04.id),
/* Now, I need to transpose the data. I will assume there will be no more than
 * 8 rows as there shouldn't be more than 8 fields. Maybe that's wrong... */
transposedData as (
  select id,
    /* Now that I have a rank, I can transpose my rows into columns */
    coalesce(case when num=1 then rawdata end,
      case when num=2 then rawdata end,
      case when num=3 then rawdata end,
      case when num=4 then rawdata end,
      case when num=5 then rawdata end,
      case when num=6 then rawdata end,
      case when num=7 then rawdata end,
      case when num=8 then rawdata end) as data
  from data),
/* Now, I can get my passport data nicely */
passports as (
  select id,
    /* and now we just need to concat the strings */
    string_agg(data, ' ' order by id) as data
  from transposedData
  group by id
  order by id
)
/* Now, calculating part one is easy */
select count(*) as resultPartOne
from passports
where
    /* check the fields with regular expressions */
    data ~ 'byr:'
  and
    data ~ 'iyr:'
  and
    data ~ 'eyr:'
  and
    data ~ 'hgt:'
  and
    data ~ 'hcl:'
  and
    data ~ 'ecl:'
  and
    data ~ 'pid:'
;


/* The difficulty is to consider the empty line as a sepration. So I need to
 * find the blank lines ids */
with blank_lines as (
  select id,
    coalesce(lag(id) over (order by id), 0) as previousId
  from input04
  where rawData = ''
  order by id
),
/* With the blank line ids, I'm able to select the records for a password */
data as (
  select blank_lines.id,
         /* I need a rank for each blank_line id, so that means window functions
         * */
         dense_rank() over (partition by blank_lines.id order by input04.id) as num,
         input04.rawData
  from input04
    inner join
       blank_lines
    on input04.id > blank_lines.previousId
    and input04.id < blank_lines.id
  order by input04.id),
/* Now, I need to transpose the data. I will assume there will be no more than
 * 8 rows as there shouldn't be more than 8 fields. Maybe that's wrong... */
transposedData as (
  select id,
    /* Now that I have a rank, I can transpose my rows into columns */
    coalesce(case when num=1 then rawdata end,
      case when num=2 then rawdata end,
      case when num=3 then rawdata end,
      case when num=4 then rawdata end,
      case when num=5 then rawdata end,
      case when num=6 then rawdata end,
      case when num=7 then rawdata end,
      case when num=8 then rawdata end) as data
  from data),
/* Now, I can get my passport data nicely */
passports as (
  select id,
    /* and now we just need to concat the strings */
    string_agg(data, ' ' order by id) as data
  from transposedData
  group by id
  order by id
),
/* I'll create a table with all the fields an basic verification on the fields.
 * Should the verification fail, null will be added instead */
passporttable as (
  select
    /* byr, iyr and eyr are years on 4 digits */
    case when data ~ 'byr:\d{4}( |$)' then
      split_part((regexp_match(data, 'byr:\d{4}'))[1],':',2)::int end as byr,
    case when data ~ 'iyr:\d{4}( |$)' then
      split_part((regexp_match(data, 'iyr:\d{4}'))[1],':',2)::int end as iyr,
    case when data ~ 'eyr:\d{4}( |$)' then
      split_part((regexp_match(data, 'eyr:\d{4}'))[1],':',2)::int end as eyr,
    /* Height is a number followed by cm or in */
    case when data ~ 'hgt:\d+(cm|in)( |$)' then
      split_part((coalesce(regexp_match(data, 'hgt:\d+cm'),
                           regexp_match(data, 'hgt:\d+in')))[1],':',2) end as hgt,
    /* hcl (Hair Color) - a # followed by exactly six characters 0-9 or a-f */
    case when data ~ 'hcl:#[0-9a-f]{6}( |$)' then
      split_part((regexp_match(data, 'hcl:#[0-9a-f]{6}'))[1],':',2) end as hcl,
    /* ecl (Eye Color) - exactly one of: amb blu brn gry grn hzl oth */
    case when data ~ 'ecl:\w{3}( |$)' then
      split_part((regexp_match(data,'ecl:\w{3}'))[1],':',2) end as ecl,
    /* pid (Passport ID) - a nine-digit number, including leading zeroes. */
    case when data ~ 'pid:\d{9}( |$)' then
      split_part((regexp_match(data, 'pid:\d{9}'))[1],':',2) end as pid
  from passports
)
select count(*) as resultPartTwo
from passporttable
where
    /* byr at least 1920 and at most 2002 */
    byr >= 1920 and byr <= 2002
  and
    /* iyr at least 2010 and at most 2020 */
    iyr >= 2010 and iyr <= 2020
  and
    /* eyr at least 2020 and at most 2030 */
    eyr >= 2020 and eyr <= 2030
  and
    /* If cm, the number must be at least 150 and at most 193 */
    case when hgt ~ 'cm'
    then (regexp_match(hgt, '\d+'))[1]::integer >= 150
      and (regexp_match(hgt, '\d+'))[1]::integer <= 193
    /* If in, the number must be at least 59 and at most 76 */
    when hgt ~ 'in'
    then  (regexp_match(hgt, '\d+'))[1]::integer >= 59
      and (regexp_match(hgt, '\d+'))[1]::integer <= 76
    end
  and
    /* ecl exactly one of: amb blu brn gry grn hzl oth */
    ecl in ('amb', 'blu', 'brn', 'gry', 'grn', 'hzl', 'oth')
    /* we still need our mandatory fields */
  and hcl is not null
  and pid is not null
;
