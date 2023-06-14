set -e


VERIFY_INTERVAL=5
VERIFY_RETRY_COUNT=12

SHORT=j:,r:,t:,c:,r:
LONG=json-file:,retries:,verify-interval:

OPTS=$(getopt -a -n '$0' --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"

while :
do
  case "$1" in
    -j | --json-file )
      JSON_FILE="$2"
      shift 2
      ;;
    -r | --verify-retry-count )
      VERIFY_RETRY_COUNT="$2"
      shift 2
      ;;
    -t | --verify-interval )
      VERIFY_INTERVAL="$2"
      shift 2
      ;;
    --)
      shift;
      break
      ;;
    *)
      echo "Unexpected option: $1"
      ;;
  esac
done

PUBLIC_IP=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com  | sed -e 's/^"//' -e 's/"$//')

for row in $( jq -r '.[] | @base64' $JSON_FILE ); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }

    _verify_whitelist() {
        local RESOURCE_GROUP_NAME=$1
        local RESOURCE_TYPE=$2
        local RESOURCE_NAME=$3
        local PUBLIC_IP=$4

        n=0
        while [ "$n" -lt "$VERIFY_RETRY_COUNT" ]
        do
            sleep $VERIFY_INTERVAL

            printf '%s\n' "$n Verifying whitelisting $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP" >&1

            case $RESOURCE_TYPE in
                kv)
                    az keyvault show --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --query "properties.networkAcls.ipRules[? value == '$PUBLIC_IP/32'].value" -o tsv
                    ;;
                st)
                    az storage account show --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --query "networkRuleSet.ipRules[? action=='Allow' && ipAddressOrRange == '$PUBLIC_IP'].ipAddressOrRange" -o tsv
                    ;;
                *)
                    printf '%s\n' "Cannot process this resource"  >&2
                    exit 1
                    ;;
            esac
            if [ $? ]
            then
                printf '%s\n' "Whitelisted $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP" >&1
                break
            else
                n=$((n+1))
            fi
        done

        if [ "$n" -ge "$VERIFY_RETRY_COUNT" ]
        then
            printf '%s\n' "Not whitelisted $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP" >&2
            exit 1
        fi
    }

    _whitelist() {
        local RESOURCE_GROUP_NAME=$1
        local RESOURCE_TYPE=$2
        local RESOURCE_NAME=$3
        local PUBLIC_IP=$4

        printf '%s\n' "Whitelisting $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP" >&1


        case $RESOURCE_TYPE in
            kv)
                az keyvault network-rule add --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --ip-address $PUBLIC_IP --output none
                az keyvault update --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --bypass AzureServices --output none
                az keyvault update --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --default-action Deny --output none

                _verify_whitelist $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP
                ;;
            st)
                az storage account network-rule add --resource-group $RESOURCE_GROUP_NAME --account-name $RESOURCE_NAME --ip-address $PUBLIC_IP --output none
                az storage account update --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --bypass AzureServices --output none
                az storage account update --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --default-action Deny --output none

                _verify_whitelist $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP
                ;;
            app)
                az webapp config access-restriction add --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --rule-name DevOps --action Allow --ip-address $PUBLIC_IP --priority 200 --output none
                
                #_verify_whitelist $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP
                ;;
            appslot)
                SLOT_NAME=$(_jq '.slot_name')
                az webapp config access-restriction add --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --slot $SLOT_NAME --rule-name DevOps --action Allow --ip-address $PUBLIC_IP --priority 200 --output none
                
                #_verify_whitelist $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP
                ;;
            sql)
                az sql server firewall-rule create --resource-group $RESOURCE_GROUP_NAME --server $RESOURCE_NAME --name DevOps --start-ip-address $PUBLIC_IP --end-ip-address $PUBLIC_IP --output none
                
                #_verify_whitelist $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP
                ;;
            *)
                printf '%s\n' "Cannot process this resource"  >&2
                exit 1
                ;;
        esac
    }

    RESOURCE_GROUP_NAME=$(_jq '.resource_group_name')
    RESOURCE_TYPE=$(_jq '.resource_type')
    RESOURCE_NAME=$(_jq '.resource_name')
    _whitelist $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP
done