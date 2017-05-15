#!/bin/bash

# This tool will validate integrity of file against cryptographic hash that is fetched from NEM blockchain using
# "txId" parameter found from ".sig" file.
#
# Cryptographic (this script supports: MD5, SHA1 and SHA256) hash will be downloaded from NEM blockchain 
# and validated against ryptographic hash gotten from file.

# This script depends on programs: curl, jq, sed, sha1sum, sha256sum

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
    echo "Program \"jq\" missing. Aborting..."
    exit
fi

if [ ! -f /bin/sed ]; then
    echo "Program \"sed\" missing. Aborting..."
    exit
fi

if [ ! -f /usr/bin/curl ]; then
    echo "Program \"curl\" missing. Aborting..."
    exit
fi

if [ ! -f /usr/bin/md5sum ]; then
    echo "Program \"sha256sum\" missing. Aborting..."
    exit
fi

if [ ! -f /usr/bin/sha1sum ]; then
    echo "Program \"sha256sum\" missing. Aborting..."
    exit
fi

if [ ! -f /usr/bin/sha256sum ]; then
    echo "Program \"sha256sum\" missing. Aborting..."
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
signed=${hashingVersionBytes:1}

if [ "$signed" == "8" ]; then
    echo "Hash is signed, cannot check integrity just yet. Aborting..."
    exit
fi

if [ "$hashingVersionBytes" == "01" ]; then
    hashFunction="md5sum"
elif [ "$hashingVersionBytes" == "02" ]; then
    hashFunction="sha1sum"
elif [ "$hashingVersionBytes" == "03" ]; then    
    hashFunction="sha256sum"
elif [ "$hashingVersionBytes" == "08" ]; then
    echo "256bit SHA3 not supported yet. Aborting..."
    exit
else 
    echo "512bit SHA3 not supported yet. Aborting..."
    exit
fi

echo "$cryptoHash $1" > /tmp/validateNemSignature.tmp.$1

eval "$hashFunction -c /tmp/validateNemSignature.tmp.$1"

rm /tmp/validateNemSignature.tmp.$1
