# Advent of Code in SQL

My [Advent of Code](https://adventofcode.com) solutions, in PostgreSQL SQL
only, run with psql. Postgres is built from source by
[pgBuilder](https://github.com/LaetitiaAvrot/pgBuilder), included as a git
submodule.

## Setup

You need Docker with Compose and a PostgreSQL checkout, by default in
`../postgresql`.

```sh
git clone --recurse-submodules https://github.com/LaetitiaAvrot/adventofcode-sql.git
cd adventofcode-sql
make up        # build Postgres from the checkout and start it
```

To use a checkout somewhere else, put `PGSRC = /path/to/postgresql` in a
`config.mk` file. It is not committed.

## Most useful commands

Run `make` to list every command. `Y` defaults to the current year and `D`
to today, so in December `make new` and `make day` need no arguments.

| Command | What it does |
| --- | --- |
| `make new` | Create today's folder from `template.sql`. |
| `make day INPUT=example` | Run today's solution on `example.csv`. |
| `make day INPUT=full` | Run it on `full.csv`, your puzzle input. |
| `make day` | Run it again on the same input. |
| `make day Y=2022 D=9` | Run an older solution. |
| `make psql` | Open psql to explore. |
| `make up` | Rebuild Postgres after changing the checkout. |
| `make reset` | Remove the container and its data. |

`make day` prints which input it used before and after the results: green
for `FULL.CSV`, yellow for `EXAMPLE.CSV`, red for anything else. Check it
is green before submitting an answer.

## Layout

```
2025/01/solution.sql   one folder per day
2025/01/example.csv    example from the puzzle
2025/01/full.csv       your puzzle input
2025/01/input.csv      symlink to the one to use, set by INPUT
template.sql           starting point for a new day
compose.aoc.yaml       mounts this repo in the pgBuilder container
pgBuilder/             submodule
```

Solutions load their data with `\copy input from 'input.csv'`, relative to
the day folder, where `make day` runs psql. Since 2025, each day uses its
own schema named after the year and day (`aoc_2025_01`), so every script
can be rerun, and you can work on a new day while keeping the previous ones.

## Puzzle inputs

The inputs are not in this repo. The Advent of Code author
[asks people not to share them](https://adventofcode.com/about), so all
`.csv` files are ignored by git. To run a solution, paste your own input
in `full.csv`.

## Updating pgBuilder

```sh
make update-builder
git commit pgBuilder -m "Update pgBuilder"
```

## License

[PostgreSQL License](LICENSE).
