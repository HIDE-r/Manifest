#!/usr/bin/env bash
set -u

tmp_root="${TMPDIR:-/tmp}"
log_root="${DAILY_UPDATE_LOG_DIR:-${tmp_root}/daily_update-${USER:-$(id -u)}}"
timestamp="$(date +%Y%m%d-%H%M%S)"
log_dir="${log_root}/${timestamp}"
verbose="${VERBOSE:-0}"
show_fail_log="${SHOW_FAIL_LOG:-0}"
no_color="${NO_COLOR:-0}"
ascii="${ASCII:-0}"

mkdir -p "${log_dir}"

if [ "$#" -eq 0 ]; then
    echo "daily_update: no task specified" >&2
    exit 1
fi

if [ "${no_color}" = "1" ] || [ ! -t 1 ]; then
    green=""
    red=""
    yellow=""
    blue=""
    reset=""
else
    green="\033[32m"
    red="\033[31m"
    yellow="\033[33m"
    blue="\033[34m"
    reset="\033[0m"
fi

if [ "${ascii}" = "1" ]; then
    ok_mark="OK"
    fail_mark="FAIL"
    warn_mark="WARN"
    skip_mark="SKIP"
    spinner="|/-\\"
    status_width=4
else
    ok_mark="✓"
    fail_mark="✗"
    warn_mark="!"
    skip_mark="-"
    spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    status_width=1
fi

ok_count=0
fail_count=0
warn_count=0
skip_count=0
saved_stty=""

disable_tty_echo() {
    [ -t 0 ] || return

    if [ -z "${saved_stty}" ]; then
        saved_stty="$(stty -g 2>/dev/null || true)"
    fi
    stty -echo 2>/dev/null || true
}

restore_tty_echo() {
    [ -n "${saved_stty}" ] || return
    [ -t 0 ] || return

    stty "${saved_stty}" 2>/dev/null || true
}

trap restore_tty_echo EXIT
trap 'restore_tty_echo; exit 130' INT
trap 'restore_tty_echo; exit 143' TERM

print_status() {
    local status="$1"
    local task="$2"
    local message="${3:-}"
    local color mark

    case "${status}" in
        ok)
            color="${green}"
            mark="${ok_mark}"
            ;;
        fail)
            color="${red}"
            mark="${fail_mark}"
            ;;
        warn)
            color="${yellow}"
            mark="${warn_mark}"
            ;;
        skip)
            color="${blue}"
            mark="${skip_mark}"
            ;;
        *)
            color=""
            mark="?"
            ;;
    esac

    if [ -n "${message}" ]; then
        printf "%b%-*s%b  %-24s %s\n" "${color}" "${status_width}" "${mark}" "${reset}" "${task}" "${message}"
    else
        printf "%b%-*s%b  %s\n" "${color}" "${status_width}" "${mark}" "${reset}" "${task}"
    fi
}

spinner_wait() {
    local pid="$1"
    local task="$2"
    local i=0
    local frame

    if [ ! -t 1 ]; then
        wait "${pid}"
        return $?
    fi

    disable_tty_echo
    while kill -0 "${pid}" 2>/dev/null; do
        frame="${spinner:i%${#spinner}:1}"
        printf "\r%b%-*s%b  %s" "${blue}" "${status_width}" "${frame}" "${reset}" "${task}"
        i=$((i + 1))
        sleep 0.1
    done

    wait "${pid}"
    local rc=$?
    restore_tty_echo
    printf "\r\033[K"
    return "${rc}"
}

run_task() {
    local task="$1"
    local log_file="${log_dir}/${task}.log"
    local rc
    local marker
    local message

    if [ "${verbose}" = "1" ]; then
        echo
        echo "===== ${task} ====="
        MAKEFLAGS='' make --no-print-directory DAILY_UPDATE_CHILD=1 "${task}" 2>&1 \
            | tee "${log_file}" \
            | grep -v '^__DAILY_UPDATE_STATUS='
        rc=${PIPESTATUS[0]}
    else
        MAKEFLAGS='' make --no-print-directory DAILY_UPDATE_CHILD=1 "${task}" >"${log_file}" 2>&1 </dev/null &
        spinner_wait "$!" "${task}"
        rc=$?
    fi

    marker="$(grep '^__DAILY_UPDATE_STATUS=' "${log_file}" 2>/dev/null | tail -n 1 || true)"
    if [ "${rc}" -eq 0 ] && [ -n "${marker}" ]; then
        marker="${marker#__DAILY_UPDATE_STATUS=}"
        message="${marker#*:}"
        marker="${marker%%:*}"
        case "${marker}" in
            warn)
                print_status warn "${task}" "${message:-warning}; see ${log_file}"
                warn_count=$((warn_count + 1))
                return
                ;;
            skip)
                print_status skip "${task}" "${message:-skipped}"
                skip_count=$((skip_count + 1))
                return
                ;;
        esac
    fi

    case "${rc}" in
        0)
            print_status ok "${task}"
            ok_count=$((ok_count + 1))
            ;;
        *)
            print_status fail "${task}" "see ${log_file}"
            if [ "${show_fail_log}" = "1" ]; then
                sed 's/^/  /' "${log_file}" | tail -n 20
            fi
            fail_count=$((fail_count + 1))
            ;;
    esac
}

for task in "$@"; do
    run_task "${task}"
done

printf "\nSummary: %d ok" "${ok_count}"
if ((warn_count > 0)); then
    printf ", %d warning" "${warn_count}"
fi
if ((skip_count > 0)); then
    printf ", %d skipped" "${skip_count}"
fi
if ((fail_count > 0)); then
    printf ", %d failed" "${fail_count}"
fi
printf "\nLogs: %s\n" "${log_dir}"

if ((fail_count > 0)); then
    exit 1
fi
exit 0
