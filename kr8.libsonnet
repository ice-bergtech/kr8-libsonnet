local about = import 'kr8-about.libsonnet';
local traefik = import 'kube-traefik.libsonnet';
local certs = import 'kube-certs.libsonnet';
local argo = import 'kube-argo.libsonnet';
local kr8Component = import 'kr8-component.libsonnet';
local kr8Kube = import 'kr8-kube.libsonnet';

{
  Version(): about.version,


  TraefikTLSIssuer(domain, component, provider): traefik.TraefikTLSIssuer(domain, component, provider),
  TraefikMiddlewareHttpUpgrade(component, interface): traefik.TraefikMiddlewareHttpUpgrade(component, interface),
  TraefikMiddlewareIPAllowlist(component, interface, defaultRanges): traefik.TraefikMiddlewareIPAllowlist(component, interface, defaultRanges),
  TraefikIngressRoute(component, interface, base_domain): traefik.TraefikIngressRoute(component, interface, base_domain),
  TraefikCombineIngressRoute(component, interfaces, base_domain): traefik.TraefikCombineIngressRoute(component, interfaces, base_domain),

  CertsKubeCert(kr8_cluster, tier, namespace, domain): certs.KubeCert(kr8_cluster, tier, namespace, domain),
  CertsKubeIssuer(domain, component, provider): certs.KubeIssuer(domain, component, provider),
  
  ArgoApp(component, name, config): argo.Argo_App(component, name, config),
  ArgoAppProj(tier): argo.Argo_App_Project(tier),

  Namespace(name, labels): kr8Kube.Namespace(name, labels),

  Kr8CmpRenderComponent(config) : kr8Component.RenderComponent(config),
}
