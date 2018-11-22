#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# See <https://raw.githubusercontent.com/aurelg/ipfs-wormhole/master/README.md>

if [ -z "${IWPASSWORDLENGTH-}" ]; then
  IWPASSWORDLENGTH=40
fi
if [ -z "${IWIPFSGATEWAY-}" ]; then
  IWIPFSGATEWAY=https://cloudflare-ipfs.com/ipfs
fi

# Check deps

function checkdep() {
  set +e
  CMDPATH="$(command -v "${1:-}")"
  set -e
  if [ -z "$CMDPATH" ]; then
    echo >&2 "${1:-} not found"
    exit 1
  fi
  echo "$CMDPATH"
}

case "${1:-}" in
send)
  PWGENCMD="$(checkdep pwgen)"
  TARCMD="$(checkdep tar)"
  GPGCMD="$(checkdep gpg)"
  IPFSCMD="$(checkdep ipfs)"
  PASSWORD=$($PWGENCMD -1 $IWPASSWORDLENGTH)
  USERINPUT=${2:-}
  FILE=${USERINPUT%/}
  if ! pgrep ipfs 1>/dev/null 2>&1; then
    echo "IPFS is not running, starting the daemon and sleep 5 seconds"
    $IPFSCMD daemon &
    sleep 5
  fi
  if [ -d "$FILE" ]; then
    TAG=$(
      $TARCMD -Jc "$FILE" | $GPGCMD --batch --passphrase="$PASSWORD" \
        -c -o - | $IPFSCMD add -Q
    )
    FILE="$FILE".tar.xz
    echo "Directory compressed and sent as $FILE."
  elif [ -f "$FILE" ]; then
    TAG=$($GPGCMD --batch --passphrase="$PASSWORD" -c -o - "$FILE" |
      $IPFSCMD add -Q)
    echo "File $FILE sent."
  else
    echo "error: $FILE is neither a file, nor a directory"
    exit 1
  fi
  FILENAME="$(echo "$FILE" | base64)"
  FULLTAG="$TAG-$PASSWORD-$FILENAME"
  RECEIVECMD="$0 receive $FULLTAG"
  echo "Retrieve it with $RECEIVECMD"
  set +e
  XCLIPCMD="$(command -v xclip)"
  set -e
  if [ -n "$XCLIPCMD" ]; then
    echo "$FULLTAG" | $XCLIPCMD
    echo "Copied to clipboard"
  fi
  exit 0
  ;;
receive)
  GPGCMD="$(checkdep gpg)"
  USERINPUT=${2:-}
  IPFSHASH=${USERINPUT%%-*}
  DSTFILENAME="$(echo "${USERINPUT##*-}" | base64 -d)"
  PASSWORD=${USERINPUT%-*}
  PASSWORD=${PASSWORD#*-}
  if [ -s "$DSTFILENAME" ]; then
    echo "File $DSTFILENAME already exists, aborting..."
    exit 1
  fi
  if pgrep ipfs 1>/dev/null 2>&1; then
    IPFSCMD="$(checkdep ipfs)"
    echo "Receiving $DSTFILENAME over IPFS..."
    $IPFSCMD cat "$IPFSHASH" |
      $GPGCMD --batch --passphrase="$PASSWORD" -d \
        >"$DSTFILENAME" \
        2>/dev/null
  else
    echo "Receiving $DSTFILENAME over HTTPS..."
    WGETCMD="$(checkdep wget)"
    $WGETCMD -qO - "$IWIPFSGATEWAY"/"$IPFSHASH" |
      $GPGCMD --batch --passphrase="$PASSWORD" -d \
        >"$DSTFILENAME" \
        2>/dev/null
  fi
  exit 0
  ;;
checkdeps)
  PWGENCMD="$(checkdep pwgen)"
  TARCMD="$(checkdep tar)"
  GPGCMD="$(checkdep gpg)"
  IPFSCMD="$(checkdep ipfs)"
  WGETCMD="$(checkdep wget)"
  echo "Everything looks good"
  exit 0
  ;;
update)
  WGETCMD="$(checkdep wget)"
  echo Update...
  $WGETCMD -O "${0:-}" \
    https://raw.githubusercontent.com/aurelg/ipfs-wormhole/master/ipfs-wormhole.sh
  chmod +x "${0:-}"
  exit 0
  ;;
*)
  WGETCMD="$(checkdep wget)"
  $WGETCMD -O- -q \
    https://raw.githubusercontent.com/aurelg/ipfs-wormhole/master/README.md
  ;;
esac
