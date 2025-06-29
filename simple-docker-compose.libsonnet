{
  generate_compose(service): [{
    services: {
      [service.release_name]: {
        image: service.deployment.compose.image,
        volumes: (
          if 'backup' in service then [
            vol.name + ':' + (if 'dir' in vol then vol.dir else '/app/data')
            for vol in service.backup
          ] else []
        ),
        expose: (
          if 'interfaces' in service then [
            (if 'port' in int then int.port else '80')
            for int in service.interfaces
            if int.type == 'http'
          ] else []
        ),
        networks: ['service_net_' + service.release_name]
                  + if 'interfaces' in service then ['service_net_' + service.tier] else [],
        environment: {
          UID: '1000',
          GID: '1000',
        } + ( if 'env' in service.deployment.compose then service.deployment.compose.env else {} ),
        labels: {
          service: service.release_name,
        } + (if 'references' in service && std.length(service.references) > 0 then {
          [std.strReplace(ref.name, ' ', '_')]: ref.value
          for ref in service.references
        } else {}) + (
          if 'ingress' in service.deployment.compose && service.deployment.compose.ingress == 'caddy' then {
            'caddy': "*.${STACK_DOMAIN}",
            ['caddy.1_@'+service.release_name]: 'host '+service.interfaces[0].subdomain+'.${STACK_DOMAIN}',
            'caddy.1_handle': "@"+service.release_name,
            'caddy.1_handle.reverse_proxy': "{{upstreams "+service.interfaces[0].port+"}}",
          } else {}),
      },
    },
    volumes: (if 'backup' in service then {
                [vol.name]: {}
                for vol in service.backup
              } else {}),
    networks: {
      ['service_net_' + service.release_name]: {},
    } + (
      if 'interfaces' in service && std.length(service.interfaces) > 0 then {
        ['service_net_' + service.tier]: { external: true },
      }
      else {}
    ),
  }],
  render_compose(service): [std.parseYaml(std.extVar('compose'))],
}
