#!/bin/bash

. /etc/sysconfig/heat-params

# TODO:
#   - do stuff in a tmp dir?
#   - cleanup the binaries.
#   - split this file into several smaller pieces.
#   - get params from template - can I do it without having to write_heat_params them?

if [ "$(echo $FEDERATION_ENABLED | tr '[:upper:]' '[:lower:]')" == "false" ]; then
    exit 0
fi

KFED_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)

# Download kubefed binary
curl -LO https://storage.googleapis.com/kubernetes-release/release/${KFED_VERSION}/kubernetes-client-linux-amd64.tar.gz
tar -xzvf kubernetes-client-linux-amd64.tar.gz
rm kubernetes-client-linux-amd64.tar.gz
sudo cp kubernetes/client/bin/kubefed /usr/local/bin
sudo chmod +x /usr/local/bin/kubefed

# CoreDNS uses etcd as backend.
# So deploy an etcd cluster (etcd-operator) first.
cat > etcd-operator-rbac.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: etcd-operator
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: etcd-operator
rules:
- apiGroups:
  - etcd.database.coreos.com
  resources:
  - etcdclusters
  verbs:
  - "*"
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - customresourcedefinitions
  verbs:
  - "*"
- apiGroups:
  - storage.k8s.io
  resources:
  - storageclasses
  verbs:
  - "*"
- apiGroups: 
  - ""
  resources:
  - pods
  - services
  - endpoints
  - persistentvolumeclaims
  - events
  verbs:
  - "*"
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - "*"
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: etcd-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: etcd-operator
subjects:
- kind: ServiceAccount
  name: etcd-operator
  namespace: default
EOF

cat > etcd-operator-deployment.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: etcd-operator
spec:
  replicas: 1
  template:
    metadata:
      labels:
        name: etcd-operator
    spec:
      serviceAccountName: etcd-operator
      containers:
      - name: etcd-operator
        image: quay.io/coreos/etcd-operator:v0.5.0
        env:
        - name: MY_POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
EOF

cat > etcd-operator-cluster.yaml <<EOF
apiVersion: etcd.database.coreos.com/v1beta2
kind: EtcdCluster
metadata:
  name: etcd-cluster
spec:
  size: 3
  version: 3.1.8
EOF

kubectl create -f etcd-operator-rbac.yaml
kubectl create -f etcd-operator-deployment.yaml
kubectl create -f etcd-operator-cluster.yaml

# Wait until one of the etcd-cluster Pods is available
until [ "$(kubectl get po -l name=etcd -n=kube-system -o jsonpath={..phase})" != "Running" ];
do
    echo "waiting for etcd to be ready..."
done

# Set up CoreDNS.
cat > coredns-configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-coredns
  namespace: default
data:
  Corefile: |-
    .:53 {
        cache 30
        errors stdout
        etcd ${DNS_ZONE_NAME} {
          path /skydns
          endpoint http://etcd-cluster-client.default:2379
        }
        health
        loadbalance round_robin
        proxy . /etc/resolv.conf
    }
EOF

cat > corends-deployment.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  labels:
    app: coredns-coredns
  name: coredns-coredns
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: coredns-coredns
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: coredns-coredns
        release: coredns
    spec:
      containers:
      - args:
        - -conf
        - /etc/coredns/Corefile
        image: coredns/coredns:1.0.1
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 5
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 5
        name: coredns
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 100m
            memory: 128Mi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /etc/coredns
          name: config-volume
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      serviceAccount: default
      serviceAccountName: default
      terminationGracePeriodSeconds: 30
      volumes:
      - configMap:
          defaultMode: 420
          items:
          - key: Corefile
            path: Corefile
          name: coredns-coredns
        name: config-volume
EOF 

cat > coredns-service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: coredns-coredns
  name: coredns-coredns
  namespace: default
spec:
  ports:
  - name: dns
    port: 53
    protocol: UDP
    targetPort: 53
  - name: dns-tcp
    port: 53
    protocol: TCP
    targetPort: 53
  - name: metrics
    port: 9153
    protocol: TCP
    targetPort: 9153
  selector:
    app: coredns-coredns
  type: NodePort
EOF

kubectl create -f coredns-configmap.yaml
kubectl create -f coredns-deployment.yaml
kubectl create -f coredns-service.yaml

# TODO(clenimar): make sure the Pod is running before
# querying the Service.

# Configure the DNS zone.
COREDNS_IP="$(kubectl get svc -l app=coredns-coredns -o jsonpath={.items[0].spec.clusterIP})"
COREDNS_PORT="$(kubectl get svc -l app=coredns-coredns -o jsonpath={.items[0].spec.ports[?(@.name==\"dns-tcp\")].nodePort})"

cat > coredns-provider.conf <<EOF
[Global]
etcd-endpoints=http://etcd-cluster.default:2379
zones=${DNS_ZONE_NAME}
coredns-endpoints=${COREDNS_IP}:${COREDNS_PORT}
EOF

# TODO: create the federation
#  - get hostcluster context info
