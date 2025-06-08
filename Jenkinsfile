pipeline {
    agent none
    stages {
        // 第一个阶段：从 Git 检出代码
        stage('Checkout Source') {
            agent any
            steps {
                echo 'Checking out code...'
                checkout scm
            }
        }

        // 第二个阶段：部署到 Kubernetes
        stage('Deploy to Kubernetes') {
            agent {
                kubernetes {
                    // 定义这个临时 Pod 的配置
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
            steps {
                container('helm') {
                    withCredentials([
                        string(credentialsId: 'mariadb-password', variable: 'DB_PASS'),
                        string(credentialsId: 'redis-password',  variable: 'REDIS_PASS')
                    ]) {
                        echo 'Deploying CTFd chart with credentials...'
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