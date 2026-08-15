#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

OUTPUT_DIR=""
PROFILE_PACKAGE="xgc2-fs150"
ROUTER_PACKAGE="xgc2-fs150-mavlink-router"
INSTALL_PREFIX="/opt/xgc2/robots/fs150"
ROUTER_ETC_DIR="/etc/xgc2/fs150-mavlink-router"

product_version() {
  awk -F': *' '/^version:[[:space:]]*/ {print $2; exit}' "${REPO_ROOT}/.xgc2/product.yml"
}

VERSION="${PACKAGE_VERSION:-$(product_version)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --install-root)
      # Accepted for compatibility with other XGC2 package scripts.  This
      # repository packages source-owned data directly.
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${OUTPUT_DIR}" ]]; then
  echo "--output-dir is required" >&2
  exit 1
fi

if [[ -z "${VERSION}" ]]; then
  echo "package version is missing" >&2
  exit 1
fi

BUILD_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_DIR}/${PROFILE_PACKAGE}_"*.deb "${OUTPUT_DIR}/${ROUTER_PACKAGE}_"*.deb

build_profile_package() {
  local pkg_root="${BUILD_DIR}/${PROFILE_PACKAGE}"
  local target_root="${pkg_root}${INSTALL_PREFIX}"

  mkdir -p \
    "${pkg_root}/DEBIAN" \
    "${pkg_root}/usr/share/doc/${PROFILE_PACKAGE}" \
    "${target_root}"

  for path in README.md docs onboard px4; do
    if [[ -e "${REPO_ROOT}/${path}" ]]; then
      cp -a "${REPO_ROOT}/${path}" "${target_root}/"
    fi
  done

  cat > "${pkg_root}/DEBIAN/control" <<EOF
Package: ${PROFILE_PACKAGE}
Version: ${VERSION}
Section: metapackages
Priority: optional
Architecture: all
Maintainer: XGC2 <apt@example.com>
Depends: chrony, python3, ros-noetic-ros-base, ros-noetic-mavros, ros-noetic-mavros-extras, ros-noetic-vrpn-client-ros, xgc2-mavlink-router (>= 3.0.0-7+focal)
Recommends: htop, i2c-tools, iproute2, net-tools, python3-pip, socat, tmux, usbutils
Description: XGC2 FS150 real-vehicle profile
 Real FS150 robot/onboard aggregation package for XGC2.
 It installs FS150 vehicle resources under /opt/xgc2/robots/fs150 and pulls
 the ROS Noetic, MAVROS, VRPN, and MAVLink router dependencies expected on
 the FS150 onboard computer. It does not pull Linux host-utils.
EOF

  cat > "${pkg_root}/usr/share/doc/${PROFILE_PACKAGE}/README" <<EOF
XGC2 FS150 Robot

Installed resources:
  ${INSTALL_PREFIX}

This package does not enable or start flight-runtime services automatically.
Install ${ROUTER_PACKAGE} to install the FS150 MAVLink router unit. Enable
it yourself if this aircraft should start the router on boot.
EOF

  find "${pkg_root}" -type d -exec chmod 0755 {} +
  find "${pkg_root}" -type f -exec chmod 0644 {} +
  find "${pkg_root}${INSTALL_PREFIX}/onboard/autostart" -type f \( -name 'start-*' -o -name 'wait-device' \) -exec chmod 0755 {} +
  chmod 0755 "${pkg_root}/DEBIAN"

  fakeroot dpkg-deb --build \
    "${pkg_root}" \
    "${OUTPUT_DIR}/${PROFILE_PACKAGE}_${VERSION}_all.deb" >/dev/null
}

