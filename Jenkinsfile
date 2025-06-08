pipeline {
    agent {
        kubernetes {
            cloud 'kubernetes'
            serviceAccount 'jenkins-agent'
            // --- YAML 块的缩进已被修正 ---
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: helm
    image: alpine/helm:3.14.2
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