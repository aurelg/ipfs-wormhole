# ipfs-wormhole

Get things from one computer to another, safely. Over IPFS.

Inspired by [magic-wormhole](https://github.com/warner/magic-wormhole) and
[dat-cp](https://github.com/tom-james-watson/dat-cp). Initially published
[here](https://www.reddit.com/r/ipfs/comments/9yyqi1/dat_dcpstyle_functionality_for_encrypted_assets/?utm_source=reddit-android).

# Usage

## Send a file

On machine A:

```
ipfs-wormhole.sh send <filename>
```

Will encrypt and add the file to IPFS, and output a tag (and copy it to the
clipboard if xclip is installed).

## Receive a file

On machine B:

```
ipfs-wormhole.sh receive <tag>
```

Will retrieve the file over IPFS, decrypt it and save it locally.

## Update from the github repo

```
ipfs-wormhole.sh update
```
