local about = import 'kr8-about.libsonnet';
local traefik = import 'kube-traefik.libsonnet';
local certs = import 'kube-certs.libsonnet';

{
  Version(): about.version,


  TraefikTLSIssuer(domain, component, provider): traefik.TraefikTLSIssuer(domain, component, provider),
  TraefikMiddlewareHttpUpgrade(component, interface): traefik.TraefikMiddlewareHttpUpgrade(component, interface),
  TraefikMiddlewareIPAllowlist(component, interface, defaultRanges): traefik.TraefikMiddlewareIPAllowlist(component, interface, defaultRanges),
  TraefikIngressRoute(component, interface, base_domain): traefik.TraefikIngressRoute(component, interface, base_domain),
  TraefikCombineIngressRoute(component, interfaces, base_domain): traefik.TraefikCombineIngressRoute(component, interfaces, base_domain),

  CertsKubeCert(kr8_cluster, tier, namespace, domain): certs.KubeCert(kr8_cluster, tier, namespace, domain),
  CertsKubeIssuer(domain, component, provider): certs.KubeIssuer(domain, component, provider),
}