pipeline {
    agent any
    
    parameters {
        string(name: 'MODEL_VERSION', defaultValue: 'latest', description: 'Version tag of the model to test')
        choice(name: 'EVAL_TYPE', choices: ['all', 'standard', 'custom'], description: 'Type of evaluations to run')
    }
    
    environment {
        // Define credentials (manage these in Jenkins)
        AI_API_KEY = credentials('ai-api-key')
        MODEL_BASE_URL = credentials('model-base-url')
        // Container image name (update to your registry)
        CONTAINER_IMAGE = "ghcr.io/alexbrooker/pre_flight:latest"
    }
    
    stages {
        stage('Prepare') {
            steps {
                // Create directory for results
                sh '''
                    mkdir -p ${WORKSPACE}/eval-results
                    chmod 777 ${WORKSPACE}/eval-results
                '''
            }
        }
        
        stage('Run Pre-Flight Evaluations') {
            steps {
                sh '''
                    docker pull ${CONTAINER_IMAGE}
                    
                    docker run --rm \
                      -e API_KEY=${AI_API_KEY} \
                      -e MODEL_BASE_URL=${MODEL_BASE_URL} \
                      -e MODEL_NAME=${params.MODEL_VERSION} \
                      -e EVAL_TYPE=${params.EVAL_TYPE} \
                      -e TEMPERATURE=0.0 \
                      -e MAX_TOKENS=2048 \
                      -v ${WORKSPACE}/eval-results:/app/results \
                      ${CONTAINER_IMAGE}
                '''
            }
        }
        
        stage('Process Results') {
            steps {
                // Parse and display summary
                sh '''
                    echo "Evaluation Results Summary:"
                    cat ${WORKSPACE}/eval-results/summary.json
                    
                    # Check if any tests failed
                    if grep -q '"status": "failed"' ${WORKSPACE}/eval-results/*.json 2>/dev/null; then
                      echo "Some tests failed!"
                      # Optionally fail the build
                      # exit 1
                    else
                      echo "All tests passed!"
                    fi
                '''
                
                // Archive the results
                archiveArtifacts artifacts: 'eval-results/**/*', fingerprint: true
            }
        }
    }
    
    post {
        always {
            // Clean up
            sh 'docker system prune -f || true'
        }
        success {
            echo 'AI Model Pre-Flight evaluation completed successfully!'
        }
        failure {
            echo 'AI Model Pre-Flight evaluation failed!'
        }
    }
}