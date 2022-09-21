#!/bin/bash

DOCKER_IMAGE="./run_docker_image.sh.x"

echo "   Export gcloud bin ..."
export PATH=$PATH:/usr/local/gcloud/google-cloud-sdk/bin

echo "   Run Provisioning unit ..."
$RUN_GET_PROPERTIES

echo "   Download Docker image ..."
$DOCKER_IMAGE

echo "   Provisioning Completed ..."