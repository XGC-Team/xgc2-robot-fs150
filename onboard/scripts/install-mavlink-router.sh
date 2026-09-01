#!/usr/bin/env bash
# One-shot FS150 companion bring-up for remote MAVLink control.
#
# Designed to be re-run on a fresh / unknown aircraft:
# - Rewrite Ubuntu ports mirror; repair ROS key+source; add XGC2 apt
# - Quarantine other apt list files that break `apt-get update`
# - Stop/disable/mask vendor mavlink routers; free /dev/ttyS7
# - Install + enable xgc2-fs150-mavlink-router (UART Baud = 921600 hard rule)
# - Verify FC HEARTBEAT on the local unfiltered UDP port; fail early if silent
# - Network LAST: write Wi-Fi + static IPv4/DNS/gateway. Never reconnect mid-run.
#
# Hard rule: never lower packaged Baud 921600. 115200 grows companion↔FC RTT,
# queues/jitters MAVLink, and has shown TIMESYNC samples >30 ms.
# If this script fails the link check, fix PX4 serial baud via QGC wired serial
# (SER_TEL1_BAUD on FS-150 / the UART this airframe uses), then re-run or
# `systemctl restart xgc2-fs150-mavlink-router`.
#
# Usage:
#   sudo bash install-mavlink-router.sh --yes --lan-address 192.168.51.24
set -euo pipefail

APT_BASE_URL="${APT_BASE_URL:-http://xgc2.apt.xiaokang.ink}"
APT_SUITE="${APT_SUITE:-focal}"
XGC2_KEY_FPR="2A8E11B36F56D307ADF626D85E5FDC30979EA43F"
ROS_KEY_FPR="C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654"
ROUTER_PKG="xgc2-fs150-mavlink-router"
ROUTER_UNIT="xgc2-fs150-mavlink-router.service"
ROUTER_CONF="/etc/xgc2/fs150-mavlink-router/router.conf"
UART_DEVICE="/dev/ttyS7"
EXPECT_BAUD="921600"
LOCAL_MAVLINK_UDP="127.0.0.1:14561"
LINK_CHECK_SECONDS="${LINK_CHECK_SECONDS:-12}"

# Managed apt basenames we own after configure_*; everything else in
# sources.list.d may be quarantined when it breaks apt-get update.
MANAGED_APT_LISTS=(
  ros-latest.list
  xgc2.list
)

CONFLICT_UNITS=(
  startMavRoute.service
  fs150-mavlink-router.service
  mavlink-router.service
  mavlink_router.service
  xgc-mavlink-router.service
)

YES=0
WIFI_SSID="${FS150_WIFI_SSID:-asus-waichang5G}"
WIFI_PASSWORD="${FS150_WIFI_PASSWORD:-asus-waichang}"
WIFI_IFACE="${FS150_WIFI_IFACE:-wlan0}"
LAN_ADDRESS="${FS150_LAN_ADDRESS:-}"
LAN_GATEWAY="${FS150_LAN_GATEWAY:-192.168.51.1}"
LAN_DNS="${FS150_LAN_DNS:-192.168.51.1}"
SKIP_WIFI=0
SKIP_UBUNTU_MIRROR=0
SKIP_ROS_SOURCE=0
SKIP_LINK_CHECK=0
SKIP_QUARANTINE_SOURCES=0

usage() {
  cat <<'EOF'
Usage: install-mavlink-router.sh --yes [options]

Options:
  --yes                     required; refuse to run without it
  --apt-url URL             default http://xgc2.apt.xiaokang.ink
  --suite SUITE             default focal
  --wifi-ssid SSID          default asus-waichang5G; write last (never reconnect)
  --wifi-password PASS      field PSK is defaulted; override with flag/env
  --wifi-iface IFACE        default wlan0
  --lan-address A.B.C.D[/24]  static IPv4; prompt on /dev/tty if omitted
  --lan-gateway ADDR        default 192.168.51.1
  --lan-dns ADDR            default 192.168.51.1
  --skip-wifi               do not touch NetworkManager / addressing
  --skip-ubuntu-mirror      do not rewrite /etc/apt/sources.list
  --skip-ros-source         do not repair ROS apt key/source
  --skip-quarantine-sources do not move aside foreign/broken apt lists
  --skip-link-check         do not fail when HEARTBEAT missing after 921600
  --link-check-seconds N    default 12
  -h, --help                show this help

Exit codes:
  0  router enabled at 921600 and (unless skipped) HEARTBEAT seen
  1  configuration / apt / service / link-check failure
EOF
}

