# Skripty pre volania METAIS API
Dokumentácia API je dostupná na adrese https://slovak-egov.github.io/metais-swagger-ui/

## VS Code RestAPI client
V adresároch GroovyAPI a OthersAPI sú skripty pre rozšírenie [VS Code Rest-client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)

## Evidencia CI
Skript test.sh umožňuje vytvorenie záznamu CI volaním s argumentami. Skript používa šablóny uložené v adresári tpl.
Skript požaduje nástroje curl, awk, jq a uuidgen.

    user@debian:~/metais-scripts$ ./test.sh -h
    Usage: ./test.sh: -t ci_type -n ci_name -d date -o owner_ico -u uroven -c dovernost -i integrita -a dostupnost
    
