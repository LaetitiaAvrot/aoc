/* Making the script idempotent */
drop table if exists input;

/* Insert data into  table */
create table input (
  id integer generated always as identity,
  value text,
  x1 integer generated always as (split_part(split_part(value,' -> ',1),',',1)::integer) stored,
  y1 integer generated always as (split_part(split_part(value,' -> ',1),',',2)::integer) stored,
  x2 integer generated always as (split_part(split_part(value,' -> ',2),',',1)::integer) stored,
  y2 integer generated always as (split_part(split_part(value,' -> ',2),',',2)::integer) stored
);

/* Please use psql, the best PostgreSQL client */
\copy input(value) from 'input.csv';

/* Calculate vertical lines */
with verticalLines(y, xmin, xmax, highestx) as (
  select y1,
    case when x1<x2
      then x1
      else x2
    end origin,
    case when x1>x2
      then x1
      else x2
    end destination,
    case when (max(x1) over ()) > (max(x2) over ())
      then (max(x1) over ())
      else (max(x2) over ())
    end highestx
  from input
  where
      y1 = y2 /* Vertical line */
),
/* Calculate horinzontal lines */
horizontalLines(x, ymin, ymax, highesty) as (
  select x1,
    case when y1<y2
      then y1
      else y2
    end origin,
    case when y1>y2
      then y1
      else y2
    end destination,
    case when (max(y1) over ()) > (max(y2) over ())
      then (max(y1) over ())
      else (max(y2) over ())
    end highesty
  from input
  where
      x1 = x2 /* Horinzontal line */
),
/* Calculate all the coordonates */
points(coordinates) as (
  select array[x,y]
    from verticalLines
      inner join generate_series(0, highestx) as points(x)
        on verticalLines.xmin <= points.x and verticalLines.xmax >= points.x
  /* We need union all to get the duplicates */
  union all
  select array[x,y]
    from HorizontalLines
      inner join generate_series(0, highesty) as points(y)
        on HorizontalLines.ymin <= points.y and HorizontalLines.ymax >= points.y
),
/* Calculate the most dangerous points coordinates */
dangerouspoints(coordinates) as (
  select
    coordinates
  from points
  group by coordinates
  having count(*)>1
)
select count(*) as resultPartOne
from dangerouspoints
;

/* Calculate vertical lines */
with verticalLines(y, xmin, xmax, highestx) as (
  select y1,
    case when x1<x2
      then x1
      else x2
    end origin,
    case when x1>x2
      then x1
      else x2
    end destination,
    case when (max(x1) over ()) > (max(x2) over ())
      then (max(x1) over ())
      else (max(x2) over ())
    end highestx
  from input
  where
      y1 = y2 /* Vertical line */
),
/* Calculate horinzontal lines */
horizontalLines(x, ymin, ymax, highesty) as (
  select x1,
    case when y1<y2
      then y1
      else y2
    end origin,
    case when y1>y2
      then y1
      else y2
    end destination,
    case when (max(y1) over ()) > (max(y2) over ())
      then (max(y1) over ())
      else (max(y2) over ())
    end highesty
  from input
  where
      x1 = x2 /* Horinzontal line */
),
/* Calculate diagonales */
diagonals(x1, x2, y1, y2, highestx, highesty, gap) as (
  select
    x1, x2, y1, y2,
    case when (max(x1) over ()) > (max(x2) over ())
      then (max(x1) over ())
      else (max(x2) over ())
    end highestx,
    case when (max(y1) over ()) > (max(y2) over ())
      then (max(y1) over ())
      else (max(y2) over ())
    end highesty,
    abs(x1-y1) as gap
  from input
  where abs(x1-y1) = abs(x2-y2) /* Diagnonal */
),
/* Calculate all the coordonates */
points(coordinates) as (
  select array[x,y]
    from verticalLines
      inner join generate_series(0, highestx) as points(x)
        on verticalLines.xmin <= points.x and verticalLines.xmax >= points.x
  /* We need union all to get the duplicates */
  union all
  select array[x,y]
    from HorizontalLines
      inner join generate_series(0, highesty) as points(y)
        on HorizontalLines.ymin <= points.y and HorizontalLines.ymax >= points.y
  union all
  select array[x,y]
  from diagonals
    inner join generate_series(0, highestx) as point(x)
      on (x1<=x2 and diagonals.x1 <= x and diagonals.x2 >= x)
        or (x1>x2 and diagonals.x2 <= x and diagonals.x1 >= x)
    inner join generate_series(0, highesty) as points2(y)
      on ((y1<=y2 and diagonals.y1 <= y and diagonals.y2 >= y)
	or (y1>y2 and diagonals.y2 <= y and diagonals.y1 >= y))
        and abs(x - y) = diagonals.gap
),
/* Calculate the most dangerous points coordinates */
dangerouspoints(coordinates) as (
  select
    coordinates
  from points
  group by coordinates
  having count(*)>1
)
  select array[x,y], diagonals.x1, diagonals.y1, diagonals.x2, diagonals.y2
  from diagonals
    inner join generate_series(0, highestx) as point(x)
      on (x1<=x2 and diagonals.x1 <= x and diagonals.x2 >= x)
        or (x1>x2 and diagonals.x2 <= x and diagonals.x1 >= x)
    inner join generate_series(0, highesty) as points2(y)
      on ((y1<=y2 and diagonals.y1 <= y and diagonals.y2 >= y)
	or (y1>y2 and diagonals.y2 <= y and diagonals.y1 >= y))
        and abs(x - y) = diagonals.gap
--select count(*) as resultPartTwo
--select *
--from dangerouspoints
;
