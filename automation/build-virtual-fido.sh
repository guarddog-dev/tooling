#!/bin/bash
# Setup Velero
echo '  Creating Tanzu Kubernetes Unmanaged Cluster with with Virtual Fido ...'

# Versions
#Tanzu/Kubernetes cluster name
CLUSTER_NAME='local-cluster'
#Control Plane Name
CONTROL_PLANE="$CLUSTER_NAME"-control-plane

# Create Unmanaged Cluster
echo '   Creating Unmanaged Cluster ...'
tanzu um create $CLUSTER_NAME -p 80:80 -p 443:443 -c calico

# Valideate Cluster is ready
echo "   Validating Unmanaged Cluster $CLUSTER_NAME is Ready ..."
STATUS=NotReady
while [[ $STATUS != "Ready" ]]
do
echo "    Tanzu Cluster $CLUSTER_NAME Status - NotReady"
sleep 10s
STATUS=$(kubectl get nodes -n $CONTROL_PLANE | tail -n +2 | awk '{print $2}')
done
echo "    Tanzu Cluster $CLUSTER_NAME Status - Ready"
kubectl get nodes,po -A
sleep 20s

#create secret
kubectl create secret docker-registry gcr-json-key \
 --docker-server=gcr.io \
 --docker-username=_json_key \
 --docker-password="$(cat /etc/guarddog/keys/service-account.json)" \
 --docker-email=russell.hamker@guarddog.ai
 
#patch service account
kubectl patch serviceaccount default \
 -p '{"imagePullSecrets": [{"name": "gcr-json-key"}]}'

#Create yaml
cat <<EOF > /root/automation/virtualfido.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: guarddog-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/etc/guarddog"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: guarddog-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
---
#@ load("@ytt:data", "data")
apiVersion: v1
kind: Pod
metadata:
  name: vfido
spec:
  containers:
  - name: vfido
    image: gcr.io/guarddog-dev/dfido/x86_x64:1.0.9
    env:
    - name: DEVICE_NAME
      value: #@ data.values.DEVICE_NAME
    - name: LICENSE_EMAIL
      value: #@ data.values.LICENSE_EMAIL
    - name: LICENSE_KEY
      value: #@ data.values.LICENSE_KEY
    - name: UUID
      value: #@ data.values.UUID
    volumeMounts:
    - name: guarddog-storage
      mountPath: /etc/guarddog
  imagePullSecrets:
  - name: gcr-json-key
  volumes:
    - name: guarddog-storage
      persistentVolumeClaim:
        claimName: guarddog-claim
EOF

# Deploy pod
echo "   Deploying Virtual Fido ..."
ytt -f /root/automation/virtualfido.yaml -v DEVICE_NAME=$(python3 /root/setup/getOvfProperty.py 'guestinfo.hostname') -v LICENSE_EMAIL=$(python3 /root/setup/getOvfProperty.py 'guestinfo.licenseemail') -v LICENSE_KEY=$(python3 /root/setup/getOvfProperty.py 'guestinfo.license') -v UUID=$(get_uuid) | kubectl apply -f-

# Validate that the pod is ready
echo "   Validate that vfido pod is ready ..."
THENAMESPACE="vfido"
THEPOD=$(kubectl get po -n $THENAMESPACE | grep portainer | cut -d " " -f 1)
while [[ $(kubectl get po -n $THENAMESPACE $THEPOD -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for pod $THEPOD to be ready" && sleep 1; done
echo "   Pod $THEPOD is now ready ..."

echo "   Build Completed ..."
