# devops

구름 쿠버네티스 
semi-project

step 0
  - 'Terraform을 사용하여 EKS 클러스터 구성하기

step 1
  - 'Stateful 애플리케이션 배포하기'
  - k8s 클러스터를 생성하고 볼륨 컨트롤러를 설정한 후 위의 튜토리얼을 진행합니다.

step 2-1
  -   Step1에서 생성한 Wordpress App에 아래 조건들을 만족할 수 있도록 기능을 추가
  -   WordPress App
    - Deployment로 배포
    - resource,livenessProbe를 정의
    - HPA를 설정하여 Autoscailing
    - Serviece와 ingress로 클러스터 외부로 노출

step 2-2 
  - stateless app 배포하기
    - 디플로이먼트로 배포
    - scale up, down 해보기
    - 특정 노드에 고정하여 배포하기
    - NodePort, Port-forward로 노출하여 접근하기
    - Recreate, ROllingUpdate 이해하고 BlueGreen배포 구현하기
   
step 3
  - Step 1과 별도로 MySql을 statefullset으로 배포
    - Statefulset으로 배포
    - replicas는 2이상으로 정의
    - resources, livenesProbe를 정의
    - Secret을 생성하여 root 패스워드 설정
    - PVC를 이용하여 스토리지 연결
    - Headless 서비스를 생성하여 앱과 연결

