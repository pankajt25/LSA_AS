#!/usr/bin/env bash
# Automated deployment pipeline script
echo "Starting production service deployment..."
systemctl reload app.service
