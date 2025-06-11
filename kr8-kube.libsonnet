local kube = import 'kube-libsonnet/kube.libsonnet';

{
Namespace(name, labels): kube._Object('v1', 'Namespace', name) {
    metadata+: { labels: labels },
},
LoadExtKubeFiles(kr8_spec): (
    if 'extfiles' in kr8_spec then
    std.flattenArrays([
        std.parseYaml(std.extVar(f.key))
        for f in std.objectKeysValues(kr8_spec.extfiles)
    ]) else []
)
}