log() { printf '+ %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "run as root (sudo)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) YES=1; shift ;;
    --apt-url) APT_BASE_URL="${2:?}"; shift 2 ;;
    --suite) APT_SUITE="${2:?}"; shift 2 ;;
    --wifi-ssid) WIFI_SSID="${2:?}"; shift 2 ;;
    --wifi-password) WIFI_PASSWORD="${2:?}"; shift 2 ;;
    --wifi-iface) WIFI_IFACE="${2:?}"; shift 2 ;;
    --lan-address) LAN_ADDRESS="${2:?}"; shift 2 ;;
    --lan-gateway) LAN_GATEWAY="${2:?}"; shift 2 ;;
    --lan-dns) LAN_DNS="${2:?}"; shift 2 ;;
    --skip-wifi) SKIP_WIFI=1; shift ;;
    --skip-ubuntu-mirror) SKIP_UBUNTU_MIRROR=1; shift ;;
    --skip-ros-source) SKIP_ROS_SOURCE=1; shift ;;
    --skip-quarantine-sources) SKIP_QUARANTINE_SOURCES=1; shift ;;
    --skip-link-check) SKIP_LINK_CHECK=1; shift ;;
    --link-check-seconds) LINK_CHECK_SECONDS="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ "${YES}" -eq 1 ]] || die "refusing to run without --yes (see --help)"
require_root
need_cmd curl
need_cmd gpg
need_cmd apt-get
need_cmd systemctl
need_cmd dpkg
need_cmd install
need_cmd python3

ARCH="$(dpkg --print-architecture)"
[[ "${ARCH}" == "arm64" ]] || warn "expected arm64 companion, got ${ARCH}"

stamp="$(date +%Y%m%d-%H%M%S)"
QUARANTINE_DIR="/var/backups/xgc2-fs150-apt-${stamp}"

backup() {
  local path="$1"
  if [[ -e "${path}" ]]; then
    cp -a "${path}" "${path}.bak-${stamp}"
    log "backup ${path} -> ${path}.bak-${stamp}"
  fi
}

fingerprint_of() {
  local file="$1"
  gpg --show-keys --with-fingerprint --with-colons "${file}" 2>/dev/null \
    | awk -F: '$1 == "fpr" { print $10; exit }'
}

is_managed_apt_list() {
  local base="$1"
  local m
  for m in "${MANAGED_APT_LISTS[@]}"; do
    [[ "${base}" == "${m}" ]] && return 0
  done
  return 1
}

quarantine_path() {
  local path="$1"
  mkdir -p "${QUARANTINE_DIR}"
  local base dest
  base="$(basename -- "${path}")"
  dest="${QUARANTINE_DIR}/${base}"
  mv -f -- "${path}" "${dest}"
  log "quarantine ${path} -> ${dest}"
}

# Move aside every non-managed sources.list.d entry (*.list / *.sources).
# Re-running on another aircraft must not inherit expired vendor ROS keys,
# random PPAs, or half-broken Chinese mirrors that fail apt-get update.
quarantine_foreign_apt_lists() {
  [[ "${SKIP_QUARANTINE_SOURCES}" -eq 0 ]] || { log "skip apt quarantine"; return; }
  local path base
  shopt -s nullglob
  for path in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    base="$(basename -- "${path}")"
    # Keep stamped backups in place; only active lists.
    [[ "${base}" == *.bak-* ]] && continue
    if is_managed_apt_list "${base}"; then
      continue
    fi
    quarantine_path "${path}"
  done
  shopt -u nullglob
}

