
# ------------------------------------------------------------------
# [Author] Paudie ORiordan
#          sample bash script use govc to enable vSAN Witness Traffic on vSAN data nodes mgmt interfaces 
#          not supported by VMware
#          not supported for production
#          use at your own risk
# ------------------------------------------------------------------
VERSION=0.0.1
#/bin/bash
export GOVC_INSECURE=1 # Don't verify SSL certs on vCenter
export GOVC_URL=<VC-FQDN> # vCenter IP/FQDN
export GOVC_USERNAME=administrator@vsphere.local # vCenter username
export GOVC_PASSWORD='<pass>' # vCenter password
export GOVC_DATACENTER='DataCenter' # I have multiple DCs in this VC, so i'm specifying the default here
export govc=/usr/local/bin/govc
echo using the following variables...
echo 	vCenter: $GOVC_URL
echo 	SSO Usr: $GOVC_USERNAME
echo    VI DataCenter Name: $GOVC_DATACENTER
#find cluster
cluster=$($govc find /$GOVC_DATACENTER -type c)
cluster_name=$($govc find / -type c | cut -d '/' -f 4)
echo The name of the cluster is $cluster_name in a datacenter called $GOVC_DATACENTER
#find hosts in cluster
hosts=$($govc find /$GOVC_DATACENTER/host/Cluster -type h | cut -d '/' -f 5)
declare -a host_array
host_array=($hosts)
cluster_size=${#host_array[@]}
echo $cluster_name has $cluster_size hosts ......checking for enabled services on management interface
for i in ${host_array[@]};
do
        declare -a vmknics_before
        vmknics_before=$($govc host.vnic.info -host $i -json=true | jq -r  '.Info[] | "\(.Device) \(.Services[])"')
        enabled_services=$(printf '%s\n' "$vmknics_before"| grep vmk0 )
        echo host $i  has the following services enabled om management vmkernel:  $enabled_services
done
# Ask the user to enable or disable 
case $# in
0) echo -n "Please enable or disable vSAN Witness traffic on vSAN  Management interface(enable|disable): "
   read option ;;

1) option=$1 ;;

*) echo "Sorry, I didn't understand that (too many command line arguments)"
   exit 2 ;;
esac
if [ "$option" == "enable" ]; then
   for i in ${host_array[@]};
     do
	declare -a vmknics
	vmknics=$($govc host.vnic.info -host $i -json=true | jq -r  '.Info[] | "\(.Device) \(.Services[])"')
	mgmtNic=$(printf '%s\n' "$vmknics"| grep management | awk '{print $1}') 
	echo Enabling vSAN Witness traffic on $mgmtNic on host $i ......
	$govc host.vnic.service -host $i  -enable=true vsanWitness  $mgmtNic
     done
elif [ "$option" == "disable" ]; then
   for i in ${host_array[@]};
     do
        declare -a vmknics
        vmknics=$($govc host.vnic.info -host $i -json=true | jq -r  '.Info[] | "\(.Device) \(.Services[])"')
        mgmtNic=$(printf '%s\n' "$vmknics"| grep management | awk '{print $1}') 
        echo Disabling vSAN Witness traffic on $mgmtNic on host $i ......
        $govc host.vnic.service -host $i  -enable=false vsanWitness  $mgmtNic
     done
else
  echo "Sorry, invalid input, please chose enable or disable "

fi

if [ "$option" == "enable" ] || [ "$option" == "disable" ]; then
        echo Checking results of enable / disable operation... 
	for i in ${host_array[@]};
	do
		declare -a vmknics_after
		vmknics_after=$($govc host.vnic.info -host $i -json=true | jq -r  '.Info[] | "\(.Device) \(.Services[])"')
        	enabled_services_after=$(printf '%s\n' "$vmknics_after"| grep vmk0 )
        	echo host $i  has the following services enabled om management vmkernel:  $enabled_services_after
	done
   else
      echo Script complete 
fi
