#!/usr/bin/env bash
export PATH="$PATH:@extraPATH@"
                                                                                                   
shopt -s extglob
set -u
set +e
@debug@ && set -x

KEEP_DAYS=@keepDays@
KEEP_WEEKS=@keepWeeks@
                                                                                                   
DATE_NOW="$(date +'%Y-%m-%d_%H-%M-%S')"
DAYS_SINCE_EPOCH=$(( $(date +'%s') / 60 / 60 / 24 ))
WEEKS_SINCE_EPOCH=$(( DAYS_SINCE_EPOCH / 7 ))
                                                                                                   
BASE_DIR=@snapshotDir@
USER_NAME=@userName@
USER_GROUP=@userGroup@
USER_HOME=@userHome@
TRASH_DIRS=(@trashDirs@)

PREFIX="$BASE_DIR/$USER_NAME/$WEEKS_SINCE_EPOCH/$DAYS_SINCE_EPOCH"
SNAPSHOT="$PREFIX/snap"
LOGFILE="$PREFIX/log"
                                                                                                   
trash() {
  # parameter count check
  [ $# -ne 1 ] && return 1
  # if path doesn't exist = no-op
  [ ! -e "$1" ] && return 0
                                                                                                   
  local trashPrefix="$BASE_DIR/.trash"
  local trashDir="$trashPrefix/$DATE_NOW"
  trashDir+="-$(uuidgen -t)"
  echo "trashing \"$1\" --> \"$trashDir\""
  mv "$1" "$trashDir"
                                                                                                   
  chmod 0700 "$trashDir"
  chown root:root "$trashDir"
    # queue a job
    systemd-run --description="Trash $trashDir" rm -rf -- "$trashDir" &>>"$LOGFILE"
}
create() {
  mkdir -p "$PREFIX"
  echo "$DATE_NOW" >"$PREFIX/timestamp"
  echo "CREATED LOG $DATE_NOW" >>"$LOGFILE"
}
cleanup() {
  pushd "$SNAPSHOT" &>/dev/null
  if [ ${#TRASH_DIRS[@]} -gt 0 ]; then
    for i in "${TRASH_DIRS[@]}"; do
      trash "$i"
    done
  fi
  popd &>/dev/null
                                                                                                   
  for i in "$BASE_DIR/$USER_NAME"/!(+([0-9])); do
    trash "$i"
  done
}
remove_old() {
  pushd "$BASE_DIR/$USER_NAME" &>/dev/null
                                                                                                   
  local keep=()
                                                                                                   
  # prepare
  for i in $(printf '%s\n' +([0-9])/+([0-9]) | gawk -F '/' \
      -v upperDy=$DAYS_SINCE_EPOCH -v upperWk=$WEEKS_SINCE_EPOCH \
      '
        $1 > upperWk { print $1 }
        $2 > upperDy { print $0 }
      '); do
    trash "$i"
  done
                                                                                                   
  keep+=( $(printf '%s\n' +([0-9])/+([0-9]) | sort -rn -t '/' -k2 | head -n $KEEP_DAYS ) )
  for i in $(printf '%s\n' +([0-9]) | sort -rn | head -n $KEEP_WEEKS ); do
    keep+=( $(printf '%s\n' +([0-9])/+([0-9]) | sort -rn -t '/' -k2 | head -n 1) )
  done
                                                                                                   
  for i in +([0-9])/+([0-9]); do
    [[ "${keep[*]}" = *"$i"* ]] || trash "$i"
  done
                                                                                                   
  for i in +([0-9]); do
    rmdir --ignore-fail-on-non-empty --parents "$i"
  done
                                                                                                   
  popd &>/dev/null
}
mark_interrupted() {
  echo "snapshot interrupted, see log file $LOGFILE"
  mv "$SNAPSHOT" "$SNAPSHOT-interrupted"
}
mark_errored() {
  echo "snapshot errored, see log file $LOGFILE"
  mv "$SNAPSHOT" "$SNAPSHOT-errored"
}
symlink_aliases() {
  pushd "$BASE_DIR/$USER_NAME" &>/dev/null
  mkdir -p by-date
  chmod 755 by-date
  chown $USER_NAME:$USER_GROUP by-date
  for i in +([0-9])/+([0-9]); do
    [ ! -e "$i"/timestamp ] && continue
    [ ! -e by-date/"$(cat "$i"/timestamp)" ] && ln -nsT -- ../"$i" by-date/"$(cat "$i"/timestamp)"
  done
  popd &>/dev/null
}
fixup() {
  pushd "$BASE_DIR/$USER_NAME" &>/dev/null
  
  find . -mindepth 1 -maxdepth 2 -type d -exec chmod 755 {} \;
  find . -mindepth 3 -maxdepth 3 -type f -exec chmod 600 {} \;
  find . -mindepth 3 -maxdepth 3 -type d -exec chmod 700 {} \;
  
  find . -mindepth 1 -maxdepth 3 -exec chown $USER_NAME:$USER_GROUP {} \;
  
  popd &>/dev/null
}
                    
trap 'mark_interrupted' SIGTERM
                                                                                                   
if [ -e "$PREFIX" ]; then
  echo "warning: prefix already exists, trashing snapshot"
  trash "$SNAPSHOT"?(-errored|-interrupted)
fi
                                                                                                   
echo "create dirs"
create
                                                                                                   
echo "snapshot"
(cp -va --reflink=auto -- "$USER_HOME" "$SNAPSHOT" &>>"$LOGFILE") || mark_errored
                                                                                                   
echo "gc"
remove_old
                                                                                                   
echo "cleanup"
cleanup
                                                                                                   
echo "symlink"
symlink_aliases
                                                                                                   
echo "fixup"
fixup