configure_ubuntu_mirror() {
  [[ "${SKIP_UBUNTU_MIRROR}" -eq 0 ]] || { log "skip ubuntu mirror"; return; }
  local list=/etc/apt/sources.list
  backup "${list}"
  cat >"${list}" <<'EOF'
deb http://mirrors.aliyun.com/ubuntu-ports/ focal main restricted
deb http://mirrors.aliyun.com/ubuntu-ports/ focal-updates main restricted
deb http://mirrors.aliyun.com/ubuntu-ports/ focal universe
deb http://mirrors.aliyun.com/ubuntu-ports/ focal-updates universe
deb http://mirrors.aliyun.com/ubuntu-ports/ focal multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ focal-updates multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ focal-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ focal-security main restricted universe multiverse
EOF
  log "wrote Aliyun ubuntu-ports sources.list"
}

fetch_ros_asc() {
  local dest="$1"
  # Prefer tuna (HTTP/HTTPS often works on field companions); then upstream.
  local url
  for url in \
    "https://mirrors.tuna.tsinghua.edu.cn/rosdistro/ros.asc" \
    "http://mirrors.tuna.tsinghua.edu.cn/rosdistro/ros.asc" \
    "https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc"
  do
    if curl -fsSL --connect-timeout 8 --max-time 45 "${url}" -o "${dest}"; then
      log "fetched ROS apt key from ${url}"
      return 0
    fi
  done
  return 1
}

configure_ros_source() {
  [[ "${SKIP_ROS_SOURCE}" -eq 0 ]] || { log "skip ROS source"; return; }
  local keyring=/usr/share/keyrings/ros-archive-keyring.gpg
  local list=/etc/apt/sources.list.d/ros-latest.list
  local asc
  asc="$(mktemp /tmp/ros.asc.XXXXXX)"
  fetch_ros_asc "${asc}" || die "could not download ROS apt signing key"
  local fpr
  fpr="$(fingerprint_of "${asc}")"
  [[ "${fpr}" == "${ROS_KEY_FPR}" ]] || die "ROS apt key fingerprint mismatch: ${fpr:-empty}"
  gpg --dearmor --yes -o /tmp/ros-archive-keyring.gpg "${asc}"
  install -d -m 0755 /usr/share/keyrings
  install -m 0644 /tmp/ros-archive-keyring.gpg "${keyring}"
  backup "${list}"
  # Drop legacy unsigned ros lists that apt still picks up under other names.
  local stale base
  shopt -s nullglob
  for stale in /etc/apt/sources.list.d/*ros*.list /etc/apt/sources.list.d/*ros*.sources; do
    base="$(basename -- "${stale}")"
    [[ "${base}" == "ros-latest.list" ]] && continue
    [[ "${base}" == *.bak-* ]] && continue
    quarantine_path "${stale}"
  done
  shopt -u nullglob
  printf 'deb [arch=%s signed-by=%s] http://mirrors.tuna.tsinghua.edu.cn/ros/ubuntu %s main\n' \
    "${ARCH}" "${keyring}" "${APT_SUITE}" >"${list}"
  rm -f "${asc}" /tmp/ros-archive-keyring.gpg
  log "wrote ROS Noetic source with signed-by keyring"
}

configure_xgc2_source() {
  local key_url="${APT_BASE_URL%/}/xgc2-archive-keyring.gpg"
  local key_file
  key_file="$(mktemp /tmp/xgc2-archive-keyring.XXXXXX)"
  curl -fsSL --connect-timeout 10 --max-time 60 "${key_url}" -o "${key_file}" \
    || die "could not download XGC2 apt key from ${key_url}"
  local fpr
  fpr="$(fingerprint_of "${key_file}")"
  [[ "${fpr}" == "${XGC2_KEY_FPR}" ]] || die "XGC2 apt key fingerprint mismatch: ${fpr:-empty}"
  install -d -m 0755 /etc/apt/keyrings
  install -m 0644 "${key_file}" /etc/apt/keyrings/xgc2-archive-keyring.gpg
  rm -f "${key_file}"
  # Quarantine alternate xgc2 list names so only one production line remains.
  local stale base
  shopt -s nullglob
  for stale in /etc/apt/sources.list.d/*xgc2*.list /etc/apt/sources.list.d/*xgc2*.sources; do
    base="$(basename -- "${stale}")"
    [[ "${base}" == "xgc2.list" ]] && continue
    [[ "${base}" == *.bak-* ]] && continue
    quarantine_path "${stale}"
  done
  shopt -u nullglob
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/xgc2-archive-keyring.gpg] %s %s main\n' \
    "${ARCH}" "${APT_BASE_URL%/}" "${APT_SUITE}" \
    >/etc/apt/sources.list.d/xgc2.list
  log "wrote /etc/apt/sources.list.d/xgc2.list (${APT_BASE_URL%/} ${APT_SUITE})"
}

# apt-get update; on failure, quarantine the first still-active foreign list and retry.
apt_update_resilient() {
  local attempt=1
  local max_attempts=8
  local logf
  while [[ "${attempt}" -le "${max_attempts}" ]]; do
    logf="$(mktemp /tmp/apt-update.XXXXXX)"
    log "apt-get update (attempt ${attempt}/${max_attempts})"
    if apt-get update 2>"${logf}"; then
      cat "${logf}" >&2 || true
      rm -f "${logf}"
      return 0
    fi
    cat "${logf}" >&2 || true
    if [[ "${SKIP_QUARANTINE_SOURCES}" -ne 0 ]]; then
      rm -f "${logf}"
      die "apt-get update failed and --skip-quarantine-sources is set"
    fi
    # Prefer explicit "The repository '…'" / Failed to fetch lines (mawk-safe).
    local bad host quarantined=0 path base
    bad="$(
      sed -n "s/.*The repository '\\([^']*\\)'.*/\\1/p;s/.*Failed to fetch \\([^ ]*\\).*/\\1/p" "${logf}" \
        | head -n1 || true
    )"
    rm -f "${logf}"
    host="$(printf '%s' "${bad}" | sed -E 's#^[a-zA-Z]+://##' | cut -d/ -f1)"
    shopt -s nullglob
    for path in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
      base="$(basename -- "${path}")"
      is_managed_apt_list "${base}" && continue
      if [[ -n "${bad}" ]]; then
        if grep -Fq "${bad}" "${path}" 2>/dev/null \
          || { [[ -n "${host}" ]] && grep -Fq "${host}" "${path}" 2>/dev/null; }; then
          quarantine_path "${path}"
          quarantined=1
          break
        fi
        continue
      fi
      quarantine_path "${path}"
      quarantined=1
      break
    done
    shopt -u nullglob
    [[ "${quarantined}" -eq 1 ]] || die "apt-get update failed; no foreign list left to quarantine"
    attempt=$((attempt + 1))
  done
  die "apt-get update still failing after quarantining foreign sources"
}

