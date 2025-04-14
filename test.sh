#!/bin/sh -x
# zavislosti: curl, jq, uuidgen
# skript sa snaží byť POSIX compliant, žiadne "bašizmy"

METAISURI="https://metais-test.slovensko.sk"
#CURL_OPTS="--silent --location"
CURL_OPTS="--location"
# copy JWT token here
ATOKEN="eyJraWQiOiJza......7L8WHd1tv6Q"
genID=""

# vráť kód METAIS na základe typu CI
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

# vráť base-URI reference
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

# nastav cloud parametre z reťazca CPARAM
setcloudParams() {
    if [ -n "$CPARAM" ]; then
    CTYPE="c_typ_cloud_sluzba_is.$(echo $CPARAM|awk -F, '{print $1}')"
    CLVL="c_akreditacie_cloudovych_sluzieb.$(echo $CPARAM|awk -F, '{print $2}')"
    CCNF="c_bezpecnost_cloudovych_sluzieb_dovernost.$(echo $CPARAM|awk -F, '{print $3}')"
    CINT="c_bezpecnost_cloudovych_sluzieb_integrita.$(echo $CPARAM|awk -F, '{print $4}')"
    CACC="c_bezpecnost_cloudovych_sluzieb_dostupnost.$(echo $CPARAM|awk -F, '{print $5}')"
    fi
}

# vráti "task/req. UUID" z požiadavky na uloženie novej CI
# arguments:
#   type - typ CI (AS, ISVS, InfraSluzba)
#   nazov - nazov CI
#   date - datum evidencie
#   cparam - cloud parametre
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

# vráti PO UUID na základe ICO
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
    # ak totalItems = 1, 0 and 2+ nie sú dostupné
    # niektoré PO sú uložené viacnásobne s rovnakým ICO (BUG?)
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