local config = std.extVar('kr8');
local clusterLevelKinds = std.set(
  [
    // these resource types should not be namespaced
    'ClusterRoleBinding',
    'ClusterRole',
    'CustomResourceDefinition',
    'Namespace',
    'PersistentVolume',
    'StorageClass',
  ] + (
    // include additional list from config
    if 'kr8_nons_kinds' in config then config.kr8_nons_kinds else []
  )
);

{
  AddNamespace(object, namespace): (
    if 'kind' in object &&
       !std.setMember(object.kind, clusterLevelKinds) &&
       'metadata' in object
    then (
      if 'namespace' in object.metadata then
        object
      else
        object { metadata+: {
          namespace: namespace,
        } }
    )
    else
      object
  ),
}
