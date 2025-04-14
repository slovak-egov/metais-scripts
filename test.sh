#!/bin/sh -x
# zavislosti: jq, uuidgen
METAISURI="https://metais-test.slovensko.sk"
#CURL_OPTS="--silent --location"
CURL_OPTS="--location"
ATOKEN="eyJraWQiOiJzaWduaW5nIiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiJwZXRlci52aXNrdXBAbWlycmkuZ292LnNrIiwiYXVkIjoid2ViUG9ydGFsQ2xpZW50IiwibmJmIjoxNzQ0NjA3OTkwLCJpZGVudGl0eV91dWlkIjoiYTIwNGQyZjAtYWIzNS00YWEwLTk0YWMtNmM4OTRlMWExYWY2IiwidXNlcl9pZCI6InBldGVyLnZpc2t1cEBtaXJyaS5nb3Yuc2siLCJzY29wZSI6WyJvcGVuaWQiLCJwcm9maWxlIiwiY191aSJdLCJyb2xlcyI6WyJJS1RfR0FSUE8iLCJLUklTX1RWT1JCQSIsIlNMQV9TUFJBVkEiLCJXSUtJX1VTRVIiLCJXSUtJX0FETUlOIiwiUl9URUNIIiwiUFJPSkVLVF9TQ0hWQUxPVkFURUwiLCJMSUNfWkxQTyIsIlJPTEVfVVNFUiIsIk1PTl9TUFJBVkEiLCJLUklTX1BPRFBJUyIsIkVBX0dBUlBPIiwiUl9FR09WIiwiVENPX1pQTyIsIlNaQ19ITEdFUyIsIklOVF9QT0RQSVMiXSwiaXNzIjoiaHR0cHM6Ly9tZXRhaXMtdGVzdC5zbG92ZW5za28uc2svaWFtIiwiZXhwIjoxNzQ0NjM2NzkwLCJpYXQiOjE3NDQ2MDc5OTAsImp0aSI6ImQ4YzJiNjM5LTE3NmYtNGViNS04MTFlLTJlODIyNTRjMDcyYiJ9.G4YdLDRo3d6oGHk5LABOiZJse-NbQkRU0K2F7wJ5rR4iUYXjAqLg8iwW9kvG4vz92ek59WoFkx_1kax4b0CjEulUe70pccaqU9yu_haSRNzw_al20TF8Csj7iGalmCihHFRqbGbF4t7xaqZ-NL4bYnup3H8XC8Nfh-XD2KDF43ETWHyD2lf-AgjivblYqrQUq7Mu5NEEIY2mqM2yIwWbJP9AK0N3ORZ0TCr50XsEVSIqBR2nkQ_9rY2Y1OEUGSRvnIL5K-akUhk_PsqouQ8XVk930WOHi21CGFmwL4YVg0Vbar5BT4NL1ARxpfcD6Vywa--3zkq-_9o7L8WHd1tv6Q"
genID=""

# return metais_code for CI type
generateID() {
    # https://metais-test.slovensko.sk/api/types-repo/citypes/generate/ISVS?lang=sk

    genIDAPI="/api/types-repo/citypes/generate/"
    TYPE=${1?'not defined'}
    URI="${METAISURI}${genIDAPI}${TYPE}"

    ret=$(curl --silent --location --request GET ${URI} --header "Authorization: Bearer ${ATOKEN}" --header 'Content-Type: application/json')
    # pri neplatnom tokene vráti prázdnu hodnotu, ale neskončí s chybou!
    [ -z "$ret" ] && exit 100
    echo $ret|jq '.cicode'|tr -d '"'
}

# return referemce base-URI
getrefURI() {
    case "${1}" in
        "AS" )
          echo "https://data.gov.sk/id/egov/app-service"
          ;;
        "ISVS" )
          echo "isvs"
          ;;
        "InfraSluzba" )
          echo "https://data.gov.sk/id/ikt/infrastructure-service"
          ;;
        * )
          echo 
          exit 110
          ;;
    esac
}

# set variables for cloud params from CPARAM
setcloudParams() {
    if [ -n "$CPARAM" ]; then
    CTYPE="c_typ_cloud_sluzba_is.$(echo $CPARAM|awk -F, '{print $1}')"
    CLVL="c_akreditacie_cloudovych_sluzieb.$(echo $CPARAM|awk -F, '{print $2}')"
    CCNF="c_bezpecnost_cloudovych_sluzieb_dovernost.$(echo $CPARAM|awk -F, '{print $3}')"
    CINT="c_bezpecnost_cloudovych_sluzieb_integrita.$(echo $CPARAM|awk -F, '{print $4}')"
    CACC="c_bezpecnost_cloudovych_sluzieb_dostupnost.$(echo $CPARAM|awk -F, '{print $5}')"
    fi
}

