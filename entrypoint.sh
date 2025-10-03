#!/bin/bash

sync-pwd --secretname dockerhub-rancher --reponame rancher-test/test --template dockerhub --secrettype repo --org rancher  > manifests/secrets/resources/PushSecret/export-dockerhub-rancher.yaml
