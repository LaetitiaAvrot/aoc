/* Insert data into temporary table */
create temporary table code_init
  (id integer generated always as identity,
  position integer generated always as (id-1) stored,
  value integer);
alter table code_init add primary key (position);

/* Please use psql, the best PostgreSQL client */
\copy code_init(value) from 'input.csv';

/* replace position 1 with the value 12 */
update code_init set value=12 where position=1;
/* replace position 2 with the value 2 */
update code_init set value=2 where position=2;

/* As we don't want to ruin our initial entry, we'll work on a copy table */
create temporary table code_running  as 
(
  select position,
    value
  from code_init);

/* We need to find the opcode */
create temporary view intcode
  (position,
  opcode,
  input1_position,
  input2_position,
  output_position)
as
(
  with opcodes (position, opcode) as (
    select position,
      value as opcode
    from code_running
    where position%4=0),
  input1_positions (position, input1_position) as (
    select position-1 as position,
      value as intput1_position
    from code_running
    where position%4=1),
  input2_positions (position, input2_position) as (
    select position-2 as positions,
      value as input2_position
    from code_running
    where position%4=2),
  output_positions (position, output_position) as (
    select position-3 as position,
      value as output_position
    from code_running
    where position%4=3)
  select position,
    opcode,
    input1_position,
    input2_position,
    output_position
  from opcodes
    inner join input1_positions using (position)
    inner join input2_positions using (position)
    inner join output_positions using (position)
  order by opcodes.position
);

/* Somehow, using a cursor felt like cheating... So I decided to create
 * a trigger that will perform the different updates. The trigger will be
 * trigerred for every update on the view we just created but will check if the
 * position column changed. */
/* If the position changed, it means I triggered that function on purpose, if it
 * didn't change, it means one of the other value was changed on purpose and
 * it's fine. The  trigger is an instead of kind, so that we don't change the
 * position value */
create or replace function day2()
  returns trigger as
$body$
begin
  if new.position <> old.position then
    /* We want to trigger that function */
    if new.opcode = 1 then
      -- raise notice 'opcode 1 position processed : %', old.position;
      update code_running
      set value =
      (
        select input1.value + input2.value
        from (select value from code_running where position=old.input1_position) as input1,
          (select value from code_running where position=old.input2_position) as input2
      )
      where position=old.output_position;
      /* Let's trigger another row */
      update intcode set position=position+1 where position= old.position+4;
    elsif new.opcode = 2 then
      -- raise notice 'opcode 2 position processed : %', old.position;
      update code_running
      set value =
      (
        select input1.value * input2.value
        from (select value from code_running where position=old.input1_position) as input1,
          (select value from code_running where position=old.input2_position) as input2
      )
      where position=old.output_position;
      /* Let's trigger another row */
      update intcode set position=position+1 where position= old.position+4;
    end if;
  end if;
  return new;
end;
$body$ LANGUAGE plpgsql;

/* The trigger is create as 'instead of' because we don't really want to update
 * that row. */
create trigger operating_intcode
  instead of update
  on intcode
  for each row
  execute procedure day2();

/* Launch operating intcode */
update intcode set position=1 where position=0;

/* What value is left at position 0 after the program halts? */
select value as part1 from code_running where position=0;

/* We have 100 values for nouns and 100 values for verbs, so we'll end up with
 * 100*100=10000 rows by trying every possible values... */
create temporary table part2(
  noun integer,
  verb integer,
  value integer,
  answer integer generated always as (100*noun+verb) stored);

insert into part2(noun, verb)
(
  select *
  from generate_series(0,99) as noun,
    generate_series(0,99) as verb
);

/* We'll just create a view to be able to trigger an event*/
create temporary view part2_v (noun, verb)
as
(
  select *
  from generate_series(0,99) noun,
    generate_series(0,99) verb
);


/* As using a cursor felt like cheating for part1, the same applys on part2.
 * I'll use the same mechanism with trigger for part2*/
create or replace function day2_part2()
  returns trigger as
$body$
begin
  if new.noun = 100 then
    raise notice 'noun and verb processed : %', old.noun || ' ' || old.verb;
    /* We want to trigger that function */
    /* Let's "initialize memomry" */
    truncate code_running;
    insert into code_running
    (select position,
      value
    from code_init);

    update code_running set value=old.noun where position = 1;
    update code_running set value=old.verb where position = 2;

    /* Let's run the intcode */
    update intcode set position=1 where position=0;

    /* Let's store the value at position 0, that's the result value for that
     * noun and verb. */
    update part2
    set value=(select value from code_running where position=0)
    where noun=old.noun
      and verb=old.verb;

    /* Do we need to trigger the next line? */
    if old.verb <> 99 then
      update part2_v set noun=100
      where  part2_v.noun=old.noun
        and part2_v.verb=old.verb+1;
    end if;

  end if;
  return new;
end;
$body$ language plpgsql;

/* The trigger is create as 'instead of' because we don't really want to update
 * that row. */
create trigger operating_intcode
  instead of update
  on part2_v
  for each row
  execute procedure day2_part2();

/* launch intcode on all nouns and verbs */
update part2_v set noun=100 where verb=0 and noun in
(select *
from generate_series(0,99)
);

/* Find the solution */
select noun, verb, value, answer from part2 
where value=19690720;

/* Deleting everything afterwards */
/* Not really necessary as temporary tables are dropped at the end of the
 * session, but I'd rather drop my temporary tables explicitely.
 * On the "+" side, this make this script idempotent. */
drop view part2_v;
drop view intcode;
drop table part2;
drop table code_running;
drop table code_init;
drop function day2_part2;
drop function day2();
