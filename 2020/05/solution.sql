/* Insert data into  table */
create table input05 (
  id integer generated always as identity,
  seatNumber text
  );

/* Please use psql, the best PostgreSQL client */
\copy input05(seatNumber) from 'input.csv';

/* I will create a function that will get as an entry the min and max values of
 * the seat number alongside with the letter and will output the new min and max
 * I decided that as long as I was using an SQL function, that was fine with my
 * "solving the puzzle" with SQL. */
create function process_seat_position(minMax integer[],
                                      letter char(1))
  returns int[] as
$body$
  select
    case when letter = 'F' or letter = 'L'
      then array[minMax[1],((minMax[2]-minMax[1])/2)+minMax[1]]
      else array[((minMax[2]-minMax[1])/2)+minMax[1]+1,minMax[2]] end as result
$body$ language sql;


/* First, I'll change the string into an aray. It is not so useful as substring
 * could be used instead, but I think this extra step makes my code more
 * readable */
with seat as (
  select string_to_array(seatNumber, null) num,
    seatNumber,
    id
  from input05
),
processed_seat as (
  select
    /* 7th bit */
    (process_seat_position(
      /* 6th bit */
      process_seat_position(
        /* 5th bit */
        process_seat_position(
          /* 4th bit */
          process_seat_position(
            /* Third bit */
            process_seat_position(
              /* Second bit */
              process_seat_position(
                /* First bit */
                process_seat_position(array[0,127],num[1]),
                num[2]
              ),
              num[3]
            ),
            num[4]
          ),
          num[5]
        ),
        num[6]
      ),
      num[7]
    ))[1] as rowNumber,
    /* 10th bit */
    (process_seat_position(
      /* 9th bit */
      process_seat_position(
        /* 8th bit */
        process_seat_position(array[0,7],num[8]),
        num[9]
      ),
      num[10]
    ))[1] as columnNumber
  from seat
)
select max(rowNumber * 8 + columnNumber) as resultPartOne
from processed_seat;

/* Generate all the valid seat numbers, this should be 1024 seats */
with seat as (
  select string_to_array(seatNumber, null) num,
    seatNumber,
    id
  from input05
),
processed_seat as (
  select
    /* 7th bit */
    (process_seat_position(
      /* 6th bit */
      process_seat_position(
        /* 5th bit */
        process_seat_position(
          /* 4th bit */
          process_seat_position(
            /* Third bit */
            process_seat_position(
              /* Second bit */
              process_seat_position(
                /* First bit */
                process_seat_position(array[0,127],num[1]),
                num[2]
              ),
              num[3]
            ),
            num[4]
          ),
          num[5]
        ),
        num[6]
      ),
      num[7]
    ))[1] as rowNumber,
    /* 10th bit */
    (process_seat_position(
      /* 9th bit */
      process_seat_position(
        /* 8th bit */
        process_seat_position(array[0,7],num[8]),
        num[9]
      ),
      num[10]
    ))[1] as columnNumber,
    id
  from seat
),
/* Now that I have seatIDs, I will get the max and the min of those number,
 * generate a series and try to find the only missing seatID */
seatIds as (
  select rowNumber * 8 + columnNumber as seatID, id
  from processed_seat
)
/* This should generate all the seatIds between min and max, so all the seatId
 * available on that plane */
(
  select generate_series(min(seatID),max(seatID))
  from seatIds
)
except
/* Then if I retrieve all the seatIds I have on my file, I should find the empty
 * seat... */
(
  select seatID
  from seatIds
);
