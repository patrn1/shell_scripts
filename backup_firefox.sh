#!/bin/bash

echo "User : ${1}";

for d in "/home/${1}/.mozilla/firefox" "/home/${1}/snap/firefox/common/.mozilla/firefox" "/home/${1}/.var/app/org.mozilla.firefox/.mozilla/firefox"; do
  [ -d "$d" ] && FIREFOX_PROFILE_DIR="$d" && break
done

FIREFOX_PROFILE_BACKUP_DIR="${FIREFOX_PROFILE_DIR}_BACKUP"

if [ -z "$FIREFOX_PROFILE_BACKUP_DIR" ]; then

  echo "FIREFOX_PROFILE_BACKUP_DIR IS EMPTY";

  exit;
fi

cp -r "${FIREFOX_PROFILE_DIR}" "${FIREFOX_PROFILE_BACKUP_DIR}"

pkill firefox
tar -czvf firefox-profile-backup-$(date +%F).tar.gz /home/qq/snap/firefox/common/.mozilla/firefox/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/cache2/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/startupCache/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/shader-cache/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/thumbnails/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/minidumps/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/safebrowsing/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/storage/default/*/cache/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/storage/permanent/*/cache/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/crashes/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/datareporting/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/healthreport/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/serviceworker/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/webrtc/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/jumpListCache/
rm -rf ${FIREFOX_PROFILE_BACKUP_DIR}/saved-telemetry-pings/
