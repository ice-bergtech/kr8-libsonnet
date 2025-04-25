local kube = import 'kube-libsonnet/kube.libsonnet';
{
KubeCert(kr8_cluster, tier, namespace, domain): kube._Object('cert-manager.io/v1', 'Certificate', std.join('-', [kr8_cluster.name, tier, 'cert'])) {
    metadata+: {
      namespace: namespace,
    },
    spec+: {
      secretName: 'issuer-secret-letsencrypt-production-' + std.strReplace(domain,'.','-'),
      issuerRef: {
        name: std.join('-', ['issuer','letsencrypt', 'production', std.strReplace(domain,'.','-')]),
        kind: 'ClusterIssuer',
      },
      dnsNames: [
        domain,
        '*.' + domain,
      ],
    },
  },
KubeIssuer(domain, component, provider): kube._Object('cert-manager.io/v1', 'ClusterIssuer', std.join('-', ['issuer', provider.name, std.strReplace(domain,'.','-')])) {
    metadata+: { namespace: 'cert-manager' },
    spec+:
      { acme: {
        server: provider.server,
        email: 'admin@' + domain,
        privateKeySecretRef: {
          // needs to match tlsisser secretName
          name: 'issuer-secret-'+std.join('-', [provider.name, std.strReplace(domain,'.','-')]),
        },
        solvers:
          [{ [provider.solver.type]:
            { webhook: {
              groupName: 'acme.cluster.local',
              solverName: provider.solver.name,
              config: { apiKeySecretRef: {
                name: provider.solver.name + '-token',
                key: 'data',
              } },
            } } }],
      } },
  },
}