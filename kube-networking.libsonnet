local kube = import 'kube-libsonnet/kube.libsonnet';

{
  KubeNodePort(component, interface, base_domain): kube._Object('traefik.io/v1alpha1', 'IngressRoute', std.join('-', [component.release_name, interface.service, 'fe'])) {
    metadata+: {
      annotations: {
        'external-dns.alpha.kubernetes.io/hostname': '*.' + base_domain,
        'link.argocd.argoproj.io/external-link': interface.subdomain + '.' + base_domain,
      },
    } + (if 'namespace' in interface then { namespace: interface.namespace } else {}),
    spec+: {
      type: 'NodePort',
      selector: {
        app: interface.service,
      },
      ports: [{
        name: 'int-'+interface.service,
        port: interface.externalPort,
        targetPort: interface.port,
        nodePort: interface.externalPort,
        protocol: interface.type,
      }],
    },
  },
}
