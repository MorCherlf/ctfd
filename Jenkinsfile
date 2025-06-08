pipeline {
    // 在顶层定义 agent，让整个流水线运行在一个动态创建的 K8s Pod 中
    agent {
        kubernetes {
            cloud 'kubernetes'
            serviceAccount 'jenkins-agent'
            yaml '''
            apiVersion: v1
            kind: Pod
            spec:
            containers:
            - name: helm
                image: alpine/helm:3.14.2 # 一个包含了 helm 和 kubectl 工具的 Docker 镜像
                command:
                - cat
                tty: true
            '''
        }
    }

    stages {
        stage('Checkout and Deploy') {
            steps {
                container('helm') {
                    echo 'Checking out source code...'
                    checkout scm

                    echo 'Deploying CTFd chart with credentials...'
                    // 使用 withCredentials 来安全地加载密码
                    withCredentials([
                        string(credentialsId: 'mariadb-password', variable: 'DB_PASS'),
                        string(credentialsId: 'redis-password',  variable: 'REDIS_PASS')
                    ]) {
                        sh """
                        helm upgrade ctfd-service ./ctfd-chart/ --install --namespace ctfd \\
                          --set ctfdConfig.databaseUrl="mysql+pymysql://ctfd:${DB_PASS}@mariadb.ctfd:3306/ctfd" \\
                          --set ctfdConfig.redisUrl="redis://:${REDIS_PASS}@redis-master.ctfd:6379"
                        """
                    }
                }
            }
        }
    }
}