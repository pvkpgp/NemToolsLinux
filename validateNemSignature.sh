#!/bin/bash

if [ "$1" == "" ]; then
    echo "Please provide file to check signature"
    exit
fi

if [ ! -f $1 ]; then
    echo "File does not exist."
    exit
fi

if [ ! -f $1.sig ]; then
    echo "Signature file does not exist. (looking for a file named: $1.sig)"
    exit
fi

txId=$(grep txId $1.sig | sed -e 's/txId: //')
if [ "$txId" == "" ]; then
    echo "Signature file did not contain NEM blockchain txId parameter. Aborting.."
    exit
fi

#Check for programs
if [ ! -f /usr/bin/jq ]; then
    echo "Program \"jq\" missing. Aborting.."
    exit
fi

if [ ! -f /bin/sed ]; then
    echo "Program \"sed\" missing. Aborting.."
    exit
fi

if [ ! -f /usr/bin/curl ]; then
    echo "Program \"curl\" missing. Aborting.."
    exit
fi

if [ ! -f /usr/bin/sha256sum ]; then
    echo "Program \"sha256sum\" missing. Aborting.."
    exit
fi


sha=$(curl -s http://bigalice3.nem.ninja:7890/transaction/get?hash=$txId | jq -r '.transaction.message.payload' | sed -e 's/fe4e545903//')
echo "$sha $1" > /tmp/validateNemSignature.tmp.$1

sha256sum -c /tmp/validateNemSignature.tmp.$1

rm /tmp/validateNemSignature.tmp.$1
