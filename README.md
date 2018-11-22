# ipfs-wormhole

Get things from one computer to another, safely. Over IPFS.

Inspired by [magic-wormhole](https://github.com/warner/magic-wormhole) and
[dat-cp](https://github.com/tom-james-watson/dat-cp). Initially published
[here](https://www.reddit.com/r/ipfs/comments/9yyqi1/dat_dcpstyle_functionality_for_encrypted_assets/?utm_source=reddit-android).

# Usage

## Send a file or a directory

On machine A:

```
ipfs-wormhole.sh send <file or directory>
```

Will encrypt and add the file (or the directory as a compressed tarball) to
IPFS, and output a tag. If xclip is installed, the command to retrieve it will
be copied to the clipboard.

## Receive a file or a directory (as a compressed tarball)

On machine B:

```
ipfs-wormhole.sh receive <tag>
```

Will retrieve the file over IPFS, decrypt it and save it locally.

## Check dependencies

```
ipfs-wormhole.sh checkdeps
```

## Update from the github repo

```
ipfs-wormhole.sh update
```
