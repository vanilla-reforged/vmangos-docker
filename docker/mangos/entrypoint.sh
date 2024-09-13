#!/bin/bash
set -e

# Wait for dependencies
/opt/wait

# Start mangosd in the foreground
exec ./mangosd -c /opt/vmangos/etc/mangosd.conf
