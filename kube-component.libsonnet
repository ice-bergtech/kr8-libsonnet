local kr8_cluster = std.extVar('kr8_cluster');
local kube = import 'kube-libsonnet/kube.libsonnet';

{
  generate_component(kr8_cluster, config, compose): std.flattenArrays([
    (if 'backup' in config then std.map(function(d)(self.pvc(config, d)),config.backup) else []) + 
    [
      self.service_deployment(config, s.key, s.value),
      kube.Service(s.key) {
        target_pod: self.service_deployment(config, s.key, s.value),
        metadata+: { labels+: { app: s.key } },
        spec+: {
          selector: { app: s.key },
          ports: (
                if 'expose' in s.value then [
                { name: std.toString(p), port: p, targetPort: p }
                for p in s.value.expose
              ] else [] ) + 
              (if 'ports' in s.value then [
                { name: std.toString(p), port: std.split(p, ':')[0], targetPort: std.split(p, ':')[1] }
                for p in s.value.ports
              ] else []),
        },
      },
    ]
    for s in std.objectKeysValues(compose.services)
  ]),

  service_deployment(config, name, service): kube.Deployment(name) {
    spec+: {
      replicas: (if 'replicas' in service then service.replicas else 1),
      selector: { matchLabels: { app: name } },
      template: {
        metadata+: {
          labels: { app: name },
        },
        spec+: {
          containers: [
            {
              name: name,
              image: service.image,
              ports: (
                if 'expose' in service then [
                { containerPort: p }
                for p in service.expose
              ] else [] ) + 
              (if 'ports' in service then [
                { containerPort: std.split(p, ':')[1] }
                for p in service.ports
              ] else []),
              volumeMounts: (
                if 'tmpfs' in config.deployment.kube then
                  std.mapWithIndex(function(i, dir) ({ mountPath: dir, name: 'tmpfs-' + i }), config.deployment.kube.tmpfs)
                else []
              )+ (
                if 'backup' in config then
                  std.map(function(d) ({name: std.strReplace(d.name, '_', '-'), mountPath: d.dir}), config.backup)
                else []
              ),
              env: (if 'env' in config.deployment.kube then config.deployment.kube.env else []),
              securityContext: (if 'user' in config.deployment.kube then {runAsUser: config.deployment.kube.user} else {}) + 
              (if 'runAsNonRoot' in config.deployment.kube then {runAsNonRoot: config.deployment.kube.runAsNonRoot} else {runAsNonRoot: true}) + 
              (if 'readOnlyRootFilesystem' in config.deployment.kube then {readOnlyRootFilesystem: config.deployment.kube.readOnlyRootFilesystem} else {readOnlyRootFilesystem: true}),
              resources: {
                requests: {
                  memory: '64Mi',
                  cpu: '250m',
                },
                limits: {
                  memory: '256Mi',
                  cpu: '500m',
                },
              },
            },
          ],
          volumes: [] + (
            if 'tmpfs' in config.deployment.kube then
              //   name: tmpfs-ram
              //   emptyDir:
              //     medium: "Memory"
              std.mapWithIndex(function(i, path) ({ name: 'tmpfs-' + i, emptyDir: {} }), config.deployment.kube.tmpfs)
            else []
          ) + (
            if 'backup' in config then
              std.map(function(d) ({name: std.strReplace(d.name, '_', '-'), persistentVolumeClaim: {claimName: name +'-'+std.strReplace(d.name, '_', '-')}}), config.backup)
            else []
          ),
        },
      },
    },
  },

  pvc(config, dirObj): kube.PersistentVolumeClaim(config.release_name+'-'+std.strReplace(dirObj.name, '_', '-')) {
    storage: '100Mi',
    [if 'storageClass' in kr8_cluster && kr8_cluster.storageClass != null then 'storageClassName']: kr8_cluster.storageClass,
  },

  sealed_secret(name, namespace, data, namespace_wide): kube._Object('bitnami.com/v1alpha1', 'SealedSecret', name) {
    metadata+: {
      annotations+: (if namespace_wide then { 'sealedsecrets.bitnami.com/namespace-wide': 'true' } else {}),
      namespace: namespace,
    },
    spec+: {
      encryptedData: data,
    },
  },
  Configmap(config, key): kube.ConfigMap(key) {
    data+: {
      [key]: config.configmaps[key],
    },
  },
}