normalize_lan_cidr() {
  local raw="$1" host prefix
  raw="${raw//[[:space:]]/}"
  [[ -n "${raw}" ]] || return 1
  if [[ "${raw}" == */* ]]; then
    host="${raw%/*}"
    prefix="${raw##*/}"
  else
    host="${raw}"
    prefix="24"
  fi
  [[ "${host}" == *.*.*.* ]] || return 1
  # /32 is the known "powered on but SSH hangs until someone pings" bug:
  # no 192.168.51.0/24 on-link route, ARP/return path stays empty after reboot.
  if [[ "${prefix}" == "32" ]]; then
    warn "refusing IPv4 /32 (breaks on-link ARP); using ${host}/24"
    prefix="24"
  fi
  [[ "${prefix}" == "24" ]] || die "field IPv4 must be /24, got ${host}/${prefix}"
  printf '%s/%s\n' "${host}" "${prefix}"
}

prompt_lan_address() {
  if [[ -n "${LAN_ADDRESS}" ]]; then
    return 0
  fi
  # Prefer /dev/tty so `ssh host 'sudo bash -s' < script` can still prompt.
  if [[ -r /dev/tty ]]; then
    printf 'Field IPv4 (gateway %s / dns %s, prefix /24, e.g. 192.168.51.24): ' \
      "${LAN_GATEWAY}" "${LAN_DNS}" >/dev/tty
    read -r LAN_ADDRESS </dev/tty
  fi
  [[ -n "${LAN_ADDRESS}" ]] || die "need --lan-address (or type it on a TTY)"
}

active_wifi_connection() {
  nmcli -t -f NAME,TYPE connection show --active \
    | awk -F: '$2 == "802-11-wireless" { print $1; exit }'
}

apply_static_ipv4() {
  local profile="$1"
  local cidr="$2"
  nmcli connection modify "${profile}" \
    connection.autoconnect yes \
    connection.autoconnect-priority 100 \
    ipv4.method manual \
    ipv4.addresses "${cidr}" \
    ipv4.gateway "${LAN_GATEWAY}" \
    ipv4.dns "${LAN_DNS}" \
    ipv4.ignore-auto-dns yes
}

# Same host, prefix only: never `connection up` (that drops SSH). Add /24
# first so the current session stays, then drop the bad /32 and reapply NM.
apply_live_ipv4_prefix() {
  local iface="$1"
  local cidr="$2"
  local host="${cidr%/*}"
  local live live_host
  live="$(ip -4 -o addr show dev "${iface}" 2>/dev/null | awk '{print $4; exit}')"
  [[ -n "${live}" ]] || return 0
  live_host="${live%/*}"
  if [[ "${live_host}" != "${host}" ]]; then
    warn "live ${iface} is ${live}, profile now ${cidr}; not applying (would drop SSH)"
    return 0
  fi
  if [[ "${live}" == "${cidr}" ]]; then
    log "${iface} already ${cidr}"
    return 0
  fi
  log "same host ${host}; apply ${live} -> ${cidr} without reconnect"
  ip addr add "${cidr}" dev "${iface}" 2>/dev/null || true
  [[ "${live}" == "${cidr}" ]] || ip addr del "${live}" dev "${iface}" 2>/dev/null || true
  if nmcli device reapply "${iface}"; then
    log "nmcli device reapply ${iface}"
  else
    warn "reapply failed; kernel may already be ${cidr} until next NM refresh"
  fi
}

# Network LAST. Write NM profile + static IPv4. Never `connection up` here —
# applying a live address/SSID change drops the SSH session mid-run.
configure_wifi() {
  if [[ "${SKIP_WIFI}" -eq 1 ]]; then
    log "skip Wi-Fi / addressing"
    return
  fi
  if [[ -z "${WIFI_SSID}" && -z "${LAN_ADDRESS}" ]]; then
    log "no --wifi-ssid / --lan-address; leave NetworkManager alone"
    return
  fi
  need_cmd nmcli
  prompt_lan_address
  local cidr
  cidr="$(normalize_lan_cidr "${LAN_ADDRESS}")" \
    || die "invalid --lan-address: ${LAN_ADDRESS}"
  [[ "${cidr}" == *.*.*.*/* ]] || die "expected IPv4 CIDR, got ${cidr}"

  local profile=""
  if [[ -n "${WIFI_SSID}" ]]; then
    profile="$(nmcli -t -f NAME,UUID,TYPE connection show \
      | awk -F: -v ssid="${WIFI_SSID}" '$1 == ssid && $3 == "802-11-wireless" { print $1; exit }')"
  else
    profile="$(active_wifi_connection)"
    [[ -n "${profile}" ]] || die "no active Wi-Fi; pass --wifi-ssid to name the profile"
    log "no --wifi-ssid; using active Wi-Fi profile '${profile}'"
  fi

  if [[ -n "${profile}" ]]; then
    log "write static IPv4 on profile '${profile}' (no reconnect)"
    apply_static_ipv4 "${profile}" "${cidr}"
    if [[ -n "${WIFI_SSID}" ]]; then
      nmcli connection modify "${profile}" 802-11-wireless.ssid "${WIFI_SSID}"
    fi
    if [[ -n "${WIFI_PASSWORD}" ]]; then
      nmcli connection modify "${profile}" \
        802-11-wireless-security.key-mgmt wpa-psk \
        802-11-wireless-security.psk "${WIFI_PASSWORD}"
    fi
  else
    [[ -n "${WIFI_PASSWORD}" ]] || die "no existing '${WIFI_SSID}' profile; pass --wifi-password to create one"
    log "create Wi-Fi profile '${WIFI_SSID}' on ${WIFI_IFACE} (no connect now)"
    nmcli connection add type wifi ifname "${WIFI_IFACE}" con-name "${WIFI_SSID}" \
      ssid "${WIFI_SSID}" \
      connection.autoconnect yes \
      connection.autoconnect-priority 100 \
      802-11-wireless-security.key-mgmt wpa-psk \
      802-11-wireless-security.psk "${WIFI_PASSWORD}" \
      ipv4.method manual \
      ipv4.addresses "${cidr}" \
      ipv4.gateway "${LAN_GATEWAY}" \
      ipv4.dns "${LAN_DNS}" \
      ipv4.ignore-auto-dns yes
    profile="${WIFI_SSID}"
  fi
  log "NM saved ${profile} -> ${cidr} gw ${LAN_GATEWAY} dns ${LAN_DNS}"
  apply_live_ipv4_prefix "${WIFI_IFACE}" "${cidr}"
  log "not running nmcli connection up (would drop SSH if SSID/host changes)"
}

discover_conflict_units() {
  local unit path
  # Known names.
  printf '%s\n' "${CONFLICT_UNITS[@]}"
  # Any unit file whose name smells like mavlink / startMav.
  shopt -s nullglob
  for path in \
    /etc/systemd/system/*.service \
    /lib/systemd/system/*.service \
    /usr/lib/systemd/system/*.service
  do
    unit="$(basename -- "${path}")"
    [[ "${unit}" == "${ROUTER_UNIT}" ]] && continue
    case "${unit}" in
      *[Mm]av[Ll]ink*|startMav*|fs150-mav*) printf '%s\n' "${unit}" ;;
    esac
  done
  shopt -u nullglob
}

stop_conflicts() {
  local unit
  systemctl daemon-reload >/dev/null 2>&1 || true
  # shellcheck disable=SC2207
  local units=( $(discover_conflict_units | sort -u) )
  for unit in "${units[@]}"; do
    if systemctl cat "${unit}" >/dev/null 2>&1; then
      log "stop/disable/mask ${unit}"
      systemctl stop "${unit}" >/dev/null 2>&1 || true
      systemctl disable "${unit}" >/dev/null 2>&1 || true
      # Mask so a vendor package reinstall cannot re-enable under our feet.
      systemctl mask "${unit}" >/dev/null 2>&1 || true
    else
      log "conflict unit absent: ${unit}"
    fi
  done

  # Leftover hand-started binaries (common on vendor images).
  local pid cmd main_pid
  main_pid="$(systemctl show -p MainPID --value "${ROUTER_UNIT}" 2>/dev/null || echo 0)"
  while read -r pid cmd; do
    [[ -z "${pid}" ]] && continue
    if [[ -n "${main_pid}" && "${main_pid}" != "0" && "${pid}" == "${main_pid}" ]]; then
      continue
    fi
    log "kill leftover mavlink process pid=${pid} cmd=${cmd}"
    kill "${pid}" >/dev/null 2>&1 || true
    sleep 0.2
    kill -9 "${pid}" >/dev/null 2>&1 || true
  done < <(ps -eo pid=,args= | awk '/mavlink-routerd/ && !/awk/ { print $1, $0 }')

  if command -v fuser >/dev/null 2>&1 && [[ -e "${UART_DEVICE}" ]]; then
    local holders holder_pids our=0 other=0
    holders="$(fuser "${UART_DEVICE}" 2>/dev/null || true)"
    for pid in ${holders}; do
      pid="${pid//[^0-9]/}"
      [[ -z "${pid}" ]] && continue
      if [[ -n "${main_pid}" && "${main_pid}" != "0" && "${pid}" == "${main_pid}" ]]; then
        our=1
        continue
      fi
      # Child threads of our routerd share the fd — treat same executable as ours.
      if [[ -n "${main_pid}" && "${main_pid}" != "0" ]] \
        && [[ "$(readlink -f "/proc/${pid}/exe" 2>/dev/null || true)" == \
              "$(readlink -f "/proc/${main_pid}/exe" 2>/dev/null || true)" ]]; then
        our=1
        continue
      fi
      other=1
      holder_pids="${holder_pids} ${pid}"
    done
    if [[ "${other}" -eq 1 ]]; then
      warn "${UART_DEVICE} held by foreign pids${holder_pids}; sending TERM"
      # shellcheck disable=SC2086
      kill -TERM ${holder_pids} >/dev/null 2>&1 || true
      sleep 0.5
      # shellcheck disable=SC2086
      kill -KILL ${holder_pids} >/dev/null 2>&1 || true
    elif [[ "${our}" -eq 1 ]]; then
      log "${UART_DEVICE} held only by ${ROUTER_UNIT}; leave it"
    fi
  fi
}

note_preexisting_uart_baud() {
  local line baud
  line="$(ps -eo args= | awk '/mavlink-routerd/ && !/awk/ { print; exit }' || true)"
  if [[ -z "${line}" ]]; then
    log "no preexisting mavlink-routerd; cannot infer prior UART baud"
    return
  fi
  log "preexisting routerd: ${line}"
  baud="$(printf '%s' "${line}" | sed -nE "s#.*${UART_DEVICE}:([0-9]+).*#\1#p")"
  if [[ -z "${baud}" ]]; then
    baud="$(printf '%s' "${line}" | tr ' ' '\n' | awk -F= '/^Baud$/ {getline; print; exit}')"
  fi
  if [[ -n "${baud}" && "${baud}" != "${EXPECT_BAUD}" ]]; then
    warn "preexisting UART baud ${baud} != required ${EXPECT_BAUD}"
    warn "after switch, PX4 SER_TELx_BAUD (or this airframe UART) must be ${EXPECT_BAUD}"
  fi
}

install_router_package() {
  apt_update_resilient
  log "apt-get install -y --no-install-recommends ${ROUTER_PKG}"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${ROUTER_PKG}"
  dpkg -s "${ROUTER_PKG}" >/dev/null
  dpkg -s xgc2-mavlink-router >/dev/null
  test -f "${ROUTER_CONF}"
  grep -q "^Baud = ${EXPECT_BAUD}$" "${ROUTER_CONF}" \
    || die "expected packaged Baud = ${EXPECT_BAUD} in ${ROUTER_CONF}"
  grep -q "^Device = ${UART_DEVICE}$" "${ROUTER_CONF}" \
    || die "expected Device = ${UART_DEVICE} in ${ROUTER_CONF}"
}

enable_router() {
  stop_conflicts
  log "enable --now ${ROUTER_UNIT}"
  systemctl unmask "${ROUTER_UNIT}" >/dev/null 2>&1 || true
  systemctl enable --now "${ROUTER_UNIT}"
  systemctl is-active --quiet "${ROUTER_UNIT}" || die "${ROUTER_UNIT} failed to start"
  systemctl is-enabled --quiet "${ROUTER_UNIT}" || die "${ROUTER_UNIT} not enabled"
  # Confirm journal reports the hard-rule baud.
  if ! journalctl -u "${ROUTER_UNIT}" -n 30 --no-pager 2>/dev/null \
      | grep -Eq "speed = ${EXPECT_BAUD}|Baud = ${EXPECT_BAUD}"; then
    # Fall back to conf + process cmdline.
    if ! tr '\0' ' ' <"/proc/$(systemctl show -p MainPID --value "${ROUTER_UNIT}")/cmdline" 2>/dev/null \
        | grep -Fq "${ROUTER_CONF}"; then
      warn "could not confirm ${EXPECT_BAUD} from journal; conf still requires it"
    fi
  fi
  log "router reports ${UART_DEVICE} @ ${EXPECT_BAUD}"
}

# Fail early when FC is still at another baud (common vendor default 115200).
verify_fc_heartbeat() {
  if [[ "${SKIP_LINK_CHECK}" -ne 0 ]]; then
    warn "skipping HEARTBEAT link check (--skip-link-check)"
    return 0
  fi
  log "link check: wait up to ${LINK_CHECK_SECONDS}s for FC HEARTBEAT on ${LOCAL_MAVLINK_UDP} (baud ${EXPECT_BAUD})"
  if python3 - "${LOCAL_MAVLINK_UDP}" "${LINK_CHECK_SECONDS}" <<'PY'
import sys, socket, time, struct

target, seconds = sys.argv[1], float(sys.argv[2])
host, port_s = target.rsplit(":", 1)
port = int(port_s)

def crc_x25(data: bytes) -> int:
    crc = 0xFFFF
    for b in data:
        tmp = b ^ (crc & 0xFF)
        tmp ^= (tmp << 4) & 0xFF
        crc = ((crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)) & 0xFFFF
    return crc

# MAVLink v1 HEARTBEAT from GCS (sys 255, comp 190). crc_extra for HEARTBEAT = 50.
payload = struct.pack("<IBBBBB", 0, 6, 8, 0, 0, 0)  # custom_mode, type, autopilot, base_mode, system_status, mavlink_version
seq = 0
header = struct.pack("<BBBBBB", 0xFE, len(payload), seq, 255, 190, 0)
crc = crc_x25(header[1:] + payload + bytes([50]))
pkt = header + payload + struct.pack("<H", crc)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(0.5)
# Ephemeral local bind so the router's UDP Server has a return path.
sock.bind(("0.0.0.0", 0))
deadline = time.time() + seconds
got = False
while time.time() < deadline:
    try:
        sock.sendto(pkt, (host, port))
    except OSError:
        pass
    try:
        data, _addr = sock.recvfrom(2048)
    except socket.timeout:
        continue
    if not data:
        continue
    # Any MAVLink framing from the FC path is enough; prefer HEARTBEAT msgid 0.
    if data[0] in (0xFE, 0xFD):
        # v1: msgid at [5]; v2: msgid at [7:10] little-endian 24-bit
        if data[0] == 0xFE and len(data) >= 6 and data[5] == 0:
            # Ignore our own GCS heartbeats if echoed (sysid 255).
            if len(data) >= 4 and data[3] != 255:
                got = True
                break
        elif data[0] == 0xFD and len(data) >= 10:
            msgid = data[7] | (data[8] << 8) | (data[9] << 16)
            sysid = data[5]
            if msgid == 0 and sysid != 255:
                got = True
                break
        elif data[0] in (0xFE, 0xFD) and (len(data) < 4 or data[3] != 255):
            # Non-GCS traffic on the FC link — accept as link-up.
            if data[0] == 0xFD and len(data) >= 6 and data[5] != 255:
                got = True
                break
            if data[0] == 0xFE and len(data) >= 4 and data[3] != 255:
                got = True
                break
sock.close()
sys.exit(0 if got else 2)
PY
  then
    log "HEARTBEAT/link OK on ${LOCAL_MAVLINK_UDP}"
    return 0
  fi

  cat >&2 <<EOF
error: no FC MAVLink on ${LOCAL_MAVLINK_UDP} within ${LINK_CHECK_SECONDS}s after enabling ${EXPECT_BAUD}.

Companion UART is correctly set to ${EXPECT_BAUD} (hard rule). The usual cause is
the flight controller still running another baud (often 115200 on vendor images).

Fix:
  1. Connect QGC to the FC with a **wired serial** link (not this Wi-Fi MAVLink path).
  2. Set PX4 **SER_TEL1_BAUD** to ${EXPECT_BAUD} (FS-150: TELEM1 ↔ ${UART_DEVICE}).
  3. Save parameters / reboot FC if required.
  4. Retest:  systemctl restart ${ROUTER_UNIT}
     or re-run this script.

Do **not** lower Baud in ${ROUTER_CONF}.
To install services anyway without a live link, re-run with --skip-link-check.
EOF
  return 1
}

smoke() {
  log "smoke"
  systemctl --no-pager --full status "${ROUTER_UNIT}" | sed -n '1,25p'
  ss -lntup 2>/dev/null | grep -E ':5760|:14560|:14561' || true
  if [[ -d "${QUARANTINE_DIR}" ]]; then
    log "quarantined apt sources under ${QUARANTINE_DIR}"
  fi
  cat <<EOF
+ hard rule: companion UART Baud = ${EXPECT_BAUD} (do not lower it)
+ remote QGC/MAVROS: UDP ${UART_DEVICE%@*} host:14560 or TCP host:5760
+ onboard MAVROS (if used later): udp://:14551@127.0.0.1:14561
EOF
  log "done"
}

note_preexisting_uart_baud
quarantine_foreign_apt_lists
configure_ubuntu_mirror
configure_ros_source
configure_xgc2_source
install_router_package
enable_router
link_rc=0
verify_fc_heartbeat || link_rc=$?
smoke
configure_wifi
exit "${link_rc}"
