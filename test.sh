#!/bin/sh -x
# zavislosti: jq, uuidgen
METAISURI="https://metais-test.slovensko.sk"
#CURL_OPTS="--silent --location"
CURL_OPTS="--location"
ATOKEN="eyJraWQiOiJzaWduaW5nIiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiJwZXRlci52aXNrdXBAbWlycmkuZ292LnNrIiwiYXVkIjoid2ViUG9ydGFsQ2xpZW50IiwibmJmIjoxNzQwNjgzMzI2LCJpZGVudGl0eV91dWlkIjoiYTIwNGQyZjAtYWIzNS00YWEwLTk0YWMtNmM4OTRlMWExYWY2IiwidXNlcl9pZCI6InBldGVyLnZpc2t1cEBtaXJyaS5nb3Yuc2siLCJzY29wZSI6WyJvcGVuaWQiLCJwcm9maWxlIiwiY191aSJdLCJyb2xlcyI6WyJJS1RfR0FSUE8iLCJLUklTX1RWT1JCQSIsIlNMQV9TUFJBVkEiLCJXSUtJX1VTRVIiLCJXSUtJX0FETUlOIiwiUFJPSkVLVF9TQ0hWQUxPVkFURUwiLCJMSUNfWkxQTyIsIlJPTEVfVVNFUiIsIk1PTl9TUFJBVkEiLCJLUklTX1BPRFBJUyIsIkVBX0dBUlBPIiwiUl9FR09WIiwiVENPX1pQTyIsIlNaQ19ITEdFUyIsIklOVF9QT0RQSVMiXSwiaXNzIjoiaHR0cHM6Ly9tZXRhaXMtdGVzdC5zbG92ZW5za28uc2svaWFtIiwiZXhwIjoxNzQwNzEyMTI2LCJpYXQiOjE3NDA2ODMzMjYsImp0aSI6ImU4MTg2OWI3LTZmOGItNGJhNS04ZjVkLTA5NzZkODVmNTE3MSJ9.if_BjuzvIv3ZkTyymY7rTgDW_crKHJGYQVL0QYkROObdaV07fP9wqJCNi4JmJ_OwcBOXWpvS7Jg7324njdH4hn1zF1gc8Gs4HPNa0UzDUHv36pLERE3t8ZZN1wUrcTBQF_ke_46SeliAR136gtUHxxFJT35AU97tcOh-Dc6d5FjJwoMip43pDkhu9DIkMFMyYhyd-TpncBRG_TrvTvslZANDhBXGiS31Pr7MG2-9v7EJZqwGtyFE9UJIbDcs70e3EfrjQ7wvvJNsn61GuU0lAWPdkZSokAtEYQSujJ2xde0cxxTakglb0BB5sWAUYtc4oLCsKv6wO0pN-7PEwMWfZg"
genID=""

generateID() {
    # https://metais-test.slovensko.sk/api/types-repo/citypes/generate/ISVS?lang=sk

    genIDAPI="/api/types-repo/citypes/generate/"
    TYPE=${1?'not defined'}
    URI="${METAISURI}${genIDAPI}${TYPE}"

    ret=$(curl --silent --location --request GET ${URI} --header "Authorization: Bearer ${ATOKEN}" --header 'Content-Type: application/json'|jq '.cicode'|tr -d '"')
    # pri neplatnom tokene vráti prázdnu hodnotu, ale neskončí s chybou!
    [-z $ret] && exit 100
    echo $ret
}

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

setcloudParams() {
    if [ -n "$CPARAM" ]; then
    CTYPE="c_typ_cloud_sluzba_is.$(echo $CPARAM|awk -F, '{print $1}')"
    CLVL="c_akreditacie_cloudovych_sluzieb.$(echo $CPARAM|awk -F, '{print $2}')"
    CCNF="c_bezpecnost_cloudovych_sluzieb_dovernost.$(echo $CPARAM|awk -F, '{print $3}')"
    CINT="c_bezpecnost_cloudovych_sluzieb_integrita.$(echo $CPARAM|awk -F, '{print $4}')"
    CACC="c_bezpecnost_cloudovych_sluzieb_dostupnost.$(echo $CPARAM|awk -F, '{print $5}')"
    fi
}

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
    # typ,uroven,dovernost,integrita,dostupnost
    CPARAM=${4-'null,null,null,null,null'}
    DATE=$(date -Is --date "${DATE}")
    genID=$(generateID "${TYPE}")
    refURI=$(getrefURI "${TYPE}")
    UUID=$(uuidgen)
    
    URI="${METAISURI}${storeCI}"

    [ "${TYPE}" = "InfraSluzba" ] && setcloudParams "${CPARAM}"

    DATA=$(sed 's#%CTYPE%#'${CTYPE}'#;s#%CLVL%#'${CLVL}'#;s#%CCNF%#'${CCNF}'#;s#%CINT%#'${CINT}'#;s#%CACC%#'${CACC}'#;s#%DATE%#'${DATE}'#;s#%TYPE%#'${TYPE}'#;s#%genID%#'${genID}'#;s#%NAZOV%#'${NAZOV}'#;s#%UUID%#'${UUID}'#;s#%refURI%#'${refURI}'#;s#%refID%#'${genID##*_}'#' "${TYPE}"|jq -c)
    #DATA=$(sed 's/%TYPE%/'${TYPE}'/;s/%genID%/'${genID}'/;s/%NAZOV%/'${NAZOV}'/;s/%UUID%/'${UUID}'/;s/%ID%/'${genID##*_}'/' AS|jq -c)
    #echo $DATA
    curl --silent --location --request POST ${URI} --header "Authorization: Bearer ${ATOKEN}" --header 'Content-Type: application/json' --data "${DATA}"
    #echo $?

}

getPO() {
    # https://metais-test.slovensko.sk/api/cmdb/rights/implicitHierarchy?lang=sk
    # data
    echo x
}

metaLogin() {
    # teraz nefunguje
    # prihlás sa v prehliadači + získaj token a ulož do premennej ATOKEN
    loginURI="/iam/usernamePassLogin"
    URI="${METAISURI}${loginURI}"
    curl --silent --location --request POST ${URI} --header 'Content-Type: application/x-www-form-urlencoded' -d "username=your_username&password=your_password" -b "cookie_name=cookie_value"
}

storeCI $1 "${2}" "$(date +%F)" "2,1,1,1,1"
#reqID=$(storeCI $1 "${2}"|jq '.requestId')
