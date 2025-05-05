#!/usr/bin/env bash
export PATH="$PATH:@extraPATH@"

shopt -s extglob nullglob
set -u
set +e
@debug@ && set -x

declare -i KEEP_DAYS KEEP_WEEKS DAYS_COUNTER WEEKS_COUNTER
declare -a TRASH_DIRS
declare -l DATE_NOW

KEEP_DAYS=@keepDays@
KEEP_WEEKS=@keepWeeks@

BASE_DIR=@snapshotDir@
USER_NAME=@userName@
USER_GROUP=@userGroup@
USER_HOME=@userHome@
TRASH_DIRS=(@trashDirs@)

DATE_NOW="$(date +%Y-%m-%d_%H-%M-%S)"
DAYS_COUNTER=$(date +%Y%W%u)
WEEKS_COUNTER=$(date +%Y%W)

PREFIX="$BASE_DIR/$USER_NAME/$WEEKS_COUNTER/$DAYS_COUNTER"
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

    # remove entries that are not supposed to exist (they lie in the future)
    for i in $(printf '%s\n' +([0-9])/+([0-9]) | gawk -F '/' \
        -v upperDy=$DAYS_COUNTER -v upperWk=$WEEKS_COUNTER \
            '
            $1 > upperWk { print $1 }
            $2 > upperDy { print $0 }
            '); do
        trash "$i"
    done

    for i in $(printf '%s\n' +([0-9])/+([0-9]) | sort -rn -t '/' -k2 | head -n $KEEP_DAYS ); do
        keep+=("$i")
    done
    for i in $(printf '%s\n' +([0-9]) | sort -rn | head -n $KEEP_WEEKS ); do
        for j in $(printf '%s\n' "$i"/+([0-9]) | sort -rn -t '/' -k2 | head -n 1); do
            keep+=("$j")
        done
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