/* Use psql, the best Postgres client in the world */
\set ON_ERROR_STOP on

/* Making the script idempotent */
drop schema if exists aoc08 cascade;
create schema aoc08;
set search_path to 'aoc08';

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  value text
);

create table treeRows (
  id int generated always as identity,
  idRow int,
  idColumn int,
  tree int
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

insert into treeRows (idRow, idColumn, tree) (
  with trees(idrow, tree) as (
    select id,
      regexp_split_to_table(value,'')
    from input
  )
  select idRow,
    row_Number() over(partition by idRow) as idColumn,
    tree::integer
  from trees
)
;

select count(*) as Partone
from
((
  with leftTrees(idrow, trees) as (
    /* Let's create a rolling array of trees in the same rows */
    select idRow,
      array_agg(tree) over(partition by idrow order by idrow, idcolumn)
    from treeRows
  ),
  trees (idrow, trees, idcolumn) as (
    /* let's get the cardinality of the arrays */
    select idrow,
      trees,
      cardinality(trees) as idcolumn
    from leftTrees
  )
  /* This should give all the trees visible from the left (minus the first row) */
  select treeRows.*
  from trees
    inner join treeRows
      on trees.idrow = treeRows.idrow
      /* we want to compare a tree height with all the previous trees heights */
      and trees.idcolumn = treeRows.idcolumn-1
      and treeRows.tree > all (trees.trees)
)
union
/* Let get all the trees visible from the right (minus the last column) */
(
  with rightTrees(idrow, maxColumn, trees) as (
    select idRow,
      max(idcolumn) over(),
      array_agg(tree) over (partition by idrow order by idrow, idcolumn desc)
      from treeRows
  ),
  trees (idrow, trees, maxColumn, idcolumn) as (
    /* let's get the cardinality of the arrays */
    select idrow,
      trees,
      maxColumn,
      cardinality(trees) as idcolumn
    from rightTrees
  )
  /* This should give all the trees visible from the left (minus the first row) */
  select treeRows.*
  from trees
    inner join treeRows
      on trees.idrow = treeRows.idrow
      /* we want to compare a tree height with all the previous trees heights */
      and maxColumn - trees.idcolumn = treeRows.idcolumn
      and treeRows.tree > all (trees.trees)
)
union
/* Let get all the trees visible from the top (minus the first row) */
(
  with TopTrees(idcolumn, trees) as (
    /* Let's create a rolling array of trees in the same rows */
    select idColumn,
      array_agg(tree) over(partition by idcolumn order by idcolumn, idrow)
    from treeRows
  ),
  trees (idcolumn, trees, idrow) as (
    /* let's get the cardinality of the arrays */
    select idcolumn,
      trees,
      cardinality(trees) as idrow
    from topTrees
  )
  /* This should give all the trees visible from the left (minus the first row) */
  select treeRows.*
  from trees
    inner join treeRows
      on trees.idcolumn = treeRows.idcolumn
      /* we want to compare a tree height with all the previous trees heights */
      and trees.idrow = treeRows.idrow-1
      and treeRows.tree > all (trees.trees)
  order by idrow, idcolumn
)
union
/* Let get all the trees visible from the bottom (minus the last row) */
(
  with BottomTrees(idcolumn, maxRows, trees) as (
    /* Let's create a rolling array of trees in the same rows */
    select idColumn,
      max(idrow) over(),
      array_agg(tree) over(partition by idcolumn order by idcolumn, idrow desc)
    from treeRows
  ),
  trees (idcolumn, maxRows, trees, idrow) as (
    /* let's get the cardinality of the arrays */
    select idcolumn,
      maxRows,
      trees,
      cardinality(trees) as idrow
    from bottomTrees
  )
  /* This should give all the trees visible from the left (minus the first row) */
  select treeRows.*
  from trees
    inner join treeRows
      on trees.idcolumn = treeRows.idcolumn
      /* we want to compare a tree height with all the previous trees heights */
      and maxRows - trees.idrow = treeRows.idrow
      and treeRows.tree > all (trees.trees)
  order by idrow, idcolumn
)
union
/* Adding the first row */
(select * from treeRows where idrow=1)
union
/* Adding the last row */
(
  with maximum(maxrow) as (
    select max(idrow)
    from treeRows
  )
  select treeRows.*
  from treeRows
    inner join maximum
      on treeRows.idrow = maximum.maxRow
)
union
/* Adding the first column */
(select * from treeRows where idcolumn=1)
union
/* Adding the last column */
(
  with maximum(maxcol) as (
    select max(idcolumn)
    from treeRows
  )
  select treeRows.*
  from treeRows
    inner join maximum
      on treeRows.idcolumn = maximum.maxCol
))
;

/* Let's try using points instead of idRows and Columns */
create table treeMap (
  x integer,
  y integer,
  tree integer not null,
  rightTrees integer,
  leftTrees integer,
  upTrees integer,
  downTrees integer,
  primary key (x,y)
);

with data(id, value) as (
  select id,
    regexp_split_to_array(value,'')
  from input
)
insert into treeMap (
  select y::integer,
    id as x,
    v::integer
  from data
    cross join unnest(value) with ordinality as d(v,y)
);

create function rightTrees(myx integer, myy integer, mytree integer) returns integer as 
$rightTrees$
  /* we're looking for the first tree taller than my tree "on the right".
   * On the right means, same y and x>myx.
   * First taller tree means the x value is minimal.
   * But, what if there is not taller tree before the edge? It means they are
   * all visible. */
  select coalesce(
      /* First taller tree */
      min(x) filter (where tree>=mytree)-myx,
      /* All trees are visible till the edge */
      count(*))
  from treeMap
  where y=myy
    and x>myx;
$rightTrees$ language sql;
create function leftTrees(myx integer, myy integer, mytree integer) returns integer as 
$leftTrees$
  select coalesce(
      myx-max(x) filter (where tree>=mytree),
      count(*))
  from treeMap
  where y=myy
    and x<myx;
$leftTrees$ language sql;
create function upTrees(myx integer, myy integer, mytree integer) returns integer as 
$upTrees$
  select coalesce(
      myy-max(y) filter (where tree>=mytree),
      count(*))
  from treeMap
  where y<myy
    and x=myx;
$upTrees$ language sql;
create function downTrees(myx integer, myy integer, mytree integer) returns integer as 
$downTrees$
  select coalesce(
     min(y) filter (where tree>=mytree)-myy,
      count(*))
  from treeMap
  where y>myy
    and x=myx;
$downTrees$ language sql;


update treeMap set rightTrees = rightTrees(x, y, tree);
/* To spare some calcul, we'll put 0 if any value is already equal to 0 as we're
 * only interested in the product of all values. */
update treeMap set leftTrees = leftTrees(x, y, tree) where rightTrees>0;
update treeMap set leftTrees = 0 where leftTrees is null;
update treeMap set upTrees = upTrees(x, y, tree) where rightTrees>0 and leftTrees>0;
update treeMap set upTrees = 0 where upTrees is null;
update treeMap set downTrees = downTrees(x, y, tree) where rightTrees>0 and leftTrees>0 and upTrees>0;
update treeMap set downTrees = 0 where downTrees is null;

select righttrees*lefttrees*uptrees*downtrees as secondStar, righttrees, lefttrees, uptrees, downtrees, x, y, tree
from treeMap
order by righttrees*lefttrees*uptrees*downtrees desc
limit 1;
