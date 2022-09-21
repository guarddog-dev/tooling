#!/bin/bash

# Copyright (c) 2022 by GUARDDOG, Inc.  All Rights Reserved.
# This software is the confidential and proprietary information of
# GUARDDOG, Inc. ("Confidential Information").
# You may not disclose such Confidential Information, and may only
# use such Confidential Information in accordance with the terms of
# the license agreement you entered into with GUARDDOG.

VOLUMEN="/etc/guarddog"
IMAGE_NAME="gcr.io/guarddog-dev/dfido/x86_x64"
CONTAINER_NAME="dfido"
STATUS=$(docker inspect --format="{{.State.Running}}" $CONTAINER_NAME)
COUNT=$(docker ps -a | grep "$CONTAINER_NAME" | wc -l)
GCLOUD_FILE="$VOLUMEN/opt/gcloudid"
VERSION=$(cat $VOLUMEN/version)
ENCRYPTER="$SCRIPTS/encrypter.py"

PROPERTY="python3 /root/setup/getOvfProperty.py "
DEVICE_NAME=$($PROPERTY guestinfo.hostname)
EMAIL=$($PROPERTY guestinfo.licenseemail)
LICENSE=$($PROPERTY guestinfo.license)
SERIAL=$(get_uuid)


# exist dfido container?
if (($COUNT > 0)); then
    echo "   $CONTAINER_NAME container exists! ..."
    # is container up?
    if ($STATUS); then
        echo "   $CONTAINER_NAME container is UP! ..."
    else
        echo "   Start container $CONTAINER_NAME ..."
        docker start $CONTAINER_NAME
    fi
else
    NEW_VERSION=$(curl -H "x-api-key: YmZjM2Q0ZTAtYjUyOC00YWIxLTlmYmQtZjNmODczNWNhNmUw"   -H "Authorization: bearer $(gcloud auth print-identity-token)" \
                https://us-central1-guarddog-dev.cloudfunctions.net/provisioning_vm_api/api/docker/version | jq -r '.docker_version')
    echo "--- $NEW_VERSION"
    if [ "$NEW_VERSION" == "" ]; then
        echo "   Error to get latest version, the latest known version $VERSION will be used. ..."
    else
        echo "$NEW_VERSION" | tee /etc/guarddog/version
        VERSION=$(cat $VOLUMEN/version)
        echo "   New version found: $VERSION ..."
    fi

    echo "   docker pull $IMAGE_NAME:$VERSION ..."
    docker pull $IMAGE_NAME:$VERSION

    echo "   docker run dfido..."
    echo "   Device Name: $DEVICE_NAME"
    echo "   Email: $EMAIL"
    echo "   License: $LICENSE"
    echo "   Serial: $SERIAL"

    docker run -itd --cap-add NET_ADMIN --net=host --restart always -v /etc/guarddog:/etc/guarddog --name $CONTAINER_NAME $IMAGE_NAME:$VERSION $DEVICE_NAME $EMAIL $LICENSE $SERIAL

fi
