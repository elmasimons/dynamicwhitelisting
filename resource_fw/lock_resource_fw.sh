#set -e

VERIFY_INTERVAL=5
VERIFY_RETRY_COUNT=12

SHORT=j:
LONG=json-file:

OPTS=$(getopt -a -n '$0' --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"

while :
do
  case "$1" in
    -j | --json-file )
      JSON_FILE="$2"
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

    RESOURCE_GROUP_NAME=$(_jq '.resource_group_name')
    RESOURCE_TYPE=$(_jq '.resource_type')
    RESOURCE_NAME=$(_jq '.resource_name')

    printf '%s\n' "Removing whitelisting $RESOURCE_GROUP_NAME $RESOURCE_TYPE $RESOURCE_NAME $PUBLIC_IP" >&1
    case $RESOURCE_TYPE in
        kv)
            az keyvault network-rule remove --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --ip-address $PUBLIC_IP --output none
            az keyvault update --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --bypass AzureServices --output none
            az keyvault update --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --default-action Deny --output none
            ;;
        st)
            az storage account network-rule remove --resource-group $RESOURCE_GROUP_NAME --account-name $RESOURCE_NAME --ip-address $PUBLIC_IP --output none
            az storage account update --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --bypass AzureServices --output none
            az storage account update --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --default-action Deny --output none
            ;;
        app)
            az webapp config access-restriction remove --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --rule-name DevOps --output none
            ;;
        appslot)
            SLOT_NAME=$(_jq '.slot_name')
            az webapp config access-restriction remove --resource-group $RESOURCE_GROUP_NAME --name $RESOURCE_NAME --slot $SLOT_NAME --rule-name DevOps --output none
            ;;
        *)
            printf '%s\n' "Cannot process this resource"  >&2
            ;;
    esac
done