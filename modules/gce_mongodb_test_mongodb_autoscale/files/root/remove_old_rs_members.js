// Remove ReplicaSet members which are in an unreachable state for more than 3 minutes
members_to_remove = rs.status().members.filter(
  function(rsStatus) {
    return rsStatus.state === 8 && rsStatus.lastHeartbeatRecv < new Date(new Date() - 1000*60*3);
  }).map(
    function(member) {
      return member.name;
    }
  )
cfg = rs.config()
cfg.members = cfg.members.filter(
  function (member) {
    return ! members_to_remove.includes(member.host);
  })
rs.reconfig(cfg, {force : true})