# return task UUID from request to store new CI
# arguments:
#   type - typ CI (AS, ISVS, InfraSluzba)
#   nazov - nazov CI
#   date - datum evidencie
#   cparam - cloud parameters
#   owneruuid - PO UUID
storeCI() {
    # https://metais-test.slovensko.sk/api/cmdb/store/ci?lang=sk
    # data AS 
    # povinné Gen_Profil_nazov, EA_Profil_AS_dostupnost_pre_externu_integraciu, EA_Profil_AS_typ_cloudovej_sluzby
    # data InfraSluzba
    # povinné Gen_Profil_nazov
    storeCI="/api/cmdb/store/ci"
    TYPE=${1?'not defined'}
    NAZOV=${2?'not defined'}
    DATE=${3?'not defined'}
    OWNERUUID=${4?'not defined'}
    # typ,uroven,dovernost,integrita,dostupnost
    CPARAM=${5-'null,null,null,null,null'}

    DATE=$(date -Is --date "${DATE}")
    genID=$(generateID "${TYPE}")
    refURI=$(getrefURI "${TYPE}")
    UUID=$(uuidgen)

    URI="${METAISURI}${storeCI}"

    [ "${TYPE}" = "InfraSluzba" ] && setcloudParams "${CPARAM}"

    # owner is hardcoded to role "EA_GARPO" ATM (1d8a37f7-3063-46d2-b66a-c1b0c8471878)
    DATA=$(sed 's#%OWNERUUID%#1d8a37f7-3063-46d2-b66a-c1b0c8471878-'${OWNERUUID}'#;s#%CTYPE%#'${CTYPE}'#;s#%CLVL%#'${CLVL}'#;s#%CCNF%#'${CCNF}'#;s#%CINT%#'${CINT}'#;s#%CACC%#'${CACC}'#;s#%DATE%#'${DATE}'#;s#%TYPE%#'${TYPE}'#;s#%genID%#'${genID}'#;s#%NAZOV%#'${NAZOV}'#;s#%UUID%#'${UUID}'#;s#%refURI%#'${refURI}'#;s#%refID%#'${genID##*_}'#' "${TYPE}"|jq -c)
    #DATA=$(sed 's/%TYPE%/'${TYPE}'/;s/%genID%/'${genID}'/;s/%NAZOV%/'${NAZOV}'/;s/%UUID%/'${UUID}'/;s/%ID%/'${genID##*_}'/' AS|jq -c)
    #echo $DATA
    ret=$(curl -v --silent --location --request POST ${URI} --header "Authorization: Bearer ${ATOKEN}" --header 'Content-Type: application/json' --data "${DATA}"|jq '.requestId')
    #echo $?
    [ -z "$ret" ] && exit 200
    echo $ret
}

# return PO UUID from ICO argument
getPO() {
    # https://metais-test.slovensko.sk/api/cmdb/rights/implicitHierarchy?lang=sk
    # data POlist.req
    filteredCI="/api/cmdb/read/cilistfiltered"
    URI="${METAISURI}${filteredCI}"
    ICO=${1?'not defined'}
    DATA=$(sed 's#%ICO%#'${ICO}'#' POlist.req|jq -c)

    ret=$(curl -v --silent --location --request POST ${URI} --header "Authorization: Bearer ${ATOKEN}" --header 'Content-Type: application/json' --data "${DATA}")
    #echo $ret
    [ -z "$ret" ] && exit 200
    # if totalItems = 1, 0 and 2+ are not acceptable
    # some PO are stored multiple times
    if [ $(echo $ret|jq .pagination.totaltems) -eq 1 ]; then
      echo $ret|jq .configurationItemSet[0].uuid
    else
      echo "not valid output in list of PO"
      exit 150
    fi
}

metaLogin() {
    # teraz nefunguje
    # prihlás sa v prehliadači + získaj token a ulož do premennej ATOKEN
    loginURI="/iam/usernamePassLogin"
    URI="${METAISURI}${loginURI}"
    curl --silent --location --request POST ${URI} --header 'Content-Type: application/x-www-form-urlencoded' -d "username=your_username&password=your_password" -b "cookie_name=cookie_value"
}

PO=$(getPO "$3"|tr -d '"')

reqID=$(storeCI $1 "${2}" "$(date +%F)" "${PO}" "2,1,1,1,1")