#!/bin/bash

#===============================================================================#
# This plugin exists to create configurably long running backup/restores that   #
# write a configurable amount of garbage out to logs and/or archives.           #
#                                                                               #
# There's no reason to use this plugin for actual backups, as it doesn't backup #
# anything. This to reproducibly test (and break) SHIELD.                       #
#===============================================================================#

set -euo pipefail

#============================#
#          HELPERS           #
#============================#
endpoint=""
sleep_time=0
log_size=0
backup_size=0
log_source=/dev/urandom
backup_source=/dev/urandom

parse_input_json() {
  if jq -Mre 'has("sleep_time")'    <<<"$endpoint" >/dev/null; then
    sleep_time="$(   jq -Mr '.sleep_time'   <<<"$endpoint")"
  fi
  if jq -Mre 'has("log_size")'      <<<"$endpoint" >/dev/null; then
    log_size="$(     jq -Mr '.log_size'     <<<"$endpoint")"
  fi
  if jq -Mre 'has("backup_size")'   <<<"$endpoint" >/dev/null; then
    backup_size="$(  jq -Mr '.backup_size'  <<<"$endpoint")"
  fi
  if jq -Mre 'has("log_source")'    <<<"$endpoint" >/dev/null; then
    log_source="$(   jq -Mr '.log_source'   <<<"$endpoint")"
  fi
  if jq -Mre 'has("backup_source")' <<<"$endpoint" >/dev/null; then
    backup_source="$(jq -Mr '.backup_source'<<<"$endpoint")"
  fi
}

is_number()          { [[ "$1" =~ ^-?[0-9]+$ ]]; return $?; }
is_positive_number() { [[ "$1" =~ ^[0-9]+$ ]];   return $?; }
file_exists()        { [[ -a "$1" ]];            return $?; }
file_readable()      { [[ -r "$1" ]];            return $?; }

validate_positive_number() {
  local value=$1
  local label=$2
  if ! is_number "$value"; then
    echo "Invalid number given for '${label}':" "$value"; exit 1;
  fi
  if ! is_positive_number "$value"; then
    echo "Cannot give negative number for '${label}':" "$value"; exit 1;
  fi
}

validate_readable_file() {
  local value=$1
  local label=$2
  if ! file_exists "$value"; then
    echo "File cannot be found for ${label}:" "$value"; exit 1;
  fi
  if ! file_readable "$value"; then
    echo "File cannot be read for ${label}:" "$value"; exit 1;
  fi
}


copy_bytes() {
  local input_file="$1"
  local output_file="$2"
  local num_bytes="$3"
  head -c "$num_bytes" "$input_file" >"$output_file"
}
#============================#
#          COMMANDS          #
#============================#

cmd_info() {
  cat <<EOF
{
  "name":    "Testing Tools Target Plugin",
  "author":  "Thomas Mitchell",
  "version": "0.0.1",
  "features": {
    "target": "yes",
    "store":  "no"
  },
  "fields": [
    {
      "mode":    "target",
      "name":    "sleep_time",
      "type":    "string",
      "title":   "Sleep Time",
      "help":    "The number of seconds to sleep after finishing writing.",
      "default": "${sleep_time}"
    },
    {
      "mode":    "target",
      "name":    "log_size",
      "type":    "string",
      "title":   "Log Size",
      "help":    "The number of bytes to write out to the log.",
      "default": "${log_size}"
    },
    {
      "mode":    "target",
      "name":    "backup_size",
      "type":    "string",
      "title":   "Backup Size",
      "help":    "The number of bytes to output as the backup archive.",
      "default": "${backup_size}"
    },
    {
      "mode":    "target",
      "name":    "log_source",
      "type":    "abspath",
      "title":   "Log Source",
      "help":    "The file to read bytes from to form the log",
      "default": "${log_source}"
    },
    {
      "mode":    "target",
      "name":    "backup_source",
      "type":    "abspath",
      "title":   "Backup Source",
      "help":    "The file to read bytes from to form the backup archive",
      "default": "${backup_source}"
    }
  ]
}
EOF
}

cmd_validate() {
  parse_input_json
  validate_positive_number "$sleep_time"    "sleep_time"
  validate_positive_number "$log_size"      "log_size"
  validate_positive_number "$backup_size"   "backup_size"
  validate_readable_file   "$log_source"    "log_source"
  validate_readable_file   "$backup_source" "backup_source"
}

cmd_backup() {
  cmd_validate
  copy_bytes "$backup_source" "/dev/fd/1" "$backup_size"
  copy_bytes "$log_source"    "/dev/fd/2" "$log_size"
  sleep "$sleep_time"
}

cmd_restore() {
  cmd_validate
  copy_bytes "$log_source"    "/dev/fd/2" "$log_size"
  sleep "$sleep_time"
}


#=============================
#            MAIN            #
#=============================

declare cmd_name
declare cur_flag
# Parse that command line
for arg in "$@"; do
  if [[ -n "$cur_flag" ]]; then
    case "$cur_flag" in
      -e|--endpoint) endpoint="$arg" ;;
      *            ) echo "Unknown flag:" "$cur_flag"; exit 1;;
    esac
    cur_flag=""
    continue
  fi

  if [[ "$arg" =~ ^-{1,2} ]]; then cur_flag="$arg"
  else                             cmd_name="$arg"
  fi
done

if [[ -n "$cur_flag" ]]; then
  echo "Flag without value given"
  exit 1
fi

if [[ -z "$cmd_name" ]]; then
  echo "No subcommand was specified"
  exit 1
fi

# Branch on subcommand
case "$cmd_name" in
  info)     cmd_info;;
  validate) cmd_validate;;
  backup)   cmd_backup;;
  restore)  cmd_restore;;
  *) echo "The '${cmd_name}' command is currently unsupported by this plugin";;
esac
