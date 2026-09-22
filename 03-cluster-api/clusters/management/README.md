# Ejemplo de load balancer con Cilium

El cluster `management` ya tiene Cilium instalado (vía
`../../helm-chart-proxies.yaml`) con `l2announcements` habilitado. Este
directorio muestra cómo darle un pool de IPs fijas de la red del bridge
(`10.77.100.0/24`).

```bash
kubectl apply -f loadbalancer.yaml.sample
```

Con `sample.yaml` se crea un nginx con un `Service` tipo `LoadBalancer` para
verificar que efectivamente toma una IP del pool:

```bash
kubectl apply -f sample.yaml
kubectl get svc nginx-service
```

Este directorio también tiene `cluster-tooling.yaml` y
`helm-chart-proxies.yaml`, que no son parte de este ejemplo — ver
"Segundo cluster: tooling" en `../../README.md`.
