#!/bin/bash
# ------------------------------------------------------------------
# [Author] Paudie ORiordan
#          sample bash script to walk vSphere JSON API using curl
#          not supported by VMware
#          not supported for production
#          use at your own risk
# ------------------------------------------------------------------
VERSION=0.2.0
# --- variables -------------------------------------------
# Ask the user for login details
#read -p 'vCenter FQDN: ' VC
#read -p 'vCenter User: ' VCUSER
#read -sp 'Password: ' VCPASS
#echo
#echo "Processing against vCenter '"$VC"' with userId '"$VCUSER"'"
VC=<vCENTER FQDN>
VCUSER=<vSphere User>
VCPASS=<vSphere User Passowrd>
VCVERSION=8.0.2.0
SESSION_MANAGER_MOID=$(curl -s -k https://$VC/sdk/vim25/$VCVERSION/ServiceInstance/ServiceInstance/content | jq .sessionManager.value| tr -d '"')
ROOT_FOLDER_MOID=$(curl -s -k https://$VC/sdk/vim25/$VCVERSION/ServiceInstance/ServiceInstance/content | jq .rootFolder.value|tr -d '"')
echo "# ------------------------------------------------------------------"
#retrieve API Session id 

APISESSION=$(curl -s -k https://$VC/sdk/vim25/$VCVERSION/SessionManager/$SESSION_MANAGER_MOID/Login -H 'Content-Type: application/json' -d '{"userName" : "'$VCUSER'", "password" : "'$VCPASS'"}'  -i| grep vmware-api-session-id| awk '{print $1, $2}')
echo "The current API key for this session is "$APISESSION
#get datacenter MOID
DATACENTER_MOID=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/Folder/$ROOT_FOLDER_MOID/childEntity| jq .[].value| tr -d '"')
#echo $DATACENTER_MOID
DATACENTER_NAME=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/Datacenter/$DATACENTER_MOID/name | jq| tr -d '"')

HOSTFOLDER_MOID=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/Datacenter/$DATACENTER_MOID/hostFolder| jq .value| tr -d '"')
#echo $HOSTFOLDER_MOID
CLUSTER_MOID=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/Folder/$HOSTFOLDER_MOID/childEntity| jq .[].value| tr -d '"')
CLUSTER_NAME=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/ClusterComputeResource/$CLUSTER_MOID/name| jq |tr -d '"')
#echo $CLUSTER_MOID
HOST_MOIDS=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/ClusterComputeResource/$CLUSTER_MOID/host| jq .[].value|tr -d '"')
#echo $HOST_MOIDS
declare -a host_array
host_array=($HOST_MOIDS)
cluster_size=${#host_array[@]}
echo "# ------------------------------------------------------------------"
echo "The DataCenter name is "$DATACENTER_NAME
echo "# ------------------------------------------------------------------"
echo "The vSAN cluster is called "$CLUSTER_NAME" with a host count of" $cluster_size ". These are the NVMe Drives belonging to each node"
index=0
while [ $index -lt ${#host_array[@]} ]
do
        ESXIHOSTNAME=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/HostSystem/${host_array[$index]}/name |jq|tr -d '"'  )
        NVME_NAME=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/HostSystem/${host_array[$index]}/config|jq .storageDevice.nvmeTopology | jq '.adapter[].connectedController[].attachedNamespace[].name'|tr -d '"')
        nvme_name=($NVME_NAME)
        siz=${#nvme_name[@]}
        echo "---------------------------------------------------------------------------------------------------------------------------------------------------------"
        echo "|           vSAN Node        |                            Device Name                                         |       Serial       |   Device Model     |"
        echo "---------------------------------------------------------------------------------------------------------------------------------------------------------"
        i=0
        while [ $i -ne $siz ]
              do
              NVME_SERIAL=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/HostSystem/${host_array[$index]}/config| jq .storageDevice.nvmeTopology | jq .adapter[$i].connectedController[].serialNumber|tr -d '"')
              NVME_MODEL=$(curl -s -k -X GET -H "$APISESSION"  https://$VC/sdk/vim25/$VCVERSION/HostSystem/${host_array[$index]}/config| jq .storageDevice.nvmeTopology | jq .adapter[$i].connectedController[].model|tr -d '"')
              nvme_serials=($NVME_SERIAL)
              echo $ESXIHOSTNAME ${nvme_name[$i]} $NVME_SERIAL"  "$NVME_MODEL"|"
              i=$(( $i + 1 ))
              done

        ((index++))
done

        echo "---------------------------------------------------------------------------------------------------------------------------------------------------------"
