# step2-2 stateless app deploy

[상태 유지를 하지 않는 애플리케이션](https://kubernetes.io/ko/docs/tutorials/stateless-application/)

→ 이것 보면서 진행했습니다.

→ Redis가 stateless 인지는 모르겠으나 예시 따라가 보려고 노력했습니다.

# Redis-leader-deployment.yaml

```yaml
# SOURCE: https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-leader
  labels:
    app: redis
    role: leader
    tier: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        role: leader
        tier: backend
    spec:
      containers:
      - name: leader
        image: "docker.io/redis:6.0.5"
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 6379
```

```bash
kubectl apply -f https://k8s.io/examples/application/guestbook/redis-leader-deployment.yaml

kubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
redis-leader-58b566dc8b-x97wz      1/1     Running   0          9s
wordpress-6cccb69f77-gpqc6         1/1     Running   0          12m
wordpress-mysql-0                  1/1     Running   0          171m
wordpress-mysql-1                  1/1     Running   0          171m
wordpress-mysql-79f4b97879-x4b5x   1/1     Running   0          175m

```

# redis-leader-service.yaml

```yaml
# SOURCE: https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook
apiVersion: v1
kind: Service
metadata:
  name: redis-leader
  labels:
    app: redis
    role: leader
    tier: backend
spec:
  ports:
  - port: 6379
    targetPort: 6379
  selector:
    app: redis
    role: leader
    tier: backend
```

```bash
kubectl get service
NAME              TYPE           CLUSTER-IP       EXTERNAL-IP                                                                   PORT(S)        AGE
kubernetes        ClusterIP      172.20.0.1       <none>                                                                        443/TCP        3h10m
redis-leader      ClusterIP      172.20.129.45    <none>                                                                        6379/TCP       7s
wordpress         LoadBalancer   172.20.222.179   a4c4d500d18dc430098f94f3a8f6c4c7-480717099.ap-northeast-2.elb.amazonaws.com   80:31232/TCP   176m
wordpress-mysql   ClusterIP      None             <none>                                                                        3306/TCP       176m
```

# Redis-follower-deployment.yaml

```yaml
# SOURCE: https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-follower
  labels:
    app: redis
    role: follower
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        role: follower
        tier: backend
    spec:
      containers:
      - name: follower
        image: gcr.io/google_samples/gb-redis-follower:v2
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 6379
```

```bash
kubectl apply -f https://k8s.io/examples/application/guestbook/redis-follower-deployment.yaml

kubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
redis-follower-6f6cd6cbdb-8trwn    1/1     Running   0          9s
redis-follower-6f6cd6cbdb-nm82j    1/1     Running   0          10s
redis-leader-58b566dc8b-x97wz      1/1     Running   0          3m2s
wordpress-6cccb69f77-gpqc6         1/1     Running   0          15m
wordpress-mysql-0                  1/1     Running   0          174m
wordpress-mysql-1                  1/1     Running   0          174m
wordpress-mysql-79f4b97879-x4b5x   1/1     Running   0          178m
```

# Redis-follower-service.yaml

```yaml
# SOURCE: https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook
apiVersion: v1
kind: Service
metadata:
  name: redis-follower
  labels:
    app: redis
    role: follower
    tier: backend
spec:
  ports:
    # the port that this service should serve on
  - port: 6379
  selector:
    app: redis
    role: follower
    tier: backend
```

```bash
kubectl apply -f https://k8s.io/examples/application/guestbook/redis-follower-service.yaml
```

# NodeAffinity(특정노드에 배포하기)

[Assign Pods to Nodes using Node Affinity](https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes-using-node-affinity/)

# frontend-service.yaml

튜토리얼 원본 → affinity추가 + 이미지 문제 해결

```yaml
kubectl label nodes ip-10-0-1-98.ap-northeast-2.compute.internal affinity=test
node/ip-10-0-1-98.ap-northeast-2.compute.internal labeled

kubectl get node -L affinity 
NAME                                            STATUS   ROLES    AGE   VERSION               AFFINITY
ip-10-0-1-98.ap-northeast-2.compute.internal    Ready    <none>   15h   v1.27.7-eks-e71965b   test
ip-10-0-2-156.ap-northeast-2.compute.internal   Ready    <none>   15h   v1.27.7-eks-e71965b   
ip-10-0-2-200.ap-northeast-2.compute.internal   Ready    <none>   15h   v1.27.7-eks-e71965b
```

```yaml
# SOURCE: https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
        app: guestbook
        tier: frontend
  template:
    metadata:
      labels:
        app: guestbook
        tier: frontend
    spec:
      containers:
      - name: php-redis
        image: gcr.io/google_samples/gb-frontend:v5
        env:
        - name: GET_HOSTS_FROM
          value: "dns"
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 80
```

→ 이대로 진행했으나 errImagePull 에러 발생

```bash
kubectl get pods -l app=guestbook -l tier=frontend -w
NAME                         READY   STATUS             RESTARTS   AGE
frontend-697bd54cd4-dlzdg    0/1     ImagePullBackOff   0          2m49s
frontend-697bd54cd4-nllrh    0/1     ImagePullBackOff   0          2m49s
frontend-697bd54cd4-z4dbn    0/1     ImagePullBackOff   0          2m49s
wordpress-6cccb69f77-gpqc6   1/1     Running            0          20m
```

→ [gcr.io/google_samples/gb-frontend:v5](http://gcr.io/google_samples/gb-frontend:v5) 에서 문제 발생 → obsolete

→ [us-docker.pkg.dev/google-samples/containers/gke/gb-frontend:v5](http://us-docker.pkg.dev/google-samples/containers/gke/gb-frontend:v5) 대체 후 다시 작성

```yaml
# SOURCE: https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
        app: guestbook
        tier: frontend
  template:
    metadata:
      labels:
        app: guestbook
        tier: frontend
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: affinity
                operator: In
                values:
                - test
      containers:
      - name: php-redis
        image: us-docker.pkg.dev/google-samples/containers/gke/gb-frontend:v5
        env:
        - name: GET_HOSTS_FROM
          value: "dns"
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 80
```

```yaml
kubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
redis-follower-6f6cd6cbdb-8trwn    1/1     Running   0          27m
redis-follower-6f6cd6cbdb-nm82j    1/1     Running   0          28m
redis-leader-58b566dc8b-x97wz      1/1     Running   0          30m
wordpress-6cccb69f77-gpqc6         1/1     Running   0          43m
wordpress-mysql-0                  1/1     Running   0          3h22m
wordpress-mysql-1                  1/1     Running   0          3h22m
wordpress-mysql-79f4b97879-x4b5x   1/1     Running   0          3h26m
```

→ 해결됨 + affinity 특정 노드확인

frontend-service.yaml

```yaml
# SOURCE: https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook
apiVersion: v1
kind: Service
metadata:
  name: frontend
  labels:
    app: guestbook
    tier: frontend
spec:
  # if your cluster supports it, uncomment the following to automatically create
  # an external load-balanced IP for the frontend service.
  type: LoadBalancer
  # type: LoadBalancer
  ports:
    # the port that this service should serve onㅏ
  - port: 80
  selector:
    app: guestbook
    tier: frontend
```

→ LoalBalancer 사용을 위해 type 주석 제거

```bash
kubectl apply -f frontend-service.yaml
service/frontend created

kubectl get services
NAME              TYPE           CLUSTER-IP       EXTERNAL-IP                                                                   PORT(S)        AGE
frontend          LoadBalancer   172.20.228.190   a8a77dfa926714a50a79132671da8fc0-449986299.ap-northeast-2.elb.amazonaws.com   80:32161/TCP   8s
kubernetes        ClusterIP      172.20.0.1       <none>                                                                        443/TCP        21h
redis-follower    ClusterIP      172.20.34.196    <none>                                                                        6379/TCP       18h
redis-leader      ClusterIP      172.20.129.45    <none>                                                                        6379/TCP       18h
wordpress         LoadBalancer   172.20.222.179   a4c4d500d18dc430098f94f3a8f6c4c7-480717099.ap-northeast-2.elb.amazonaws.com   80:31232/TCP   21h
wordpress-mysql   ClusterIP      None             <none>  

kubectl get node -o wide
NAME                                            STATUS   ROLES    AGE   VERSION               INTERNAL-IP   EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
ip-10-0-1-98.ap-northeast-2.compute.internal    Ready    <none>   33h   v1.27.7-eks-e71965b   10.0.1.98     <none>        Amazon Linux 2   5.10.198-187.748.amzn2.x86_64   containerd://1.6.19
ip-10-0-2-156.ap-northeast-2.compute.internal   Ready    <none>   33h   v1.27.7-eks-e71965b   10.0.2.156    <none>        Amazon Linux 2   5.10.198-187.748.amzn2.x86_64   containerd://1.6.19
ip-10-0-2-200.ap-northeast-2.compute.internal   Ready    <none>   33h   v1.27.7-eks-e71965b   10.0.2.200    <none>        Amazon Linux 2   5.10.198-187.748.amzn2.x86_64   containerd://1.6.19

# port forwarding
kubectl port-forward svc/frontend 8080:80                                                                      3306/TCP       21h
```

→ 포트 포워딩 후 확인 ( Nodeport 로 하는 것을 깜빡했습니다..)

![스크린샷 2023-12-08 오전 11.54.18.png](step2-2%20stateless%20app%20deploy%20808a798806a74fe2895c3c8f4de6247a/%25E1%2584%2589%25E1%2585%25B3%25E1%2584%258F%25E1%2585%25B3%25E1%2584%2585%25E1%2585%25B5%25E1%2586%25AB%25E1%2584%2589%25E1%2585%25A3%25E1%2586%25BA_2023-12-08_%25E1%2584%258B%25E1%2585%25A9%25E1%2584%258C%25E1%2585%25A5%25E1%2586%25AB_11.54.18.png)

→ ingress로 변경시 작동하는 것을 확인 하기 위해 ingress 편집 실시

```bash
kubectl edit ingress minimal-ingress

- http:
      paths:
      - backend:
          service:
            name: frontend
            port:
              number: 80
        path: /
        pathType: Prefix

```

→ ingress로 접속 실시

![스크린샷 2023-12-08 오후 12.04.23.png](step2-2%20stateless%20app%20deploy%20808a798806a74fe2895c3c8f4de6247a/%25E1%2584%2589%25E1%2585%25B3%25E1%2584%258F%25E1%2585%25B3%25E1%2584%2585%25E1%2585%25B5%25E1%2586%25AB%25E1%2584%2589%25E1%2585%25A3%25E1%2586%25BA_2023-12-08_%25E1%2584%258B%25E1%2585%25A9%25E1%2584%2592%25E1%2585%25AE_12.04.23.png)

→ ingress 접속가능 ( 하지만 NodePort로 해보는 것을 까먹었슴다!)

# scale up, down

```yaml
kubectl scale deployment frontend --replicas=5
deployment.apps/frontend scaled

kubectl get pod
NAME                               READY   STATUS    RESTARTS   AGE
frontend-86df6fd594-ldsmq          0/1     Pending   0          36s
frontend-86df6fd594-n4v2z          1/1     Running   0          15m
frontend-86df6fd594-w7dll          0/1     Pending   0          36s
frontend-86df6fd594-wd428          1/1     Running   0          15m
frontend-86df6fd594-xn5ml          1/1     Running   0          37s
redis-follower-6f6cd6cbdb-8trwn    1/1     Running   0          18h
redis-follower-6f6cd6cbdb-nm82j    1/1     Running   0          18h
redis-leader-58b566dc8b-x97wz      1/1     Running   0          18h
wordpress-6cccb69f77-gpqc6         1/1     Running   0          18h
wordpress-mysql-0                  1/1     Running   0          21h
wordpress-mysql-1                  1/1     Running   0          21h
wordpress-mysql-79f4b97879-x4b5x   1/1     Running   0          21h
```

→ 생성은 되었으나 알 수 없는 이유로 pending

→ 추후 해결할 예정입니다!!

```yaml
kubectl scale deployment frontend --replicas=3
deployment.apps/frontend scaled

kubectl get pods                              
NAME                               READY   STATUS    RESTARTS   AGE
frontend-86df6fd594-n4v2z          1/1     Running   0          18m
frontend-86df6fd594-wd428          1/1     Running   0          18m
frontend-86df6fd594-xn5ml          1/1     Running   0          4m26s
redis-follower-6f6cd6cbdb-8trwn    1/1     Running   0          18h
redis-follower-6f6cd6cbdb-nm82j    1/1     Running   0          18h
redis-leader-58b566dc8b-x97wz      1/1     Running   0          18h
wordpress-6cccb69f77-gpqc6         1/1     Running   0          18h
wordpress-mysql-0                  1/1     Running   0          21h
wordpress-mysql-1                  1/1     Running   0          21h
wordpress-mysql-79f4b97879-x4b5x   1/1     Running   0          21h
```

→ 다시 3개로 줄였습니다

# recreate, rollingUpdate

[Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

# Blue-green-deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
        app: guestbook
        tier: frontend
        version: v4
  template:
    metadata:
      labels:
        app: guestbook
        tier: frontend
        version: v4
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: affinity
                operator: In
                values:
                - test
      containers:
      - name: php-redis
        image: [us-docker.pkg.dev/google-samples/containers/gke/gb-frontend:v5](http://us-docker.pkg.dev/google-samples/containers/gke/gb-frontend:v5)
        env:
        - name: GET_HOSTS_FROM
          value: "dns"
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend2
spec:
  replicas: 2
  selector:
    matchLabels:
        app: guestbook
        tier: frontend
        version: v5
  template:
    metadata:
      labels:
        app: guestbook
        tier: frontend
        version: v5
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: affinity
                operator: DoesNotExist
      containers:
      - name: php-redis
        image: [us-docker.pkg.dev/google-samples/containers/gke/gb-frontend:v5](http://us-docker.pkg.dev/google-samples/containers/gke/gb-frontend:v5)
        env:
        - name: GET_HOSTS_FROM
          value: "dns"
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 80
```

## blue-select.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-load-balancer
  labels:
    app: guestbook
    tier: frontend
spec:
  ports:
    - port: 80
  selector:
    app: guestbook
    tier: frontend
    version: v4
  type: LoadBalancer
```

```yaml
kubectl get frontend-load-balancer
NAME                     TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
frontend-load-balancer   LoadBalancer   10.100.193.112   a30a6dfb1471f989f3a3269cfb42-1845485982.ap-northeast-2.elb.amazonaws.com   80:30385/TCP   81s
```

→ 다시 green-version select

```yaml
version: v4 
-> 
version: v5

kubectl get svc frontend-load-balancer -o wide 
NAME                     TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE   SELECTOR
frontend-load-balancer   LoadBalancer   10.100.193.112   a702694a6dfb1471f989f3a3269cfb42-1845485982.ap-northeast-2.elb.amazonaws.com   80:30385/TCP   16m   app=guestbook,tier=frontend,version=v5

# delete blue-version
kubectl delete deployment frontend
deployment.apps "frontend" deleted

```
