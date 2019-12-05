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
if [ -z "${IWIPFSENCRYPTION-}" ]; then
  IWIPFSENCRYPTION="symmetric"
fi

# Check deps
function checkdep() {
  if ! command -pv "${1:-}"; then
    echo >&2 "${1:-} not found"
    exit 1
  fi
}

# Generate Password
function generate_password() {
  echo "$(tr </dev/urandom -dc A-Za-z0-9 | head -c $1)"
}

case "${1:-}" in

send)

  # Get path to deps
  TARCMD="$(checkdep tar)"
  GPGCMD="$(checkdep gpg)"
  IPFSCMD="$(checkdep ipfs)"
  PASSWORD="$(generate_password "${IWPASSWORDLENGTH}")"

  # Handle user input
  USERINPUT=${2:-}
  FILE=${USERINPUT%/}

  # Check if ipfs is running and if no, start it
  if ! pgrep ipfs 1>/dev/null 2>&1; then
    echo "IPFS is not running, starting the daemon and sleep 5 seconds"
    $IPFSCMD daemon &
    sleep 5
  fi

  # Choose between symmetric/asymmetric encryption
  case ${IWIPFSENCRYPTION} in
  symmetric)
    # Set passphrase for asymmetric encryption, if required
    ENCRYPTIONCMD="$GPGCMD --batch --passphrase=$PASSWORD -c -o -"
    ;;
  asymmetric)
    # Will prompt for the public keys of recipients
    ENCRYPTIONCMD="$GPGCMD -e -o -"
    ;;
  no)
    # No encryption, `transfer.sh`-like mode, to allow a direct retrieval from
    # the IPFS gateway
    ENCRYPTIONCMD="cat"
    ;;
  *)
    cat <<EOF
ENCRYPTIONCMD should be either 'symmetric' (default), 'asymmetric' (advanced) or 'no' (ala transfer.sh)
EOF
    exit 1
    ;;
  esac

  if [ -d "$FILE" ]; then
    # If FILE is a directory (!): compress, encrypt and add to IFPS
    IFS=' '
    TAG=$($TARCMD -Jc "$FILE" | $ENCRYPTIONCMD | $IPFSCMD add -Q)
    IFS=$'\n\t'
    FILE="$FILE".tar.xz
  elif [ -f "$FILE" ]; then
    # If FILE is a file :) : encrypt and add to IFPS
    IFS=' '
    TAG=$($ENCRYPTIONCMD "$FILE" | $IPFSCMD add -Q)
    IFS=$'\n\t'
  else
    # If FILE is neither a file or a directory, exit
    echo "error: $FILE is neither a file, nor a directory"
    exit 1
  fi

  EXTRA=""
  if [ "$ENCRYPTIONCMD" == "cat" ]; then
    # If no encryption was requested, just print out the URL of the IPFS gateway
    # with the hash, and store it in the clipboard
    RECEIVECMD="from $IWIPFSGATEWAY/$TAG"
    FULLTAG="$IWIPFSGATEWAY/$TAG"
  else
    # If encryption is enabled:
    # - Create the tag: <IPFSHASH>-<PASSWORD>-<BASE64 ENCODED FILENAME>
    # - print out the link to retrieve the content with `ipfs-wormhole`
    FULLTAG="$TAG-$PASSWORD-$(echo "$FILE" | base64)"
    RECEIVECMD="with $0 receive $FULLTAG"
  fi

  # Check if xclip is available
  set +e
  XCLIPCMD="$(command -v xclip)"
  set -e
  # Send the full tag to the clipboard
  EXTRA=""
  if [ -n "$XCLIPCMD" ]; then
    echo "$FULLTAG" | $XCLIPCMD
    EXTRA="(copied to clipboard)"
  fi

  # Output
  echo
  echo "$FILE sent, tag: $FULLTAG"
  echo
  echo "Retrieve it $RECEIVECMD $EXTRA"
  echo

  exit 0
  ;;

receive)

  # Get path to deps
  GPGCMD="$(checkdep gpg)"

  # Handle user input
  USERINPUT=${2:-}
  IPFSHASH=${USERINPUT%%-*}
  case "$OSTYPE" in
  linux-gnu)
    BASE64FLAG="-d"
    ;;
  darwin*)
    BASE64FLAG="-D"
    ;;
  esac
  DSTFILENAME="$(echo "${USERINPUT##*-}" | base64 $BASE64FLAG)"
  PASSWORD=${USERINPUT%-*}
  PASSWORD=${PASSWORD#*-}

  # Check if the file already exists, protect it if its size is >0
  if [ -s "$DSTFILENAME" ]; then
    echo "File $DSTFILENAME already exists, aborting..."
    exit 1
  fi

  # Check whether IPFS is running
  if pgrep ipfs 1>/dev/null 2>&1; then
    # If yes, download from IPFS
    IPFSCMD="$(checkdep ipfs)"
    echo "Receiving $DSTFILENAME over IPFS..."
    $IPFSCMD cat "$IPFSHASH" |
      $GPGCMD --batch --passphrase="$PASSWORD" -d \
        >"$DSTFILENAME" \
        2>/dev/null
  else
    # If no, download from an IPFS gateway
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
  # Check if all dependencies are installed
  TARCMD="$(checkdep tar)"
  GPGCMD="$(checkdep gpg)"
  IPFSCMD="$(checkdep ipfs)"
  WGETCMD="$(checkdep wget)"
  echo "Everything looks good"
  exit 0
  ;;

update)
  # Update directly from github
  WGETCMD="$(checkdep wget)"
  echo Update...
  $WGETCMD -O "${0:-}" \
    https://raw.githubusercontent.com/aurelg/ipfs-wormhole/master/ipfs-wormhole.sh
  chmod +x "${0:-}"
  exit 0
  ;;

*)
  # Show usage, i.e. download the readme from github.
  WGETCMD="$(checkdep wget)"
  $WGETCMD -O- -q \
    https://raw.githubusercontent.com/aurelg/ipfs-wormhole/master/README.md
  ;;
esac
