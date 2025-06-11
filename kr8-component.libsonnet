local kcomp = import 'kube-component.libsonnet';
local kr8_cluster = std.extVar('kr8_cluster');
local kr8_lib = import 'kube-traefik.libsonnet';
local certs = import 'kube-certs.libsonnet';
local dc = import 'simple-docker-compose.libsonnet';

{
  RenderComponent(config): (
    if 'compose' in kr8_cluster.type && kr8_cluster.type.compose.enabled then
      self.ProcessCompose(config)
    else if 'kube' in kr8_cluster.type && kr8_cluster.type.kube.enabled then (
      if 'deployment' in config && 'generate' in config.deployment.kube && config.deployment.kube.generate then std.flattenArrays([
        // generate kube from compose
        kcomp.generate_component(kr8_cluster, config, compose)
        for compose in self.ProcessCompose(config)
      ]) else []
    )
    else
      []
  ),
  // TODO: add option to allow insecure on 80
  GenerateInterface(config, interface): (
    local def_middlewares = [
      kr8_lib.TraefikMiddlewareIPAllowlist(config, interface, kr8_cluster.tiers[config.tier].network.ranges_ingress),
      kr8_lib.TraefikMiddlewareHttpUpgrade(config, interface)
    ];
    (if 'middlewares' in interface then interface.middlewares + [
      kr8_lib.TraefikIngressRoute(config, interface, kr8_cluster.base_domain)
    ] else
    (if interface.type == 'http' then [
        kr8_lib.TraefikIngressRoute(config, interface{middlewares+:def_middlewares}, kr8_cluster.base_domain)
      ] +
      def_middlewares
    else [])) +
    (if 'namespace' in interface && !std.objectHas(kr8_cluster.tiers, interface.namespace) then [
      certs.KubeCert(kr8_cluster, config.tier, interface.namespace, (if 'domain' in kr8_cluster.tiers[config.tier] then kr8_cluster.tiers[config.tier].domain else kr8_cluster.base_domain))
    ] else [])
  ),
  GenerateCombinedInterface(config, interfaces): (
  [kr8_lib.TraefikCombineIngressRoute(config, interfaces, (if 'domain' in config then config.domain else kr8_cluster.base_domain))] +
    (if 'namespace' in interfaces[0] && !std.objectHas(kr8_cluster.tiers, interfaces[0].namespace) then [
      certs.KubeCert(kr8_cluster, config.tier, interfaces[0].namespace, (if 'domain' in kr8_cluster.tiers[config.tier] then kr8_cluster.tiers[config.tier].domain else kr8_cluster.base_domain))
    ] else [])
  ),

  ProcessCompose(config):
    (
      if 'generate' in config.deployment.compose && config.deployment.compose.generate then
        dc.generate_compose(config)
      else
        [std.parseYaml(config.deployment.compose.file)]
    ),
}



