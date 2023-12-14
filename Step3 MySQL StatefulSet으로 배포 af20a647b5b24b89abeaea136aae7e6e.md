# Step3 MySQL StatefulSet으로 배포

# 참고자료

[https://kubernetes.io/ko/docs/tasks/run-application/run-replicated-stateful-application/](https://kubernetes.io/ko/docs/tasks/run-application/run-replicated-stateful-application/)

# 설정

---

# mysql-config.ymal

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  primary.cnf: |
    # Primary에만 이 구성을 적용한다.
    [mysqld]
    log-bin        
  replica.cnf: |
    # 레플리카에만 이 구성을 적용한다.
    [mysqld]
    super-read-only
```

# mysql-statefulset.yaml

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  selector:
    matchLabels:
      app: mysql
      app.kubernetes.io/name: mysql
  serviceName: mysql
  replicas: 3
  template:
    metadata:
      labels:
        app: mysql
        app.kubernetes.io/name: mysql
    spec:
      initContainers:
      - name: init-mysql
        image: mysql:5.7
        command:
        - bash
        - "-c"
        - |
          set -ex
          # 파드의 원래 인덱스에서 mysql server-id를 생성.
          [[ $HOSTNAME =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          echo [mysqld] > /mnt/conf.d/server-id.cnf
          # 예약된 server-id=0 값을 피하기 위해 오프셋 추가.
          echo server-id=$((100 + $ordinal)) >> /mnt/conf.d/server-id.cnf
          # config-map에서 emptyDir로 적당한 conf.d 파일들을 복사.
          if [[ $ordinal -eq 0 ]]; then
            cp /mnt/config-map/primary.cnf /mnt/conf.d/
          else
            cp /mnt/config-map/replica.cnf /mnt/conf.d/
          fi          
        volumeMounts:
        - name: conf
          mountPath: /mnt/conf.d
        - name: config-map
          mountPath: /mnt/config-map
      - name: clone-mysql
        image: gcr.io/google-samples/xtrabackup:1.0
        command:
        - bash
        - "-c"
        - |
          set -ex
          # 데이터가 이미 존재하면 복제 생략. 
          [[ -d /var/lib/mysql/mysql ]] && exit 0
          # Primary에 복제 생략(ordinal index 0).
          [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          [[ $ordinal -eq 0 ]] && exit 0
          # 이전 피어(peer)에서 데이터 복제.
          ncat --recv-only mysql-$(($ordinal-1)).mysql 3307 | xbstream -x -C /var/lib/mysql
          # 백업 준비.
          xtrabackup --prepare --target-dir=/var/lib/mysql          
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
      containers:
      - name: mysql
        image: mysql:5.7
        env:
        - name: MYSQL_ALLOW_EMPTY_PASSWORD
          value: "1"
        ports:
        - name: mysql
          containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 100m # 변경된 CPU 요청 값
            memory: 256Mi
          limits:
            cpu: 200m # 변경된 CPU 제한 값
            memory: 512Mi
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            # TCP 상에서 쿼리를 실행할 수 있는지 확인(skip-networking은 off).
            command: ["mysql", "-h", "127.0.0.1", "-e", "SELECT 1"]
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
      - name: xtrabackup
        image: gcr.io/google-samples/xtrabackup:1.0
        ports:
        - name: xtrabackup
          containerPort: 3307
        command:
        - bash
        - "-c"
        - |
          set -ex
          cd /var/lib/mysql

          # 복제된 데이터의 binlog 위치를 확인.
          if [[ -f xtrabackup_slave_info && "x$(<xtrabackup_slave_info)" != "x" ]]; then
            # XtraBackup은 기존 레플리카에서 복제하기 때문에
            # 일부 "CHANGE MASTER TO" 쿼리는 이미 생성했음. (테일링 세미콜론을 제거해야 한다!)
            cat xtrabackup_slave_info | sed -E 's/;$//g' > change_master_to.sql.in
            # 이 경우에는 xtrabackup_binlog_info는 무시(필요없음).
            rm -f xtrabackup_slave_info xtrabackup_binlog_info
          elif [[ -f xtrabackup_binlog_info ]]; then
            # Primary로부터 직접 복제함. binlog 위치를 파싱.
            [[ `cat xtrabackup_binlog_info` =~ ^(.*?)[[:space:]]+(.*?)$ ]] || exit 1
            rm -f xtrabackup_binlog_info xtrabackup_slave_info
            echo "CHANGE MASTER TO MASTER_LOG_FILE='${BASH_REMATCH[1]}',\
                  MASTER_LOG_POS=${BASH_REMATCH[2]}" > change_master_to.sql.in
          fi

          # Replication을 시작하여 복제를 완료해야 하는지 확인.
          if [[ -f change_master_to.sql.in ]]; then
            echo "Waiting for mysqld to be ready (accepting connections)"
            until mysql -h 127.0.0.1 -e "SELECT 1"; do sleep 1; done

            echo "Initializing replication from clone position"
            mysql -h 127.0.0.1 \
                  -e "$(<change_master_to.sql.in), \
                          MASTER_HOST='mysql-0.mysql', \
                          MASTER_USER='root', \
                          MASTER_PASSWORD='', \
                          MASTER_CONNECT_RETRY=10; \
                        START SLAVE;" || exit 1
            # 컨테이너가 다시 시작하는 경우, 이 작업을 한번만 시도한다.
            mv change_master_to.sql.in change_master_to.sql.orig
          fi

          # 피어가 요청할 때 서버를 시작하여 백업을 보냄.
          exec ncat --listen --keep-open --send-only --max-conns=1 3307 -c \
            "xtrabackup --backup --slave-info --stream=xbstream --host=127.0.0.1 --user=root"          
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
      volumes:
      - name: conf
        emptyDir: {}
      - name: config-map
        configMap:
          name: mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi

---
# 스테이트풀셋 멤버의 안정적인 DNS 엔트리를 위한 헤드리스 서비스.
apiVersion: v1
kind: Service
metadata:
  name: mysql
  labels:
    app: mysql
    app.kubernetes.io/name: mysql
spec:
  ports:
  - name: mysql
    port: 3306
  clusterIP: None
  selector:
    app: mysql
---
# 읽기용 MySQL 인스턴스에 연결하기 위한 클라이언트 서비스.
# 쓰기용은 Primary인 mysql-0.mysql에 대신 연결해야 한다.
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
  labels:
    app: mysql
    app.kubernetes.io/name: mysql
    readonly: "true"
spec:
  ports:
  - name: mysql
    port: 3306
  selector:
    app: mysql
```

---

### 생성 및 결과

```yaml
k apply -f mysql-statefulset.yaml
k get sts,po,pv,pvc,svc,ep
```

![Untitled](Step3%20MySQL%20StatefulSet%E1%84%8B%E1%85%B3%E1%84%85%E1%85%A9%20%E1%84%87%E1%85%A2%E1%84%91%E1%85%A9%20af20a647b5b24b89abeaea136aae7e6e/Untitled.png)

---

### mysql 접속

```yaml
kubectl run nettool -it --image ghcr.io/c1t1d0s7/network-multitool --rm

>host mysql
>mysql -h mysql-0.mysql -u root
```

![Untitled](Step3%20MySQL%20StatefulSet%E1%84%8B%E1%85%B3%E1%84%85%E1%85%A9%20%E1%84%87%E1%85%A2%E1%84%91%E1%85%A9%20af20a647b5b24b89abeaea136aae7e6e/Untitled%201.png)

---

### DB 편집

![Untitled](Step3%20MySQL%20StatefulSet%E1%84%8B%E1%85%B3%E1%84%85%E1%85%A9%20%E1%84%87%E1%85%A2%E1%84%91%E1%85%A9%20af20a647b5b24b89abeaea136aae7e6e/Untitled%202.png)