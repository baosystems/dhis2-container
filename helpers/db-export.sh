#!/usr/bin/env bash

# SC2155: Declare and assign separately to avoid masking return values.
# shellcheck disable=SC2155

set -Eeo pipefail


################################################################################


SELF="$( basename "$0" )"

echo "[INFO] $SELF: started..." >&2  # Using stderr for info messages


################################################################################


# If PGPASSWORD is empty or null, set it to the contents of PGPASSWORD_FILE
if [[ -z "${PGPASSWORD:-}" ]] && [[ -r "${PGPASSWORD_FILE:-}" ]]; then
  export PGPASSWORD="$(<"${PGPASSWORD_FILE}")"
fi

# If PGHOST is empty or null, set it to DHIS2_DATABASE_HOST if provided
if [[ -z "${PGHOST:-}" ]] && [[ -n "${DHIS2_DATABASE_HOST:-}" ]]; then
  export PGHOST="${DHIS2_DATABASE_HOST:-}"
fi

# Set default values if not provided in the environment
if [[ -z "${DHIS2_DATABASE_NAME:-}" ]]; then
  export DHIS2_DATABASE_NAME='dhis2'
fi
if [[ -z "${PGHOST:-}" ]]; then
  export PGHOST='localhost'
fi
if [[ -z "${PGPORT:-}" ]]; then
  export PGPORT='5432'
fi
if [[ -z "${PGUSER:-}" ]]; then
  export PGUSER='postgres'
fi

# If WAIT_HOSTS is empty or null, set to PGHOST:PGPORT
if [[ -z "${WAIT_HOSTS:-}" ]]; then
  export WAIT_HOSTS="${PGHOST}:${PGPORT}"
fi

# Disable wait delay as this script is designed to be run interactively
export WAIT_BEFORE='0'


################################################################################


# Wait for hosts specified in the environment variable WAIT_HOSTS (noop if not set).
# If it times out before the targets are available, it will exit with a non-0 code,
# and this script will quit because of the bash option "set -e" above.
# https://github.com/ufoscout/docker-compose-wait
/usr/local/bin/wait 2>/dev/null  # No output to stderr due to strange docker compose run output line break issue


################################################################################


# The following section requires the following environment variables set:
# - DHIS2_DATABASE_NAME
# - PGHOST
# - PGPORT
# - PGUSER
# - PGPASSWORD


# Using stderr for log output in this script to avoid being in a stdout-captured file
echo "[INFO] $SELF: Exporting database \"$DHIS2_DATABASE_NAME\":" >&2

pg_dump \
  "$DHIS2_DATABASE_NAME" \
  --format='plain' \
  --no-owner \
  --no-privileges \
  --exclude-table='_*' \
  --exclude-table='aggregated*' \
  --exclude-table='analytics_*' \
  --exclude-table='completeness*' \
  --exclude-schema='postgis' \
  --exclude-table='geography_columns' \
  --exclude-table='geometry_columns' \
  --exclude-table='spatial_ref_sys' \
| sed \
    --regexp-extended \
    -e '/^-- Dumped by pg_dump/,/^-- Name: postgis/{/^-- Dumped by pg_dump/!{/^-- Name: postgis/!d}}' \
    -e '/^-- Name: postgis/i \\nSET check_function_bodies = false;\n\n--' \
    -e 's/postgis\.(geometry)/\1/g' \
    -e 's/( postgis) WITH SCHEMA postgis;/\1;/'


################################################################################


# Output script progess
# Using stderr for log output in this script to avoid being in a stdout-captured file
echo "$SELF: COMPLETED" >&2
