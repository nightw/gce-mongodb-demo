#!/bin/bash

set -euf -o pipefail

# Setting up an SSH key for the VMs to be able to SSH to each other
if ! grep -q 'ubuntu@mongodb-rs$' /home/ubuntu/.ssh/authorized_keys; then
  curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/mongodb_ssh_pub_key -H "Metadata-Flavor: Google" >> /home/ubuntu/.ssh/authorized_keys
  echo '' >> /home/ubuntu/.ssh/authorized_keys
fi
if ! test -f /home/ubuntu/.ssh/id_rsa; then
  curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/mongodb_ssh_priv_key -H "Metadata-Flavor: Google" > /home/ubuntu/.ssh/id_rsa
  echo '' >> /home/ubuntu/.ssh/id_rsa
  chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
  chmod 600 /home/ubuntu/.ssh/id_rsa
fi

# Setting up the MongoDB repository and installing the MongoDB package
if ! apt-key list | grep -q 'MongoDB 3.4 Release Signing Key'; then
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
fi
if ! test -f /etc/apt/sources.list.d/mongodb-org-3.4.list; then
  echo 'deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse' > /etc/apt/sources.list.d/mongodb-org-3.4.list
  apt-get update
fi
if ! dpkg -l mongodb-org | grep -q '^ii '; then
  apt-get install -y mongodb-org
fi

# Setting up the MongoDB server config file
NEED_RESTART=false
if ! grep -Eq '\s*bindIp: 0\.0\.0\.0' /etc/mongod.conf; then
  sed -i 's/bindIp: 127\.0\.0\.1/bindIp: 0.0.0.0/g' /etc/mongod.conf
  NEED_RESTART=true
fi
if ! grep -Eq '\s*replSetName:\s*\w+' /etc/mongod.conf; then
cat >> /etc/mongod.conf <<EOF
replication:
  replSetName: demo_rs
EOF
  NEED_RESTART=true
fi

# Starting/restarting the MongoDB service as needed to make sure it is running
# and uses the right config
if test "$NEED_RESTART" = true; then
  service mongod restart
else
  if ! service mongod status &>/dev/null; then
    service mongod start
  fi
fi

# Giving time to MongoDB to start up properly (maybe for the first time)
sleep 5

# Init the replicaset if it's needed
if test "$(mongo --norc --quiet --eval 'rs.status()["codeName"]')" = "NotYetInitialized"; then
  # Getting all the related nodes from GCE
  nodes=$(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | grep 'RUNNING$' | awk '{print $1}')
  i=0
  readarray -t node_arr < <(for node in $nodes; do echo "{ _id : $i, host : '${node}:27017' }"; let i++ || true; done)
  members_str=$(printf ",%s" "${node_arr[@]}")
  members_str=${members_str:1}
  # Doing the replicaset initialization
  if mongo --norc --quiet --eval "rs.initiate( {_id : 'demo_rs', \
      members: [ $members_str ] \
    })" | grep -q 'NewReplicaSetConfigurationIncompatible'; then
    # If the initialization failed because there are nodes in the replica set
    # already and this node cannot start a "new one", then add this node to the
    # replicaset using the current primary node
    OUR_HOSTNAME=$(hostname -s)
    # Now check who is master on a node which is in `RUNNING` state
    MASTER_HOST=$(ssh -o StrictHostKeyChecking=no -l ubuntu -i /home/ubuntu/.ssh/id_rsa $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | grep 'RUNNING$' | awk '{print $1}' | head -n 1) "/usr/bin/mongo --norc --quiet --eval 'rs.isMaster().primary' | cut -d':' -f1")
    # SSH to the master and run the replicaset add command for this node
    ssh -o StrictHostKeyChecking=no -l ubuntu -i /home/ubuntu/.ssh/id_rsa $MASTER_HOST "/usr/bin/mongo --norc --quiet --eval 'rs.add(\"${OUR_HOSTNAME}:27017\")'"
  fi
fi

# Setup of the node is done
