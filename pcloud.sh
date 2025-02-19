#!/bin/bash

username="test"
password="test"

strAuth=$(curl -s --location --request GET "https://eapi.pcloud.com/userinfo?getauth=1&username=$username&password=$password" | jq -r ".auth")
echo $strAuth

curl --location --request POST "https://eapi.pcloud.com/uploadfile?auth=$strAuth" \
--form "folderid=$2" \
--form "file=@$1"