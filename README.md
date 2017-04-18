# gce-mongodb-demo
A small demo project to showcase the setup of a dynamically scaling MongoDB replicaset on Google Compute Engine

This demo showcases the following tools:
- Google Compute Engine command line tool
- Google Compute Engine autoscaling of instance groups
- Google Compute Engine startup scripts
- Google Compute Engine instance tagging
- Google Compute Engine metadata write at creation time and retrieval on the VMs

## Disclaimer

This project is only meant as an example showcasing how easily you can run a dinamically scaling MongoDB replicaset in Google Compute Engine using only built-in GCE features.

Security, extendability, error handling and flexibility was **NOT** really considered, becasue it is just a simple demo project. Please **DO NOT** use it directly without modifications for managing **production deployments** of MongoDB! In fact I simply advise you against running an autoscaling MongoDB replicaset in production in general, since it only boosts read performance and may have very serious, not expected side effects. So really consider this project only a showcase for Google Compute Engine autoscaling feature using only startup scripts and metadata.

## Prerequisites

1. Set up a Project on Google Cloud Platform with Billing enabled
1. Login to the Google Cloud Console and go here to initialize the Google Compute Engine for the first time using this URL: https://console.cloud.google.com/compute/instances
1. Download and install the `gcloud` command line tool (Google Cloud SDK) (See the details [here](https://cloud.google.com/sdk/downloads))
1. Run `gcloud init` command to authenticate yourself against the previously created Google Cloud Platform Project
   * Also don't skip setting up a preferred default region and zone with compute engine during the gcloud init
1. Clone this git repository to your computer and set your working directory to it:
```
git clone https://github.com/nightw/gce-mongodb-demo.git
cd gce-mongodb-demo
```
1. Create an SSH keypair on your machine for the VMs to be able to SSH to each other:
```
ssh-keygen -f /tmp/temp_id_rsa -C ubuntu@mongodb-rs
```

## Creating the Instance Group for the MongoDB machines

* Create an instance template:
```
gcloud compute instance-templates create mongodb-replicaset-template \
    --machine-type g1-small \
    --image-family ubuntu-1604-lts \
    --image-project ubuntu-os-cloud \
    --boot-disk-type pd-ssd \
    --boot-disk-size 25GB \
    --tags mongodb-replicaset \
    --scopes useraccounts-ro,storage-ro,logging-write,monitoring-write,service-management,service-control,compute-ro \
    --metadata mongodb_ssh_priv_key="$(cat /tmp/temp_id_rsa)",mongodb_ssh_pub_key="$(cat /tmp/temp_id_rsa.pub)" \
    --metadata-from-file startup-script=mongodb_node_startup_script.sh,shutdown-script=mongodb_node_shutdown_script.sh
```
* Create the instance group:
```
gcloud compute instance-groups managed create mongodb-replicaset \
    --base-instance-name mongodb-rs \
    --size 3 \
    --region $(gcloud config get-value compute/region) \
    --template mongodb-replicaset-template
```
* Set autoscaling on the previously created instance group:
```
gcloud compute instance-groups managed set-autoscaling mongodb-replicaset \
    --max-num-replicas 7 \
    --min-num-replicas 3 \
    --target-cpu-utilization 0.5 \
    --region $(gcloud config get-value compute/region) \
    --cool-down-period 60
```

## Check on an instance that everything is set up properly

Login to the first instance and check if MongoDB replicaset is running well (please note that the bootstrap process can take 1-2 minutes):

```
gcloud compute ssh $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $1}') --zone $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $2}')
mongo --norc --quiet --eval 'rs.status().members.forEach(function(member) {print(member["name"] + "\t" + member["stateStr"] + "  \tuptime: " + member["uptime"] + "s")})'
```

It should have 3 nodes with two of them in the this state: `SECONDARY` and one of them in `PRIMARY` state.

## Causing syntethic CPU load to test autoscaling

* SSH into a node and make it look overloaded (and leave the SSH session open):
```
gcloud compute ssh $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $1}') --zone $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $2}')
cat /dev/zero > /dev/null
```
*  Watch until Google Compute Engine starts new nodes in a new shell on your machine
```
while :; do clear; gcloud compute instance-groups managed list-instances mongodb-replicaset --region $(gcloud config get-value compute/region); sleep 2; done
```
* After the new VMs have been created in the replicaset wait a bit then SSH to one of them again and check the status of the cluster
```
gcloud compute ssh $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $1}') --zone $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $2}')
mongo --norc --quiet --eval 'rs.status().members.forEach(function(member) {print(member["name"] + "\t" + member["stateStr"] + "  \tuptime: " + member["uptime"] + "s")})'
```
* It should have 6 nodes with five of them in `SECONDARY` and one of them in `PRIMARY` state.
* Now stop the syntethic CPU load in the still open shell from before with CTRL-C
* Watch the replicaset again for the disappearing nodes on your machine:
```
while :; do clear; gcloud compute instance-groups managed list-instances mongodb-replicaset --region $(gcloud config get-value compute/region); sleep 2; done
```
* Please note that it will take about 10-12 minutes before any VMs will be shut down (The reason is that the autoscaler wants to make sure you use the first 10 minutes of your VMs, since the first 10 minutes must be paid in any case even if you terminate your instances before it)
* When some of them has been deleted SSH again to the cluster and see the status of it:
```
gcloud compute ssh $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $1}') --zone $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $2}')
mongo --norc --quiet --eval 'rs.status().members.forEach(function(member) {print(member["name"] + "\t" + member["stateStr"] + "  \tuptime: " + member["uptime"] + "s")})'
```
* It should have 3 nodes with two of them in `SECONDARY` and one of them in `PRIMARY` state.

Now you have seen the autoscaler scaling up and down instances and the MongoDB replicaset also growing and shrinking alongside.

## Tear everything down

This is an important step, since this was only a demo and you should avoid unneccessary bills with running multiple machines for a long time.

Run this in the command line on your machine:

```
gcloud compute instance-groups managed delete mongodb-replicaset --region $(gcloud config get-value compute/region)
gcloud compute instance-templates delete mongodb-replicaset-template
```

## A bit more advanced example

If you want to see an example which uses a Puppet server node to configure the MongoDB replicaset, then you can check out the `with_puppet_server` branch of this repository.

## Contributing

1. Fork it!
1. Create your feature branch: `git checkout -b my-new-feature`
1. Commit your changes: `git commit -am 'Add some feature'`
1. Push to the branch: `git push origin my-new-feature`
1. Submit a pull request :)

## License

Code released under [Apache License Version 2.0](LICENSE)
