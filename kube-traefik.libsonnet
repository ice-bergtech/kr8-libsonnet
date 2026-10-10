local kube = import 'kube-libsonnet/kube.libsonnet';

{
  local wantsTls(interface) = !('cert' in interface) || interface.cert,

  TraefikTLSIssuer(domain, component, provider): kube._Object('traefik.io/v1alpha1', 'TLSStore', std.join('-', ['tlsstore', provider.name, std.strReplace(domain, '.', '-')])) {
    metadata+: { namespace: 'cert-manager' },
    spec+: {
      defaultCertificate: {
        // needs to match clusterissuer secret name
        secretName: 'issuer-secret-' + std.join('-', [provider.name, std.strReplace(domain, '.', '-')]),
      },
    },
  },

  TraefikMiddlewareHttpUpgrade(component, interface): kube._Object('traefik.io/v1alpha1', 'Middleware', component.release_name + '-http2s-middleware') {
    metadata+: if 'namespace' in interface then { namespace: interface.namespace } else {},
    spec+: {
      redirectScheme: {
        scheme: 'https',
      },
    },
  },

  TraefikMiddlewareIPAllowlist(component, interface, defaultRanges): kube._Object('traefik.io/v1alpha1', 'Middleware', component.release_name + '-ipallowlist-middleware') {
    metadata+: if 'namespace' in interface then { namespace: interface.namespace } else {},
    spec+: {
      ipAllowList: {
        sourceRange: if 'ranges' in interface then interface.ranges else defaultRanges,
      },
    },
  },

  TraefikIngressRoute(component, interface, base_domain): kube._Object('traefik.io/v1alpha1', 'IngressRoute', std.join('-', [component.release_name, interface.service, 'fe'])) {
    metadata+: {
      annotations: {
        'external-dns.alpha.kubernetes.io/hostname': '*.' + base_domain,
      } + (if wantsTls(interface) then {
        // todo: parameterize off of cert-manager config
        'cert-manager.io/cluster-issuer': std.join('-', ['issuer-letsencrypt-production', std.strReplace(base_domain, '.', '-')]),
      } else {}) + (if 'subdomain' in interface then {
        'link.argocd.argoproj.io/external-link': (if wantsTls(interface) then 'https://' else 'http://') + interface.subdomain + '.' + base_domain,
      } else {}),
    } + (if 'namespace' in interface then { namespace: interface.namespace } else {}),

    spec+: {
      entryPoints: if 'entryPoints' in interface then interface.entryPoints else if wantsTls(interface) then ['websecure'] else ['web'],
      routes: if 'routes' in interface then interface.routes else [
        (if 'subdomain' in interface then
          { match: 'Host(`' + interface.subdomain + '.' + base_domain + '`)'
          }
        else
          { match: 'Host(`' + base_domain + '`)'
        }) + {
          kind: 'Rule',
          priority: 10,
          middlewares: std.map(function(m) ({ name: m.metadata.name }), interface.middlewares),
          services: [{
            name: interface.service,
            port: interface.port,
          }],
        }
      ],
    } + (if wantsTls(interface) then {
      tls: {
        domains: [{
          main: base_domain,
          sans: ['*.' + base_domain],
        }],
        secretName: 'issuer-secret-letsencrypt-production-' + std.strReplace(base_domain, '.', '-'),
      },
    } else {}),
  },

  TraefikCombineIngressRoute(component, interfaces, base_domain): kube._Object('traefik.io/v1alpha1', 'IngressRoute', std.join('-', [component.release_name, interfaces[0].service, 'fe'])) {
    metadata+: {
      annotations: {
        'external-dns.alpha.kubernetes.io/hostname': '*.' + base_domain,
      } + (if wantsTls(interfaces[0]) then {
        // todo: parameterize off of cert-manager config
        'cert-manager.io/cluster-issuer': std.join('-', ['issuer-letsencrypt-production', std.strReplace(base_domain, '.', '-')]),
      } else {}) + (if 'subdomain' in interfaces[0] then {
        'link.argocd.argoproj.io/external-link': (if wantsTls(interfaces[0]) then 'https://' else 'http://') + interfaces[0].subdomain + '.' + base_domain,
      } else {}),
    } + (if 'namespace' in interfaces[0] then { namespace: interfaces[0].namespace } else {}),

    spec+: {
      entryPoints: if wantsTls(interfaces[0]) then ['websecure'] else ['web'],
      routes: [
        {
          match: if 'match' in interface then interface.match else
            'Host(`' + interface.subdomain + '.' + base_domain + '`)' + (if 'path' in interface then ' && PathPrefix(`' + interface.path + '`)' else ''),
          kind: 'Rule',
          priority: if 'priority' in interface then interface.priority else 10,
          services: [
            {
              name: interface.service,
              port: interface.port,
            } + (if 'scheme' in interface then { scheme: interface.scheme } else {}),
          ],
        }
        for interface in interfaces
        if interface.type == 'http'
      ],
    } + (if wantsTls(interfaces[0]) then {
      tls: {
        domains: [{
          main: base_domain,
          sans: ['*.' + base_domain],
        }],
        secretName: 'issuer-secret-letsencrypt-production-' + std.strReplace(base_domain, '.', '-'),
      },
    } else {}),
  },
}
