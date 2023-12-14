# step2-1 wordpress app

# mysql-headless.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress
spec:
  ports:
    - port: 3306
  selector:
    app: wordpress
    tier: mysql
  clusterIP: None
```

→ mysql-headless.yaml은 kustomization.yaml에 같이 넣어서 실행했으나 서비스가 기존의 것이랑 충돌해서 먼저 kubctl apply -k ./ 이후에 다시 kubectl apply -f mysql-headless.yaml로 다시 실행하여 덮어씌어 주었습니다.

# mysql-lb.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  ports:
    - port: 80
  selector:
    app: wordpress
    tier: frontend
  type: LoadBalancer
```

→ mysql이 아니라 wordpress-lb가 되어야하는데 제가 깜빡하고 진행해서 수정 못했습니다. 

→ 아마 다시 정리할 때는 제대로 할 것 같습니다.

```bash
kubectl get svc
NAME              TYPE           CLUSTER-IP       EXTERNAL-IP                                                                   PORT(S)        AGE
kubernetes        ClusterIP      172.20.0.1       <none>                                                                        443/TCP        53m
wordpress         LoadBalancer   172.20.222.179   a4c4d500d18dc430098f94f3a8f6c4c7-480717099.ap-northeast-2.elb.amazonaws.com   80:31232/TCP   39m
wordpress-mysql   ClusterIP      None             <none>                                                                        3306/TCP       39m
```

→ loadbalancer 정상 작동 확인했습니다

→ 추후 ingress 적용할 예정입니다.

[Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)

[](https://github.com/kubernetes/ingress-nginx/blob/main/README.md#readme)

# ingress controller 설치해주었습니다.

```bash
brew install helm

helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace

kubectl get all -n ingress-nginx
NAME                                            READY   STATUS    RESTARTS   AGE
pod/ingress-nginx-controller-6b448794df-d86td   1/1     Running   0          72s

NAME                                         TYPE           CLUSTER-IP      EXTERNAL-IP                                                                  PORT(S)                      AGE
service/ingress-nginx-controller             LoadBalancer   10.100.93.139   a61571edf24c14f31b20a13e76b79b92-28163619.ap-northeast-2.elb.amazonaws.com   80:30118/TCP,443:30394/TCP   72s
service/ingress-nginx-controller-admission   ClusterIP      10.100.54.133   <none>                                                                       443/TCP                      72s

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-nginx-controller   1/1     1            1           72s

NAME                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/ingress-nginx-controller-6b448794df   1         1         1       72s
```

# ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /wordpress
        pathType: Prefix
        backend:
          service:
            name: wordpress  
            port:
              number: 80
```

→ 이후 kubectl apply -f ingress.yaml 로 강제 실행 이후 서버 확인해 보았습니다.

![스크린샷 2023-12-07 오후 3.25.47.png](step2-1%20wordpress%20app%204caabf335b3a4518aec2fb9b7297671e/%25E1%2584%2589%25E1%2585%25B3%25E1%2584%258F%25E1%2585%25B3%25E1%2584%2585%25E1%2585%25B5%25E1%2586%25AB%25E1%2584%2589%25E1%2585%25A3%25E1%2586%25BA_2023-12-07_%25E1%2584%258B%25E1%2585%25A9%25E1%2584%2592%25E1%2585%25AE_3.25.47.png)

→ wordpress 한국어 설정이후 계정 생성해서 site 실행해 보았습니다

→ 현재 사이트에 트래픽 걸어서 확인해 보려고 했으나 이후 hpa 설정이후 하려고 결정했습니다.

# metric-server 설치

[Kubernetes 지표 서버 설치 - Amazon EKS](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/metrics-server.html)

→ 위 사이트 보고 참고했습니다.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl get deployment metrics-server -n kube-system
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           53s
```

## wordpress-hpa 적용

[HorizontalPodAutoscaler 연습](https://kubernetes.io/ko/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)

→ 위사이트 보고 참고했습니다.

```bash
kubectl get pod
NAME                               READY   STATUS    RESTARTS   AGE
wordpress-78889d7b4d-7qxgd         1/1     Running   0          47m
wordpress-mysql-0                  1/1     Running   0          44m
wordpress-mysql-1                  1/1     Running   0          43m
wordpress-mysql-79f4b97879-x4b5x   1/1     Running   0          47m

kubectl top pod wordpress-78889d7b4d-7qxgd
NAME                         CPU(cores)   MEMORY(bytes)   
wordpress-78889d7b4d-7qxgd   1m           20Mi

#autoscale 실시
kubectl autoscale deployment wordpress --cpu-percent=50 --min=1 --max=10
horizontalpodautoscaler.autoscaling/wordpress autoscaled

kubectl describe pod wordpress-78889d7b4d-7qxgd
# 확인
```

→ 현재 위에서 이름설정을 잘못해서 살짝 애매한점이 있습니다. 참고바랍니다.

→ 현재 부하주는 pod를 따로 새로운 터미널에 생성하여 확인하고 있습니다.

```bash
kubectl get hpa -w
NAME        REFERENCE              TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
wordpress   Deployment/wordpress   <unknown>/50%   1         10        1          2m38s
^C%
```

→ 부하를 주었는데 어디부분이 잘못되었는지 replicas에 변동이 생기지 않습니다. 사이트를 잘못 넣은 것 같습니다. 추후 확인해보겠습니다.