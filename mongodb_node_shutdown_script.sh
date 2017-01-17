#!/bin/bash

set -euf -o pipefail

# Since the local MongoDB on this node is already stopped when the script gets
# called, just simnply start with a 5 second sleep to give time to the MongoDB
# replicaset to elect a new primary if we were the primary up until now
sleep 5

OUR_HOSTNAME=$(hostname -s)

# Now check who is master on a node which is still in `RUNNING` state
MASTER_HOST=$(ssh -o StrictHostKeyChecking=no $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | grep 'RUNNING$' | awk '{print $1}' | head -n 1) "/usr/bin/mongo --norc --quiet --eval 'rs.isMaster().primary' | cut -d':' -f1")

# SSH to the master and run the replicaset remove command for this node
ssh -o StrictHostKeyChecking=no $MASTER_HOST "/usr/bin/mongo --norc --quiet --eval 'rs.remove(\"${OUR_HOSTNAME}:27017\")'"

# Now this node can be shut down safely after removing itself from the MongoDB replicaset
