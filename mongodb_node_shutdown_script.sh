#!/bin/bash

set -euf -o pipefail

# Check if this node is the master and if yes then make is step down to only be a secondary
if test "$(/usr/bin/mongo --norc --quiet --eval 'db.isMaster().ismaster')" == "true"; then
  /usr/bin/mongo --norc --quiet --eval 'rs.stepDown()' &>/dev/null
  sleep 3
fi

OUR_HOSTNAME=$(hostname -s)

# Now that the node should be a secondary, check which node is the master
MASTER_HOST=$(/usr/bin/mongo --norc --quiet --eval 'rs.isMaster().primary' | cut -d':' -f1)

# SSH to the master and run the replicaset remove command for this node
ssh -o StrictHostKeyChecking=no $MASTER_HOST "/usr/bin/mongo --norc --quiet --eval 'rs.remove(\"${OUR_HOSTNAME}:27017\")'"

# Now this node can be shut down safely after removing itself from the MongoDB replicaset
