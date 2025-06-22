
pipeline {
    agent any

    stages {
        stage('Source') {
            steps {
                echo 'Clonando el repositorio...'
                sh 'git clone https://github.com/JoseGo/unir-test-act2.git'
            }
        }
        stage('Build') {
            steps {
                echo 'Ejecutando make build dentro de WSL...'
                sh 'wsl make build'
            }
        }
        stage('Unit tests') {
            steps {
                echo 'Ejecutando pruebas unitarias dentro de WSL...'
                sh 'wsl make test-unit'
                archiveArtifacts artifacts: 'results/*.xml'
            }
        }
        stage('API tests') {
            steps {
                echo 'Ejecutando pruebas de API dentro de WSL...'
                sh 'wsl make test-api'
                archiveArtifacts artifacts: 'results/*.xml'
            }
        }
        stage('E2E tests') {
            steps {
                echo 'Ejecutando pruebas end-to-end dentro de WSL...'
                sh 'wsl make test-e2e'
                archiveArtifacts artifacts: 'results/*.xml'
            }
        }
    }

    post {
        always {
            echo 'Publicando resultados y limpiando workspace...'
            junit allowEmptyResults: true, testResults: 'results/*_result.xml'
        }
        failure {
            echo 'El build falló. se envía correo de notificación.'
        }
    }
}

