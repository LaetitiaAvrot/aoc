/* Making the script idempotent */
drop table if exists input;
drop function if exists moveOneCrate(text,text);
drop function if exists firstEmptySlot(text);
drop function if exists duplicateCrate(text, text, text);
drop function if exists deleteCrate(text, text, text);
drop function if exists getCrateIds(text,int);

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  value text,
  cat text generated always as (
    case when value ~ 'move' then 'moves'
      when value ~ ']' then 'crates'
      else null
    end) stored,
  /* I would need a generated default as (expression) here, but it is not
   * implemented in Postgres yet */
  crate1 char(1),
  crate2 char(1),
  crate3 char(1),
  crate4 char(1),
  crate5 char(1),
  crate6 char(1),
  crate7 char(1),
  crate8 char(1),
  crate9 char(1)
);


/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

/* Generate the crates first values */
update input
  set
    crate1 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 2 for 1),' ')
    end,
    crate2 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 6 for 1),' ')
    end,
    crate3 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 10 for 1),' ')
    end,
    crate4 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 14 for 1),' ')
    end,
    crate5 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 18 for 1),' ')
    end,
    crate6 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 22 for 1),' ')
    end,
    crate7 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 26 for 1),' ')
    end,
    crate8 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 30 for 1),' ')
    end,
    crate9 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 34 for 1),' ')
    end
  where
    cat='crates';

/* Add the rows needed to store all crates in one column, if needed */
insert into input(id,value)
  /* this should allow to write into the id column even though it was "generated
   * always as" */
  overriding system value
  (select generate_series(0,-1*(rows*9),-1),
    /* This should generate the category "crates" */
    ']'
  from (select count(*) from input where cat = 'crates') as t(rows))
;

create function firstEmptySlot(crateColumn text) returns text as
$firstEmptySlot$
  select
    $$select id from ($$ ||
    /* when it's not empty */
    $$(select id-1 as id from input where crate$$ || crateColumn ||
    $$ is not null and cat='crates' order by id limit 1) $$ ||
    $$union $$ ||
    /* when it's empty */
    $$(select max(id) as id from input where cat='crates')) as t(id) $$ ||
    $$order by id nulls last limit 1$$ as result;
$firstEmptySlot$ language SQL;

create function moveOneCrate(fromColumn text, toColumn text) returns text as
$moveOneCrate$
  select
    /* First let's copy the crate to the new Column */
    $$update input set crate$$ || toColumn ||
    $$ = (select crate$$ || fromColumn ||
    $$ from input where cat='crates' and crate$$ || fromColumn ||
    $$ is not null order by id limit 1) where id = ($$ || firstEmptySlot(toColumn) ||
    $$);$$ ||
    /* Now let's remove the crate from the old column */
    $$update input set crate$$ || fromColumn ||
    $$ = null where id = $$ ||
    $$(select id from input where crate$$ || fromColumn ||
    $$ is not null and cat='crates' order by id limit 1);$$ as result
  ;
$moveOneCrate$ language SQL;

/* We will use dynamic sql with \gexec . We don't want to have all the update
 * messages */
\set QUIET on

with decodeMoves(id, numberToMove, fromColumn, toColumn) as (
  select id,
    split_part(value,' ',2) as numberToMove,
    split_part(value,' ',4) as fromColumn,
    split_part(value,' ',6) as toColumn
  from input
  where cat = 'moves'
  order by id
)
select moveOneCrate(fromColumn, toColumn)
from decodeMoves,
  /* This will generate the numberToMove of lines for each instruction.
   * For example, if I need to move 2 crates, it will generate 2 lines, so that
   * I can use my function moveOneCrate twice */
  generate_series(1,numberToMove::int) as t(a)
order by id, a
/* Use psql, the best client for PostgreSQL */
\gexec

/* We will use dynamic sql with \gexec . We don't want to have all the update
 * messages */
\set QUIET off

with crate1(value) as (
  select crate1
  from input
  where crate1 is not null
    and cat='crates'
  order by id
  limit 1
),
crate2(value) as (
  select crate2
  from input
  where crate2 is not null
    and cat='crates'
  order by id
  limit 1
),
crate3(value) as (
  select crate3
  from input
  where crate3 is not null
    and cat='crates'
  order by id
  limit 1
),
crate4(value) as (
  select crate4
  from input
  where crate4 is not null
    and cat='crates'
  order by id
  limit 1
),
crate5(value) as (
  select crate5
  from input
  where crate5 is not null
    and cat='crates'
  order by id
  limit 1
),
crate6(value) as (
  select crate6
  from input
  where crate6 is not null
    and cat='crates'
  order by id
  limit 1
),
crate7(value) as (
  select crate7
  from input
  where crate7 is not null
    and cat='crates'
  order by id
  limit 1
),
crate8(value) as (
  select crate8
  from input
  where crate8 is not null
    and cat='crates'
  order by id
  limit 1
),
crate9(value) as (
  select crate9
  from input
  where crate9 is not null
    and cat='crates'
  order by id
  limit 1
)
select crate1.value || crate2.value || crate3.value ||
  crate4.value || crate5.value || crate6.value ||
  crate7.value || crate8.value || crate9.value
