#!/bin/bash

# This tool will validate integrity of file against cryptographic hash that is fetched from NEM blockchain using
# "txId" parameter found from ".sig" file.
#
# Cryptographic (this script supports: MD5, SHA1, SHA256 and SHA3) hash will be downloaded from NEM blockchain 
# and validated against cryptographic hash gotten from file.

# This script depends on programs: curl, jq, sed, sha1sum, sha256sum and sha3sum
# Ubuntu: sha3sum is provided from "libdigest-sha3-perl" package
# Fedora / RHEL: sha3sum is provided by "sha3sum" package

MISSINGPROGS=""

if [ "$1" == "" ]; then
    echo "Please provide file to check integrity"
    exit
fi

if [ ! -f $1 ]; then
    echo "File does not exist."
    echo "Aborting..."
    exit
fi

if [ ! -f $1.sig ]; then
    echo "Signature file does not exist. (looking for a file named: $1.sig)"
    echo "Aborting..."
    exit
fi

txId=$(grep txId $1.sig | sed -e 's/txId: //')
if [ "$txId" == "" ]; then
    echo "Signature file did not contain NEM blockchain txId parameter. Aborting..."
    exit
fi

#Check for programs
if [ ! -f /usr/bin/jq ]; then
    MISSINGPROGS="${MISSINGPROGS} jq"
fi

if [ ! -f /bin/sed ]; then
    MISSINGPROGS="${MISSINGPROGS} sed"
fi

if [ ! -f /usr/bin/curl ]; then
    MISSINGPROGS="${MISSINGPROGS} curl"
fi

if [ ! -f /usr/bin/md5sum ]; then
    MISSINGPROGS="${MISSINGPROGS} md5sum"
fi

if [ ! -f /usr/bin/sha1sum ]; then
    MISSINGPROGS="${MISSINGPROGS} sha1sum"
fi

if [ ! -f /usr/bin/sha256sum ]; then
    MISSINGPROGS="${MISSINGPROGS} sha256sum"
fi

if [ ! -f /usr/bin/sha3sum ]; then
    MISSINGPROGS="${MISSINGPROGS} sha3sum"
fi

function hex2string () {
  I=0
  while [ $I -lt ${#1} ];
  do
    echo -en "\x"${1:$I:2}
    let "I += 2"
  done
}

if [ ${#MISSINGPROGS} -gt 2 ]; then
    echo "Following programs missing: $MISSINGPROGS"
    echo "NOTE: sha3sum is found from ubuntu package libdigest-sha3-perl, Fedora/RHEL package is sha3sum"
    echo "Aborting..."
    exit
fi


apostilleHash=$(curl -s http://bigalice3.nem.ninja:7890/transaction/get?hash=$txId | jq -r '.transaction.message.payload')

if [ "$apostilleHash" == "" ]; then
    echo "Could not fetch Apostille hash from blockchain."
    echo "You can check if you get anything in browser using URL: http://bigalice3.nem.ninja:7890/transaction/get?hash=$txId"
    echo "Aborting..."
    exit
fi

checksum=${apostilleHash:0:10}
hashingVersionBytes=${checksum:8:2}
cryptoHash=${apostilleHash:10}
fileHash=""
message=""
signed=${hashingVersionBytes:1}

if [ "$signed" == "8" ]; then
    echo "Hash is signed, cannot check integrity just yet. Aborting..."
    exit
fi

if [ "$hashingVersionBytes" == "01" ]; then
    hashFunction="md5sum"
    fileHash=${cryptoHash:0:32}
    message=${cryptoHash:36}
elif [ "$hashingVersionBytes" == "02" ]; then
    hashFunction="sha1sum"
    fileHash=${cryptoHash:0:40}
    message=${cryptoHash:44}
elif [ "$hashingVersionBytes" == "03" ]; then    
    hashFunction="sha256sum"
    fileHash=${cryptoHash:0:64}
    message=${cryptoHash:68}
elif [ "$hashingVersionBytes" == "08" ]; then
    hashFunction="sha3sum -a 256"
    fileHash=${cryptoHash:0:64}
    message=${cryptoHash:68}
else 
    hashFunction="sha3sum -a 512"
    fileHash=${cryptoHash:0:128}
    message=${cryptoHash:132}
fi

echo "$fileHash $1" > /tmp/validateNemSignature.tmp.$1

eval "$hashFunction -c /tmp/validateNemSignature.tmp.$1"

if [ ${#message} -gt 0 ]; then
    echo "Apostille hash contained also following message:"
    hex2string $message
fi
echo ""
rm /tmp/validateNemSignature.tmp.$1
