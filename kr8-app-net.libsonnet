local kube = import 'kube-libsonnet/kube.libsonnet';
{
  Kube_Certificate(domains, issuer, issuer_secret, tier, namespace): 
    kube._Object('cert-manager.io/v1', 'Certificate', std.join('-', [std.strReplace(std.join('-', domains), '.', '_'), tier, 'cert'])) {
    metadata+: {
      namespace: namespace,
    },
    spec+: {
      secretName: issuer_secret,
      issuerRef: {
        name: issuer,
        kind: 'ClusterIssuer',
      },
      dnsNames: std.uniq(
        ([d  for d in domains] ) +
        (['*.' + d for d in domains] )
      )
    },
  },
  Kube_Cert_Issuer(domain, component, provider): kube._Object('cert-manager.io/v1', 'ClusterIssuer', std.join('-', ['issuer', provider.name, std.strReplace(domain, '.', '-')])) {
    metadata+: { namespace: 'cert-manager' },
    spec+:
      { acme: {
        server: provider.server,
        email: 'admin@' + domain,
        privateKeySecretRef: {
          // needs to match tlsisser secretName
          name: 'issuer-secret-' + std.join('-', [provider.name, std.strReplace(domain, '.', '-')]),
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
