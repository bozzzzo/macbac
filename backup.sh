#!/bin/sh
#
# Perform incrementaly-style backups with rsync using hardlinking
# and keep the current backup in the root folder of the backup drive
# so effectively having a bootable most-recent backup
#
# see http://www.sanitarium.net/golug/rsync_backups_2010.html
# see http://www.egg-tech.com/mac_backup/
#
BACKUP_ROOT=/Volumes/Elements
BACKUP_DIR="${BACKUP_ROOT}/backup"
BACKUP_DEST="${BACKUP_DIR}/incomplete"
CURRENT="${BACKUP_DIR}/current"

test -d "${BACKUP_ROOT}" || {
  echo "Backup volume ${BACKUP_ROOT} is not present"
  exit 1
}

test -d "${BACKUP_DIR}" || mkdir "${BACKUP_DIR}"


if true; then
/opt/local/bin/rsync "$@" -X --archive --one-file-system --hard-links \
  --human-readable --inplace --numeric-ids --delete \
  --delete-excluded --exclude-from="${0}.excludes.txt" \
  --link-dest="${BACKUP_ROOT}" \
  --log-file="${BACKUP_DEST}.log" \
  / "${BACKUP_DEST}/" || exit $?
fi


#
# move last backup from / to /backups/$current
#
if [ -a "${CURRENT}" ]; then
	echo "CONFUSED, ${CURRENT} should be a dangling symlink or non-existent"
	exit 1
fi

function content() {
	dir="$1"; shift;
	find "$dir" ! -name '.Trashes' ! -name '.DS_Store' ! -name '.Spotlight-*' ! -name '.fseventd' -maxdepth 1 -depth 1 "$@"
}

if [ -h "${CURRENT}" ]; then
	current="${BACKUP_DIR}/$(basename "$(readlink "${CURRENT}")")"
	mkdir "$current" || exit 1
	rm "${CURRENT}"
        content "${BACKUP_ROOT}" -print0 | grep -zv "${BACKUP_DIR}" | xargs -0 -J %% mv %% "$current"
        if [ "$(content "${BACKUP_ROOT}" )" != "${BACKUP_DIR}" ]; then
		echo "Failed to properly move old backup from ${BACKUP_ROOT} to $current"
		exit 1
	fi
else
	echo First backup
fi

# move current backup from /backups/incomplete to /
# and remember it's name to current
STAMP="backup-$(date +%F.%T | tr : -)"
ln -sf "${STAMP}" "${CURRENT}"
ln -sf "${STAMP}.log" "${CURRENT}.log"
content "${BACKUP_DEST}" -print0 | xargs -0 -J %% mv %% "${BACKUP_ROOT}"
mv "${BACKUP_DEST}.log" "${BACKUP_DIR}/${STAMP}.log"
rmdir -p "${BACKUP_DEST}"

BLESSED="${BACKUP_ROOT}/System/Library/CoreServices"
test -d "${BLESSED}" && bless -folder "${BLESSED}"