as partOne
from crate1,
  crate2,
  crate3,
  crate4,
  crate5,
  crate6,
  crate7,
  crate8,
  crate9;

/* we need to reinitiate the crates */
update input
  set
    crate1 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 2 for 1),' ')
    end,
    crate2 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 6 for 1),' ')
    end,
    crate3 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 10 for 1),' ')
    end,
    crate4 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 14 for 1),' ')
    end,
    crate5 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 18 for 1),' ')
    end,
    crate6 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 22 for 1),' ')
    end,
    crate7 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 26 for 1),' ')
    end,
    crate8 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 30 for 1),' ')
    end,
    crate9 = case when value ~ ']' and length(value)>0
      then nullif(substring(value from 34 for 1),' ')
    end
  where
    cat='crates'
  and id>0;
update input
  set
    crate1=null,
    crate2=null,
    crate3=null,
    crate4=null,
    crate5=null,
    crate6=null,
    crate7=null,
    crate8=null,
    crate9=null
  where cat='crates'
    and id <= 0;

create function duplicateCrate(fromColumn text,  toColumn text,
  idMove text) returns text as
$duplicateCrate$
  select
    /* First let's copy the crate to the new Column */
    $$update input set crate$$ || toColumn ||
    $$ = (select crate$$ || fromColumn ||
    $$ from input where id = ($$ || idMove || $$))$$ ||
    $$ where id = ($$ || firstEmptySlot(toColumn) ||
    $$);$$ as result;
$duplicateCrate$ language SQL;

create function deleteCrate(fromColumn text,  toColumn text,
  idMove text) returns text as
$deleteCrate$
  select
    /* Let's remove the crate from the old column */
    $$update input set crate$$ || fromColumn ||
    $$ = null where id = ($$ || idMove || $$);$$ as result ;
$deleteCrate$ language SQL;

create function getCrateIds(crateColumn text, n int)
returns text as
$getCrateIds$
  select
    $$select id[$$ || n || $$] $$ ||
    $$from ($$ ||
    $$  select array_agg(id) from (select id from input where crate$$ ||
    crateColumn || $$ is not null and cat='crates' order by id))$$ ||
    $$ t(id)$$ as result
  ;
$getCrateIds$ language SQL;

/* We will use dynamic sql with \gexec . We don't want to have all the update
 * messages */
\set QUIET on

with decodeMoves(id, numberToMove, fromColumn, toColumn) as (
  select id,
    split_part(value,' ',2) as numberToMove,
    split_part(value,' ',4) as fromColumn,
    split_part(value,' ',6) as toColumn
  from input
  where cat = 'moves'
  order by id
)
select query
from (
  (select duplicateCrate(fromColumn, toColumn,getCrateIds(fromColumn,a)) as query,
    id,
    a,
    1 as b
  from decodeMoves,
    generate_series(1,numberToMove::int) as t(a)
  order by id, a)
  union all
  (select deleteCrate(fromColumn, toColumn,getCrateIds(fromColumn,a)) as query,
    id,
    a,
    2 as b
  from decodeMoves,
    generate_series(1,numberToMove::int) as t(a)
  order by id, a))
order by id, a desc, b
\gexec

/* We will use dynamic sql with \gexec . We don't want to have all the update
 * messages */
\set QUIET off

with crate1(value) as (
  select crate1
  from input
  where crate1 is not null
    and cat='crates'
  order by id
  limit 1
),
crate2(value) as (
  select crate2
  from input
  where crate2 is not null
    and cat='crates'
  order by id
  limit 1
),
crate3(value) as (
  select crate3
  from input
  where crate3 is not null
    and cat='crates'
  order by id
  limit 1
),
crate4(value) as (
  select crate4
  from input
  where crate4 is not null
    and cat='crates'
  order by id
  limit 1
),
crate5(value) as (
  select crate5
  from input
  where crate5 is not null
    and cat='crates'
  order by id
  limit 1
),
crate6(value) as (
  select crate6
  from input
  where crate6 is not null
    and cat='crates'
  order by id
  limit 1
),
crate7(value) as (
  select crate7
  from input
  where crate7 is not null
    and cat='crates'
  order by id
  limit 1
),
crate8(value) as (
  select crate8
  from input
  where crate8 is not null
    and cat='crates'
  order by id
  limit 1
),
crate9(value) as (
  select crate9
  from input
  where crate9 is not null
    and cat='crates'
  order by id
  limit 1
)
select crate1.value || crate2.value || crate3.value ||
  crate4.value || crate5.value || crate6.value ||
  crate7.value || crate8.value || crate9.value
as partTwo
from crate1,
  crate2,
  crate3,
  crate4,
  crate5,
  crate6,
  crate7,
  crate8,
  crate9;

