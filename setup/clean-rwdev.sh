#!/bin/bash

set -e

set -a
source vars.env
set +a

sudo systemctl stop k3s
sudo /usr/local/bin/k3s-uninstall.sh
sudo rm -rf /mnt/k3s-disk/k3s-data/*
sudo rm -rf /mnt/k3s-disk/k3s-dev-platform-kubeconfig
