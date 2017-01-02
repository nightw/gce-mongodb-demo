# Determines the list of running MongoDB replicaset nodes using the gcloud
# command line tool, used for automatic replicaset cofiguration
require 'facter'
require 'json'

def mongo_rs_members_from_discovery
  instance_host_array = []
  # Very non-nice way of doing things with stderr to /devnull redirection, but
  # bear with me please, this is still just a demo and you do *NOT* want to use
  # this is production, *right*?
  output = `gcloud compute instances list --filter='tags.items:mongodb-replicaset' --format json 2>/dev/null`
  # If there was an error running the command line script, so returing an
  # empty array as a replicaset member list
  return [] unless $?.to_i == 0
  # If we got no output in the list we also return an empty array
  return [] unless !output.empty?
  # If we got an empty array as the JSON output, then the below each will not
  # yield any items, so we just return the originally initialized empty array
  # from the start of the function
  instance_objects = JSON.parse(output)
  instance_objects.each do |instance|
    instance_host_array.push instance['name'] if instance['status'] == 'RUNNING'
  end
  instance_host_array
end

Facter.add(:mongo_rs_members_from_discovery) do
  setcode do
    mongo_rs_members_from_discovery
  end
end
