# gce-mongodb-demo
A small demo project to showcase the setup of a dynamically scaling MongoDB replicaset using Puppet on Google Compute Engine

This demo showcases the following tools:
- Google Compute Engine command line tool
- Google Compute Engine autoscaling of instance groups
- Google Compute Engine startup scripts
- Google Compute Engine instance labeling for discovery purposes
- A very basic Puppet server
- A simple Puppet module to manage a MongoDB replicaset with auto-joining new nodes to the cluster

## Disclaimer

This project is only meant as an example showcasing how easily you can run a dinamically scaling MongoDB replicaset in Google Compute Engine using little code and configuration.

Security, extendability, error handling and flexibility was **NOT** really considered, becasue it is just a simple demo project. Please **DO NOT** use it directly without modifications for managing **production deployments** of MongoDB! In fact I simply advise you against running an autoscaling MongoDB replicaset in production in general, since it only boosts read performance and may have very serious, not expected side effects. So really consider this project only a showcase for Google Compute Engine autoscaling with startup scripts and Puppet added to the mix.

## Prerequisites

1. Set up a Project on Google Cloud Platform with Billing enabled
1. Login to the Google Cloud Console and go here to initialize the Google Compute Engine for the first time using this URL: https://console.cloud.google.com/compute/instances
1. Download and install the `gcloud` command line tool (Google Cloud SDK) (See the details [here](https://cloud.google.com/sdk/downloads))
1. Run `gcloud init` command to authenticate yourself against the previously created Google Cloud Platform Project
   * Also don't skip setting up a preferred default region and zone with compute engine during the gcloud init

## Launching the Puppet server

* Run the following command on your machine:
```
gcloud compute instances create puppet-server \
    --metadata-from-file startup-script=puppet_server_startup_script.sh \
    --boot-disk-size 20GB --boot-disk-type=pd-ssd \
    --machine-type g1-small \
    --image-family ubuntu-1604-lts \
    --image-project ubuntu-os-cloud
```
* Login to the instance and check if the bootstrap was successful
   * Please note that the bootstrap process may last even up to 5 minutes
```
gcloud compute ssh puppet-server
sudo -i
tail -n 600 /var/log/syslog | grep 'startupscript: '
```
* You should see something like this in the last two lines:
```
Dec 30 16:53:23 puppet-server startupscript: Branch master set up to track remote branch master from origin.
Dec 30 16:53:24 puppet-server startupscript: Finished running startup script /var/run/google.startup.script
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
    --metadata-from-file startup-script=mongodb_node_startup_script.sh
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
    --cool-down-period 180
```

## Check on an instance that everything is set up properly

Login to the first instance and check if MongoDB replicaset is running well:

```
gcloud compute ssh $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $1}') --zone $(gcloud compute instances list --filter='tags.items:mongodb-replicaset' | tail -n+2 | head -n 1 | awk '{print $2}')
mongo
rs.status().members
```

It should have 3 nodes with each of them in the this state: `"state" : 2`

## Causing syntethic CPU load to test autoscaling

FIXME

## Tear everything down

This is an important step, since this was only a demo and you should avoid unneccessary bills with running multiple machines for a long time.

Run this in the command line on your machine:

```
gcloud compute instance-groups managed delete mongodb-replicaset --region $(gcloud config get-value compute/region)
gcloud compute instance-templates delete mongodb-replicaset-template
gcloud compute instances delete puppet-server
```

## Contributing

1. Fork it!
1. Create your feature branch: `git checkout -b my-new-feature`
1. Commit your changes: `git commit -am 'Add some feature'`
1. Push to the branch: `git push origin my-new-feature`
1. Submit a pull request :)

## License

Code released under [Apache License Version 2.0](LICENSE)
