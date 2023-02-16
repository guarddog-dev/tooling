#!/bin/bash
# Setup vfido
echo '  Creating Kubernetes Cluster with with Virtual Fido ...'

# Versions
#Kubernetes cluster name
CLUSTER_NAME='vfido-cluster'
#Control Plane Name
CONTROL_PLANE="$CLUSTER_NAME"-control-plane

#Create Cluster yaml
cat <<EOF > ./kind-calico.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: vfido-cluster
networking:
  # the default CNI will not be installed
  disableDefaultCNI: true # disable kindnet
  podSubnet: 192.168.0.0/16  # set to Calico's default subnet
  serviceSubnet: "10.96.0.0/12"
nodes:
- role: control-plane
  # port forward 80 on the host to 80 on this node
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    # optional: set the bind address on the host
    # 0.0.0.0 is the current default
    listenAddress: "127.0.0.1"
    # optional: set the protocol to one of TCP, UDP, SCTP.
    # TCP is the default
    protocol: TCP
EOF

#Create Cluster
kind create cluster --config kind-calico.yaml

#Install the Tigera Calico operator
echo "   Deploying Calico Tigera operator on Cluster $CLUSTER_NAME ..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.2/manifests/tigera-operator.yaml

#Install Calico
echo "   Deploying Calico CNI on Cluster $CLUSTER_NAME ..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.2/manifests/custom-resources.yaml

#Deploy Carvel secretgen controller
echo "   Deploying Carvel secretgen controller on Cluster $CLUSTER_NAME ..."
kapp deploy -a sg -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/latest/download/release.yml -y

#Deploy Carvel kapp controller
echo "   Deploying Carvel kapp controller on Cluster $CLUSTER_NAME ..."
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml -y

# Valideate Cluster is ready
echo "   Validating Cluster $CLUSTER_NAME is Ready ..."
STATUS=NotReady
while [[ $STATUS != "Ready" ]]
do
echo "    Kubernetes Cluster $CLUSTER_NAME Status - NotReady"
sleep 10s
STATUS=$(kubectl get nodes -n $CONTROL_PLANE | tail -n +2 | awk '{print $2}')
done
echo "    Kubernetes Cluster $CLUSTER_NAME Status - Ready"
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
    image: gcr.io/guarddog-dev/dfido/x86_x64:1.0.15
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
PODNAME="vfido"
THEPOD=$(kubectl get po $PODNAME | grep $PODNAME | cut -d " " -f 1)
while [[ $(kubectl get po $THEPOD -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for pod $THEPOD to be ready" && sleep 1; done
echo "   Pod $THEPOD is now ready ..."

echo "   Build Completed ..."

echo "   Completing licensing processes ..."
sleep 60s
