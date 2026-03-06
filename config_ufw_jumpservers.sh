#!/bin/bash

## How to Use It
## sudo bash config_.sh

# Exit on error
set -e

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow in on wt0 to any port 22 proto tcp
sudo ufw allow in on wt0 to any port 443 proto tcp
sudo ufw allow in on wt0 to any port 3389 proto tcp
sudo ufw allow in on wt0 to any port 60000:61000 proto udp

sudo ufw deny in on enp2s0
sudo ufw deny in on wlp3s0

sudo ufw status verbose

sudo ufw enable
