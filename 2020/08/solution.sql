/* Insert data into  table */
create table input08 (
  id integer generated always as identity,
  rawData text,
  /* this should get the instruction */
  instruction text generated always as (
    (regexp_split_to_array(rawData, ' '))[1]
  ) stored,
  /* this should get the number after the instruction */
  num integer generated always as (
    (regexp_split_to_array(rawData, ' '))[2]::integer
  ) stored
);

/* Please use psql, the best PostgreSQL client */
\copy input08(rawData) from 'input.csv';

/* The first with list element is not recursive, the next one is */
with recursive instructions as (
  /* For each instruction, I'll calculate the id of the next instruction */
  select id,
    instruction,
    num,
    case when instruction ~ 'jmp'
      then id+num
      else id+1
    end as nextInstructionId
  from input08
),
completePath as(
  /* This is the first iteration */
  select 1 as iteration,
    array[nextInstructionId] as instructionIds,
    /* I will calculate the value in the accumulator. If the instruction is
     * 'acc', then it will add the number to 0, else the accumulator will stay
     * 0. */
    case when instruction = 'acc'
      then num
      else 0
    end as accumulator
  from instructions
  where id = 1
  union
  /* For the next one, we need to add the next step into our array */
  select completePath.iteration +1 as iteration,
    array_append(completePath.instructionIds, instructions.nextInstructionId) as instructionIds,
    /* If the instruction is 'acc' */
    case when instructions.instruction = 'acc'
      /* I will add the number to the previsou accumulator value */
      then completePath.accumulator + instructions.num
      /* else Ii'll keep the previous value */
      else completePath.accumulator
    end as accumulator
  from completePath
    inner join instructions
      on completePath.instructionIds[cardinality(completePath.instructionIds)] = instructions.id
  /* We need to stop before looping or we'll enter an infinite loop */
  where array_position(completePath.instructionIds, instructions.nextInstructionId) is null
)
select
  accumulator as resultPartOne
from completePath
/* We're only interested with the last value, which is the accumulator value
 * before we enter the infinite loop */
order by iteration desc
limit 1
