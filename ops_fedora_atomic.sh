#!/usr/bin/env bash
rpm-ostree upgrade
flatpak update -y
flatpak list --app
rpm-ostree status
