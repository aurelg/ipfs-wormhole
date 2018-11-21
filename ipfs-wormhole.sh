#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Send/receive encrypted files using IPFS.
#
# The file to send is encrypted with a temporary password, and added to IPFS.
# The IPFS hash and the password are merged in a key, which can be used to
# retrieve an decrypt the content of the file.
#
# Dependencies:
# - pwgen
# - gpg
# - ipfs

case "${1:-}" in
send)
  echo "Send..."
  PASSWORD=$(pwgen -1 20)
  FILE=${2:-}
  TAG=$(cat "$FILE" |
    gpg --batch --passphrase="$PASSWORD" -c -o - |
    ipfs add -Q)
  echo "Retrieve with $0 receive $TAG$PASSWORD"
  exit 0
  ;;
receive)
  echo "Receive..."
  ipfs cat "${2:0:46}" | gpg --batch --passphrase="${2:46:66}" -d 2>/dev/null
  exit 0
  ;;
esac

echo "${0:-} send <filename>"
echo "${0:-} receive <tag>"
