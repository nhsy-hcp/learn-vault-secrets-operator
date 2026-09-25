# team is read from the pre-created entity's metadata, so each app only sees its own team's path
path "kvv2/data/teams/{{identity.entity.metadata.team}}/*" {
   capabilities = ["read", "list", "subscribe"]
   subscribe_event_types = ["kv*"]
}
path "sys/events/subscribe/kv*" {
   capabilities = ["read"]
}
