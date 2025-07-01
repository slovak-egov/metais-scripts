#!/bin/sh -x
# zavislosti: curl, jq, uuidgen
# skript sa snaží byť POSIX compliant, žiadne "bašizmy"

METAISURI="https://metais-test.slovensko.sk"
#CURL_OPTS="--silent --location"
CURL_OPTS="--location"
# copy JWT token here
ATOKEN="eyJraWQiOiJzaWduaW5nIiwiYWxnIjoiUlMyNTYifQ....."
genID=""

while getopts :f:t:n:d:o:s:u:c:i:a: name
do
    case $name in
        f)  FILE=$OPTARG
            ;;
        t)  CI_TYPE=$OPTARG
            ;;
        n)  CI_NAME=$OPTARG
            ;;
        d)  DATE=$OPTARG
            ;;
        o)  CI_OWNER=$OPTARG
            ;;
        s)  SVC_TYPE=$OPTARG
            ;;
        u)  SVC_UROVEN=$OPTARG
            ;;
        c)  SVC_CONFID=$OPTARG
            ;;
        i)  SVC_INTEGR=$OPTARG
            ;;
        a)  SVC_AVAILA=$OPTARG
            ;;
        ?)  printf "Usage: %s: -t ci_type -n ci_name -d date -o owner_ico -u uroven -c dovernost -i integrita -a dostupnost\n" $0
            exit 1;;
    esac
done

# nastavit default hodnoty
[ -z "${DATE}" ] && DATE=$(date +%F)
[ -z "${CI_TYPE}" ] && CI_TYPE="InfraSluzba"
[ -z "${CI_NAME}" ] && CI_NAME="${CI_TYPE}_${DATE}"

#echo "$CI_TYPE $CI_NAME $DATE $CI_OWNER $SVC_UROVEN $SVC_CONFID $SVC_INTEGR $SVC_AVAILA" && exit 3

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
    CTYPE="c_typ_cloud_sluzba_is.${SVC_TYPE:-1}"
    CLVL="c_akreditacie_cloudovych_sluzieb.${SVC_UROVEN:-1}"
    CCNF="c_bezpecnost_cloudovych_sluzieb_dovernost.${SVC_CONFID:-1}"
    CINT="c_bezpecnost_cloudovych_sluzieb_integrita.${SVC_INTEGR:-1}"
    CACC="c_bezpecnost_cloudovych_sluzieb_dostupnost.${SVC_AVAILA:-1}"

    #CTYPE="c_typ_cloud_sluzba_is.$(echo $CPARAM|awk -F, '{print $1}')"
    #CLVL="c_akreditacie_cloudovych_sluzieb.$(echo $CPARAM|awk -F, '{print $2}')"
    #CCNF="c_bezpecnost_cloudovych_sluzieb_dovernost.$(echo $CPARAM|awk -F, '{print $3}')"
    #CINT="c_bezpecnost_cloudovych_sluzieb_integrita.$(echo $CPARAM|awk -F, '{print $4}')"
    #CACC="c_bezpecnost_cloudovych_sluzieb_dostupnost.$(echo $CPARAM|awk -F, '{print $5}')"
    fi
}

