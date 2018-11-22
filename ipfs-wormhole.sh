#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Send/receive encrypted files using IPFS.
#
# The file to send is encrypted with a temporary password, and added to IPFS.
# The IPFS hash, the password and the file name are merged in a key, which can
# be used to retrieve, decrypt and save the content of the file.
#
# Dependencies:
# - pwgen
# - gpg
# - ipfs

# Check deps

set +e
PWGENCMD="$(command -v pwgen)"
GPGCMD="$(command -v gpg)"
IPFSCMD="$(command -v ipfs)"
set +e

ERROR=0
if [ -z "$PWGENCMD" ]; then
  echo pwgen not found
  ERROR=1
fi
if [ -z "$GPGCMD" ]; then
  echo gpg not found
  ERROR=1
fi
if [ -z "$IPFSCMD" ]; then
  echo ipfs not found
  ERROR=1
fi

[ "$ERROR" -eq 1 ] && exit 1

case "${1:-}" in
send)
  echo "Send..."
  PASSWORD=$($PWGENCMD -1 20)
  FILE=${2:-}
  TAG=$($GPGCMD --batch --passphrase="$PASSWORD" -c -o - "$FILE" |
    $IPFSCMD add -Q)
  FILENAME="$(echo "$FILE" | base64)"
  RECEIVECMD="$0 receive $TAG$PASSWORD$FILENAME"
  echo "Retrieve with $RECEIVECMD"
  set +e
  XCLIPCMD="$(command -v xclipe)"
  set -e
  if [ -n "$XCLIPCMD" ]; then
    echo "$RECEIVECMD" | $XCLIPCMD
    echo "Copied to clipboard"
  fi
  exit 0
  ;;
receive)
  DSTFILENAME="$(echo "${2:66}" | base64 -d)"
  echo "Receiving $DSTFILENAME..."
  $IPFSCMD cat "${2:0:46}" |
    $GPGCMD --batch --passphrase="${2:46:20}" -d \
      >"$DSTFILENAME" \
      2>/dev/null
  exit 0
  ;;
update)
  echo Update...
  wget -O "${0:-}" \
    https://raw.githubusercontent.com/aurelg/ipfs-wormhole/master/ipfs-wormhole.sh
  exit 0
  ;;
*)
  cat <<EOM
Get things from one computer to another, safely. Over IPFS.

On machine A
------------

${0:-} send <filename>

# Will encrypt and add the file to IPFS, and output a tag (and copy it to the
# clipboard if xclip is installed)

On machine B
------------

${0:-} receive <tag>

# Will retrieve the file over IPFS, decrypt it and save it locally.

Update from github repo
-----------------------

${0:-} update
EOM
  ;;
esac
