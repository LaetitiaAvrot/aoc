# Advent of Code in SQL, run on a PostgreSQL built by pgBuilder.
# Run "make" for the list of commands.
#
# Variables:
#   Y      year, default current year
#   D      day, default today
#   INPUT  example or full (or any <name>.csv in the day folder)
#   PGSRC, PG_USER, PG_DATABASE, PG_MESON_ARGS  passed to pgBuilder

SHELL := bash

# Personal settings, not committed
-include config.mk

Y ?= $(shell date +%Y)
D ?= $(shell date +%d)
INPUT ?=
D2 := $(shell printf '%02d' "$$(echo '$(D)' | sed 's/^0*//')")
DAYDIR := $(Y)/$(D2)

PGSRC ?= ../postgresql
override PGSRC := $(abspath $(PGSRC))
PG_USER ?= postgres
PG_DATABASE ?= $(PG_USER)
PG_MESON_ARGS ?=
AOC_DIR := $(CURDIR)
export PGSRC PG_USER PG_DATABASE PG_MESON_ARGS AOC_DIR

COMPOSE := docker compose -p aoc --project-directory pgBuilder \
  -f pgBuilder/compose.yaml -f compose.aoc.yaml

.DEFAULT_GOAL := help
.PHONY: help check up running day new psql logs down reset update-builder

help: ## Show this list
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) \
	  | awk -F ':.*## ' '{ printf "  %-15s %s\n", $$1, $$2 }'

check:
	@[ -f pgBuilder/compose.yaml ] || { \
	  echo "pgBuilder is missing, run: git submodule update --init"; exit 1; }
	@[ -f "$(PGSRC)/meson.build" ] || { \
	  echo "No postgres checkout in $(PGSRC)."; \
	  echo "Clone it there or set PGSRC in config.mk"; exit 1; }

up: check ## Rebuild Postgres from the checkout and (re)start it
	$(COMPOSE) up -d --build runtime
	@$(MAKE) -s running

# Start without rebuilding if the image exists, then wait for the server
running: check
	@$(COMPOSE) up -d runtime
	@for i in $$(seq 60); do \
	  $(COMPOSE) exec -T runtime pg_isready -q 2>/dev/null && exit 0; \
	  sleep 0.5; \
	done; \
	echo "Postgres did not start, see: make logs"; exit 1

day: running ## Run a solution: make day [Y=2025] [D=1] [INPUT=example]
	@[ -f "$(DAYDIR)/solution.sql" ] || { \
	  echo "No $(DAYDIR)/solution.sql, create it with: make new Y=$(Y) D=$(D)"; \
	  exit 1; }
	@if [ -n "$(INPUT)" ]; then \
	  cd "$(DAYDIR)"; \
	  [ -f "$(INPUT).csv" ] || { echo "No $(DAYDIR)/$(INPUT).csv"; exit 1; }; \
	  if [ -f input.csv ] && [ ! -L input.csv ]; then \
	    echo "$(DAYDIR)/input.csv is a regular file, not replacing it"; \
	    exit 1; \
	  fi; \
	  ln -sfn "$(INPUT).csv" input.csv; \
	fi
	@src=$$(readlink "$(DAYDIR)/input.csv" || echo "input.csv, a regular file"); \
	case "$$src" in \
	  full.csv) color=32 ;; \
	  example*) color=33 ;; \
	  *) color=31 ;; \
	esac; \
	banner() { printf '\033[1;%sm==== %s on %s ====\033[0m\n' \
	  "$$color" "$(DAYDIR)" "$$(echo "$$src" | tr a-z A-Z)"; }; \
	banner; \
	$(COMPOSE) exec -w "/aoc/$(DAYDIR)" runtime psql -f solution.sql; \
	rc=$$?; \
	banner; \
	exit $$rc

new: ## Create a day from template.sql: make new [Y=2026] [D=1]
	@[ ! -e "$(DAYDIR)" ] || { echo "$(DAYDIR) already exists"; exit 1; }
	mkdir -p "$(DAYDIR)"
	sed -e 's/YEAR/$(Y)/g' -e 's/DAY/$(D2)/g' template.sql > "$(DAYDIR)/solution.sql"
	touch "$(DAYDIR)/example.csv" "$(DAYDIR)/full.csv"
	ln -s example.csv "$(DAYDIR)/input.csv"
	@echo "Paste the inputs in $(DAYDIR)/example.csv and $(DAYDIR)/full.csv"

psql: running ## Open psql, from the repo root
	$(COMPOSE) exec -w /aoc runtime psql

logs: ## Follow the server logs
	$(COMPOSE) logs -f runtime

down: ## Stop and remove the container, keep the data
	$(COMPOSE) down

reset: ## Remove the container and its data
	$(COMPOSE) down -v

update-builder: ## Update the pgBuilder submodule to its latest version
	git submodule update --remote pgBuilder
	@echo "Commit the new pgBuilder version with: git commit pgBuilder"
