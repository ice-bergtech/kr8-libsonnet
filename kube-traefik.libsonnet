local kube = import 'kube-libsonnet/kube.libsonnet';

{
  TraefikTLSIssuer(domain, component, provider): kube._Object('traefik.io/v1alpha1', 'TLSStore', std.join('-', ['tlsstore', provider.name, std.strReplace(domain, '.', '-')]),) {
    metadata+: { namespace: 'cert-manager' },
    spec+: {
      defaultCertificate: {
        // needs to match clusterissuer secret name
        secretName: 'issuer-secret-' + std.join('-', [provider.name, std.strReplace(domain, '.', '-')]),
      },
    },
  },
  TraefikMiddlewareHttpUpgrade(component, interface): kube._Object('traefik.io/v1alpha1', 'Middleware', component.release_name + '-http2s-middleware') {
    metadata+: (if 'namespace' in interface then { namespace: interface.namespace } else {}),
    spec+: {
      redirectScheme: {
        scheme: 'https',
      },
    },
  },
  TraefikMiddlewareIPAllowlist(component, interface, defaultRanges): kube._Object('traefik.io/v1alpha1', 'Middleware', component.release_name + '-ipallowlist-middleware') {
    metadata+: (if 'namespace' in interface then { namespace: interface.namespace } else {}),
    spec+: {
      ipWhiteList: {
        sourceRange: (
          if 'ranges' in interface then
            interface.ranges
          else
            defaultRanges
        ),
      },
    },
  },
  TraefikIngressRoute(component, interface, base_domain): kube._Object('traefik.io/v1alpha1', 'IngressRoute', std.join('-', [component.release_name, interface.service, 'fe'])) {
    metadata+: {
      annotations: {
        'external-dns.alpha.kubernetes.io/hostname': '*.' + base_domain,
        // todo: parameterize off of cert-manager config
        'cert-manager.io/cluster-issuer': std.join('-', ['issuer-letsencrypt-production', std.strReplace(base_domain, '.', '-')]),
        'link.argocd.argoproj.io/external-link': 'https://' + interface.subdomain + '.' + base_domain,
      },
    } + (if 'namespace' in interface then { namespace: interface.namespace } else {}),
    spec+: {
      entryPoints: ['websecure'],
      routes: [{
        match: 'Host(`' + interface.subdomain + '.' + base_domain + '`)',
        kind: 'Rule',
        priority: 10,
        middlewares: std.map(function(m) ({ name: m.metadata.name }), interface.middlewares),
        services: [{
          name: interface.service,
          port: interface.port,
        }],
      }],
      tls: {
        domains: [{
          main: base_domain,
          sans: ['*.' + base_domain],
        }],
        secretName: 'issuer-secret-letsencrypt-production-' + std.strReplace(base_domain, '.', '-'),
      },
    },
  },

  TraefikCombineIngressRoute(component, interfaces, base_domain): kube._Object('traefik.io/v1alpha1', 'IngressRoute', std.join('-', [component.release_name, interfaces[0].service, 'fe'])) {
    metadata+: {
      annotations: {
        'external-dns.alpha.kubernetes.io/hostname': '*.' + base_domain,
        // todo: parameterize off of cert-manager config
        'cert-manager.io/cluster-issuer': std.join('-', ['issuer-letsencrypt-production', std.strReplace(base_domain, '.', '-')]),
        'link.argocd.argoproj.io/external-link': 'https://' + interfaces[0].subdomain + '.' + base_domain,
      },
    } + (if 'namespace' in interfaces[0] then { namespace: interfaces[0].namespace } else {}),
    spec+: {
      entryPoints: ['websecure'],
      routes: [
        {
          match: if 'match' in interface then interface.match else
            'Host(`' + interface.subdomain + '.' + base_domain + '`)' + (if 'path' in interface then ' && PathPrefix(`' + interface.path + '`)' else ''),
          kind: 'Rule',
          priority: interface.priority,
          //middlewares: std.map(function(m) ({ name: m.metadata.name }), interfaces[0].middlewares),
          services: [
            {
              name: interface.service,
              port: interface.port,
            } + if 'scheme' in interface then interface.scheme else {},
          ],
        }
        for interface in interfaces
        if interface.type == 'http'
      ],
      tls: {
        domains: [{
          main: base_domain,
          sans: ['*.' + base_domain],
        }],
        secretName: 'issuer-secret-letsencrypt-production-' + std.strReplace(base_domain, '.', '-'),
      },
    },
  },
}
