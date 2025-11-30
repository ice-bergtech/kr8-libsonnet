local kr8_cluster = std.extVar('kr8_cluster');
local kube = import 'kube-libsonnet/kube.libsonnet';
{
  Argo_App(component, name, config): kube._Object('argoproj.io/v1alpha1', 'Application', std.asciiLower(std.strReplace(name, '_', '-'))) {
    metadata+: {
      namespace: 'argocd',
      labels: {
        'app.argoproj.io/name': std.asciiLower(std.strReplace(name, '_', '-')),
        'app.argoproj.io/cluster': kr8_cluster.name,
        'app.argoproj.io/tier': config.tier,
      },
    },
    spec+: {
      destination: {
        server: 'https://kubernetes.default.svc',
        namespace: (if 'namespace' in config then config.namespace else kr8_cluster.name + '-' + config.tier),
      },
      project: kr8_cluster.name + '-' + config.tier,
      sources: [] +
               (
                 if 'chart' in config.deployment then
                   if std.isArray(config.deployment.chart) then [
                     {
                       repoURL: cht.repoURL,
                       targetRevision: cht.targetRevision,
                       helm: (if 'values' in cht then { valuesObject: cht.values } else {}) +
                             (if 'parameters' in cht then { parameters: cht.parameters } else {}),
                     } + (if 'chart' in cht then { chart: cht.chart } else { path: cht.path })
                     for cht in config.deployment.chart
                     if !('enabled' in cht) || ('enabled' in cht && cht.enabled == true)
                   ] else if !('enabled' in config.deployment.chart) || ('enabled' in config.deployment.chart && config.deployment.chart.enabled == true) then [
                     {
                       local cht = config.deployment.chart,
                       repoURL: cht.repoURL,
                       targetRevision: cht.targetRevision,
                       helm: (if 'values' in cht then { valuesObject: cht.values } else {}) +
                             (if 'parameters' in config.deployment.chart then { parameters: config.deployment.chart.parameters } else {}),
                     } + (
                       if 'chart' in config.deployment.chart then { chart: config.deployment.chart.chart } else { path: config.deployment.chart.path }
                     ),
                   ] else []
                 else []
               ) +
               (
                 if 'kube' in config.deployment then
                   [{
                     repoURL: kr8_cluster.meta.repo,
                     targetRevision: kr8_cluster.meta.ref,
                     path: std.join('/', [kr8_cluster.meta.path, component]),
                   }]
                 else []
               ),
      syncPolicy: {
        automated: {
          prune: true,
          selfHeal: true,
        },
      },
      info: [{ name: 'Base Domain', value: kr8_cluster.base_domain }] + [
        ({ name: ref.name, value: ref.value })
        for ref in config.references
      ],
    },
  },
  Argo_App_Project(tier): kube._Object('argoproj.io/v1alpha1', 'AppProject', kr8_cluster.name + '-' + tier) {
    metadata+: {
      namespace: 'argocd',
      finalizers: ['resources-finalizer.argocd.argoproj.io'],
    },
    spec+: {
      description: 'Project for Applications classified as' + tier,
      // Allow manifests to deploy from any Git repos
      sourceRepos: ['*'],
      destinations: [{
        namespace: '*',
        server: '*',
      }],
      // Deny all cluster-scoped resources from being created, except for Namespace
      clusterResourceWhitelist:
        (if tier == 'core' then [{
           group: '*',
           kind: '*',
         }]
         else [
           {
             group: '*',
             kind: 'Namespace',
           },
           {
             group: '*',
             kind: 'ClusterRole',
           },
           {
             group: '*',
             kind: 'ClusterRoleBinding',
           },
           {
             group: '*',
             kind: 'CustomResourceDefinition',
           },
         ]),
      // Allow all namespaced-scoped resources to be created, except for ResourceQuota, LimitRange, NetworkPolicy
      namespaceResourceBlacklist: [
        {
          group: '',
          kind: 'ResourceQuota',
        },
        {
          group: '',
          kind: 'LimitRange',
        },
        {
          group: '',
          kind: 'NetworkPolicy',
        },
      ],
      // Deny all namespaced-scoped resources from being created, except for Deployment and StatefulSet
      namespaceResourceWhitelist: [{
        group: '*',
        kind: '*',
      }],
      roles: [
        // A role which provides read-only access to all applications in the project
        {
          name: 'read-only',
          description: 'Read-only privileges to' + tier,
          policies: ['p, proj:' + tier + ':read-only, applications, get,' + tier + '/*, allow'],
          groups: ['my-oidc-group'],
        },
        // A role which provides sync privileges to only the guestbook-dev application, e.g. to provide
        // sync privileges to a CI system
        //  - name: ci-role
        //    description: Sync privileges for guestbook-dev
        //    policies:
        //    - p, proj:{{ project_tier }}:ci-role, applications, sync, {{ project_tier }}/guestbook-dev, allow
        //    # NOTE: JWT tokens can only be generated by the API server and the token is not persisted
        //    # anywhere by Argo CD. It can be prematurely revoked by removing the entry from this list.
        //    jwtTokens:
        //    - iat: 1535390316
      ],
    },
  },
}
