#!/usr/bin/env bash
# -*- coding: UTF-8 -*-
## Helper script to prepare the cluster to test Machine API Operator
## see https://github.com/openshift/machine-api-operator/blob/master/docs/dev/hacking-guide.md

echo "[+] scaling down the cluster version operator."
# This operator watches the deployments and images related to the core OpenShift services, and would prevent a user from changing these details.
oc scale --replicas=0 deployment/cluster-version-operator -n openshift-cluster-version

if oc get configmap/machine-api-operator-images -n openshift-machine-api -o yaml | yq '.data' | grep nodeHealthcheck; then
    echo "[+] image.json contains already nodehealthcheck"
else
    echo "Getting NHC v0.7.0 image with SHA"
    NHC_v070_SHA=$(skopeo inspect docker://quay.io/medik8s/node-healthcheck-operator:v0.7.0 | jq -r ".Digest")
    echo "[+] edit machine-api-operator-images ConfigMap - double check NHC image is present (press ENTER)"
    echo "[+] add \"nodeHealthcheck\": \"quay.io/medik8s/node-healthcheck-operator@${NHC_v070_SHA}\""
    read
    oc edit configmap/machine-api-operator-images -n openshift-machine-api
fi

echo "Getting MAO custom image with SHA"
MAO_CUSTOM_SHA=$(skopeo inspect docker://quay.io/clobrano/machine-api-operator:latest | jq -r ".Digest")
echo "[+] patching MAO image with quay.io/clobrano/machine-api-operator@${MAO_CUSTOM_SHA}"
cmd="kubectl set image deployment/machine-api-operator machine-api-operator=quay.io/clobrano/machine-api-operator@${MAO_CUSTOM_SHA} -n openshift-machine-api "
echo " $ $cmd"
$cmd
echo "[+] check image was set: $(oc get deployment/machine-api-operator -n openshift-machine-api -o json | jq '.spec.template.spec.containers[] | select(.name == "machine-api-operator").image')"

echo "[+] swapping out the controller"
oc delete deployment/machine-api-controllers -n openshift-machine-api

