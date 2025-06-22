pipeline {
    agent {
        label 'docker'
    }
    stages {
        stage('Source') {
            steps {
                echo 'Clonando el repositorio...'
                git 'https://github.com/JoseGo/unir-test-act2.git'
            }
        }
        stage('Build') {
            steps {
                echo 'Ejecutando make build...'
                sh 'make build'
            }
        }
        stage('Unit tests') {
            steps {
                echo 'Ejecutando pruebas unitarias...'
                sh 'make test-unit'
                archiveArtifacts artifacts: 'results/*.xml'
            }
        }
        stage('API tests') {
            steps {
                echo 'Ejecutando pruebas de API...'
                sh 'make test-api'
                archiveArtifacts artifacts: 'results/*.xml'
            }
        }
        stage('E2E tests') {
            steps {
                echo 'Ejecutando pruebas end-to-end...'
                sh 'make test-e2e'
                archiveArtifacts artifacts: 'results/*.xml'
            }
        }
    }
    post {
        always {
            echo 'Publicando resultados y limpiando workspace...'
            junit 'results/*_result.xml'
            cleanWs()
        }
        failure {
            echo 'La build falló. Aquí podrías simular un correo de notificación.'
        }
    }
}
