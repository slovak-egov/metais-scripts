#!/bin/sh -x
# zavislosti: curl, jq, uuidgen
# skript sa snaží byť POSIX compliant, žiadne "bašizmy"

#METAISURI="https://metais-test.slovensko.sk/api/cmdb/read/cilistfiltered?lang=sk"
METAISURI="https://metais-test.slovensko.sk/api/cmdb/read/cilist"
#CURL_OPTS="--silent --location"
CURL_OPTS="--location"
# AS, InfraSluzba, ISVS, KS
TYPE=${1?'not defined'}
LIMIT=${2-'10000'}
PAGE=${3-'1'}

TMPL='{"filter":{"type":["%TYPE%"]}, "perpage":%LIMIT%, "page":%PAGE%}'

DATA=$(echo ${TMPL}|sed 's#%LIMIT%#'${LIMIT}'#;s#%TYPE%#'${TYPE}'#;s#%PAGE%#'${PAGE}'#'|jq -c)

#ret=$(curl --silent --location --request POST "${METAISURI}"  --header 'Content-Type: application/json'  --data ${DATA} 2>/dev/null)
# prepisat na 
# curl -v --location --request POST "https://metais-test.slovensko.sk/api/cmdb/external/read/query" --header 'Content-Type: application/json' --header "Authorization: Bearer ${TOKEN}" --data "${DATA}"
ret=$(curl --silent --location --request GET "${METAISURI}"  --header 'Content-Type: application/json'  --data ${DATA} 2>/dev/null)
#PAGES=$(echo $ret|jq .pagination.totalPages)
#ITEMS=$(echo $ret|jq .pagination.totaltems)
#if [ $(echo $ret|jq .pagination.totalPages) -lt 1 ]; then
#echo $PAGES $ITEMS
#echo "$ret" | jq -Rnr '[inputs] | join("\\n") | fromjson | .choices[0].message.content'
echo "$ret"
#jq -Rnr '[inputs] | join("\\n") | fromjson | .choices[0].message.content'