build_router_package() {
  local pkg_root="${BUILD_DIR}/${ROUTER_PACKAGE}"
  local autostart_src="${REPO_ROOT}/onboard/autostart/src/fs150_onboard_autostart"
  local autostart_lib="/usr/lib/xgc2/fs150/autostart"

  mkdir -p \
    "${pkg_root}/DEBIAN" \
    "${pkg_root}/lib/systemd/system" \
    "${pkg_root}/usr/share/doc/${ROUTER_PACKAGE}" \
    "${pkg_root}${ROUTER_ETC_DIR}/config.d" \
    "${pkg_root}/etc/xgc2/fs150" \
    "${pkg_root}${autostart_lib}"

  install -m 0644 \
    "${REPO_ROOT}/onboard/communication/mavlink-router/router.conf" \
    "${pkg_root}${ROUTER_ETC_DIR}/router.conf"
  install -m 0644 \
    "${autostart_src}/config/onboard.env" \
    "${pkg_root}/etc/xgc2/fs150/onboard.env"
  install -m 0755 \
    "${autostart_src}/scripts/wait-device" \
    "${autostart_src}/scripts/start-communication" \
    "${autostart_src}/scripts/start-mavros" \
    "${autostart_src}/scripts/start-mocap" \
    "${autostart_src}/scripts/start-camera" \
    "${autostart_src}/scripts/start-media-edge" \
    "${pkg_root}${autostart_lib}/"
  install -m 0644 \
    "${autostart_src}/systemd/xgc2-fs150-mavlink-router.service" \
    "${pkg_root}/lib/systemd/system/xgc2-fs150-mavlink-router.service"
  install -m 0644 \
    "${autostart_src}/systemd/xgc2-fs150-camera.service" \
    "${pkg_root}/lib/systemd/system/xgc2-fs150-camera.service"
  install -m 0644 \
    "${autostart_src}/systemd/xgc2-fs150-media-edge.service" \
    "${pkg_root}/lib/systemd/system/xgc2-fs150-media-edge.service"
  install -m 0644 \
    "${autostart_src}/systemd/xgc2-fs150-mavros.service" \
    "${pkg_root}/lib/systemd/system/xgc2-fs150-mavros.service"
  install -m 0644 \
    "${autostart_src}/systemd/xgc2-fs150-mocap.service" \
    "${pkg_root}/lib/systemd/system/xgc2-fs150-mocap.service"

  mkdir -p "${pkg_root}/usr/share/xgc2/fs150/mavros/launch"
  install -m 0644 \
    "${REPO_ROOT}/onboard/communication/src/fs150_mavros/launch/mavros.launch" \
    "${pkg_root}/usr/share/xgc2/fs150/mavros/launch/mavros.launch"
  mkdir -p "${pkg_root}/usr/share/xgc2/fs150/mocap/launch"
  install -m 0644 \
    "${REPO_ROOT}/onboard/communication/src/fs150_mocap/launch/vrpn.launch" \
    "${REPO_ROOT}/onboard/communication/src/fs150_mocap/launch/mocap.launch" \
    "${pkg_root}/usr/share/xgc2/fs150/mocap/launch/"
  install -m 0755 \
    "${REPO_ROOT}/onboard/communication/src/fs150_mocap/scripts/vrpn_relay" \
    "${pkg_root}/usr/share/xgc2/fs150/mocap/vrpn_relay"

  for script in postinst prerm postrm; do
    install -m 0755 \
      "${REPO_ROOT}/.xgc2/debian/${ROUTER_PACKAGE}/${script}" \
      "${pkg_root}/DEBIAN/${script}"
  done

  cat > "${pkg_root}/DEBIAN/control" <<EOF
Package: ${ROUTER_PACKAGE}
Version: ${VERSION}
Section: misc
Priority: optional
Architecture: all
Maintainer: XGC2 <apt@example.com>
Depends: xgc2-mavlink-router (>= 3.0.0-7+focal)
Recommends: xgc2-fs150
Description: XGC2 FS150 MAVLink router service
 FS150-specific MAVLink router configuration and systemd units.
 It uses /usr/bin/mavlink-routerd from xgc2-mavlink-router, listens on
 TCP 5760, routes the fixed /dev/ttyS7 flight-controller UART at 921600 baud,
 and exposes filtered remote MAVROS plus unfiltered local MAVROS UDP ports.
 Units are install-only; nothing is enabled or started on install.
EOF

  cat > "${pkg_root}/usr/share/doc/${ROUTER_PACKAGE}/README" <<EOF
XGC2 FS150 MAVLink Router

Installed services (from onboard/autostart):
  xgc2-fs150-mavlink-router.service   (communication, install-only)
  xgc2-fs150-mavros.service           (install-only)
  xgc2-fs150-mocap.service            (install-only)
  xgc2-fs150-camera.service           (install-only)
  xgc2-fs150-media-edge.service       (install-only)

Installed configuration:
  ${ROUTER_ETC_DIR}/router.conf
  ${ROUTER_ETC_DIR}/config.d
  /etc/xgc2/fs150/onboard.env

No unit is enabled or started on install.
It depends on xgc2-mavlink-router for /usr/bin/mavlink-routerd.
EOF

  find "${pkg_root}" -type d -exec chmod 0755 {} +
  find "${pkg_root}" -type f -exec chmod 0644 {} +
  chmod 0755 "${pkg_root}/DEBIAN" \
    "${pkg_root}/DEBIAN/postinst" \
    "${pkg_root}/DEBIAN/prerm" \
    "${pkg_root}/DEBIAN/postrm" \
    "${pkg_root}${autostart_lib}/wait-device" \
    "${pkg_root}${autostart_lib}/start-communication" \
    "${pkg_root}${autostart_lib}/start-mavros" \
    "${pkg_root}${autostart_lib}/start-mocap" \
    "${pkg_root}${autostart_lib}/start-camera" \
    "${pkg_root}${autostart_lib}/start-media-edge" \
    "${pkg_root}/usr/share/xgc2/fs150/mocap/vrpn_relay"

  fakeroot dpkg-deb --build \
    "${pkg_root}" \
    "${OUTPUT_DIR}/${ROUTER_PACKAGE}_${VERSION}_all.deb" >/dev/null
}

build_profile_package
build_router_package

find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "*.deb" -print | sort
