#!/usr/bin/env bash
# Nightly backup script
echo "Running database dump..."
tar -czf /var/backups/app_$(date +%F).tar.gz /var/www/app