setASParams() {
    if [ -n "$CPARAM" ]; then
    CTYPE="c_typ_cloud_sluzba_as.$(echo $CPARAM|awk -F, '{print $1}')"
    CEXT="c_stav_dost_ext_int.$(echo $CPARAM|awk -F, '{print $2}')"
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
    CPARAM=${5-'0,1,1,1,1'}

    DATE=$(date -Is --date "${DATE}")
    genID=$(generateID "${TYPE}")
    refURI=$(getrefURI "${TYPE}")
    UUID=$(uuidgen)

    URI="${METAISURI}${storeCI}"

    [ "${TYPE}" = "InfraSluzba" ] && setcloudParams "${CPARAM}"
    [ "${TYPE}" = "AS" ] && setASParams "${CPARAM}"

    # owner is hardcoded to role "EA_GARPO" ATM (1d8a37f7-3063-46d2-b66a-c1b0c8471878)
    DATA=$(sed 's#%OWNERUUID%#1d8a37f7-3063-46d2-b66a-c1b0c8471878-'${OWNERUUID}'#;s#%CEXT%#'${CEXT}'#;s#%CTYPE%#'${CTYPE}'#;s#%CLVL%#'${CLVL}'#;s#%CCNF%#'${CCNF}'#;s#%CINT%#'${CINT}'#;s#%CACC%#'${CACC}'#;s#%DATE%#'${DATE}'#;s#%TYPE%#'${TYPE}'#;s#%genID%#'${genID}'#;s#%NAZOV%#'${NAZOV}'#;s#%UUID%#'${UUID}'#;s#%refURI%#'${refURI}'#;s#%refID%#'${genID##*_}'#' tpl/"${TYPE}"|jq -c)
    #DATA=$(sed 's#%OWNERUUID%#'${OWNERUUID}'#;s#%CEXT%#'${CEXT}'#;s#%CTYPE%#'${CTYPE}'#;s#%CLVL%#'${CLVL}'#;s#%CCNF%#'${CCNF}'#;s#%CINT%#'${CINT}'#;s#%CACC%#'${CACC}'#;s#%DATE%#'${DATE}'#;s#%TYPE%#'${TYPE}'#;s#%genID%#'${genID}'#;s#%NAZOV%#'${NAZOV}'#;s#%UUID%#'${UUID}'#;s#%refURI%#'${refURI}'#;s#%refID%#'${genID##*_}'#' "${TYPE}"|jq -c)
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
    DATA=$(sed 's#%ICO%#'${ICO}'#' tpl/POlist.req|jq -c)

    ret=$(curl -v --silent --location --request POST ${URI} --header "Authorization: Bearer ${ATOKEN}" --header 'Content-Type: application/json' --data "${DATA}")
    #echo $ret
    [ -z "$ret" ] && exit 200
    # ak totalItems = 1, 0 and 2+ nie sú dostupné
    # niektoré PO sú uložené viacnásobne s rovnakým ICO (BUG?)
    if [ $(echo $ret|jq .pagination.totaltems) -eq 1 ]; then
      echo $ret|jq .configurationItemSet[0].uuid
    else
      echo "not valid output in list of PO" >&2
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

# InfraSluzba
#reqID=$(storeCI $1 "${2}" "$(date +%F)" "${PO}" "2,1,1,1,1")
# AS
#reqID=$(storeCI $1 "${2}" "$(date +%F)" "${PO}" "2,1")
if [ -n "${FILE}" -a -r "${FILE}" ]; then
    while IFS=, read -r CI_TYPE CI_OWNER SVC_TYPE SVC_UROVEN SVC_CONFID SVC_INTEGR SVC_AVAILA; do
        PO=$(getPO "${CI_OWNER}"|tr -d '"')
        reqID=$(storeCI "${CI_TYPE}" "${CI_NAME}" "${DATE}" "${PO}" "${SVC_TYPE},${SVC_UROVEN},${SVC_CONFID},${SVC_INTEGR},${SVC_AVAILA}")
        #echo "${CI_TYPE}" "${CI_NAME}" "${DATE}" "${CI_OWNER}" "${SVC_TYPE},${SVC_UROVEN},${SVC_CONFID},${SVC_INTEGR},${SVC_AVAILA}"
    done < "${FILE}"
else
    PO=$(getPO "${CI_OWNER}"|tr -d '"')
    reqID=$(storeCI "${CI_TYPE}" "${CI_NAME}" "${DATE}" "${PO}" "${SVC_TYPE},${SVC_UROVEN},${SVC_CONFID},${SVC_INTEGR},${SVC_AVAILA}")
fi