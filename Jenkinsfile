pipeline {
    agent any

    environment {
        DOCKER_IMAGE     = "sachin19102001/crm-panel"
        AWS_REGION       = "ap-south-1"
        EB_APP_NAME      = "crm-panel"
        EB_ENV_NAME      = "Crm-panel-env"
        SHORT_SHA        = "${GIT_COMMIT[0..6]}"
    }

    stages {

        // ── 1. Checkout ──────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                echo "Branch: ${env.BRANCH_NAME}"
                echo "Commit: ${env.GIT_COMMIT}"
            }
        }

        // ── 2. Trivy Code Scan ───────────────────────────
        stage('Code Scan (Trivy)') {
            steps {
                sh '''
                    # Install Trivy if not present
                    if ! command -v trivy &> /dev/null; then
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                    fi

                    echo "Running Trivy filesystem scan..."
                    trivy fs . \
                        --severity CRITICAL,HIGH \
                        --exit-code 0 \
                        --format table
                '''
            }
        }

        // ── 3. Docker Build (for scanning) ───────────────
        stage('Docker Build') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE}:${SHORT_SHA} ."
                echo "Built image: ${DOCKER_IMAGE}:${SHORT_SHA}"
            }
        }

        // ── 4. Trivy Image Scan ──────────────────────────
        stage('Image Scan (Trivy)') {
            steps {
                sh '''
                    echo "Running Trivy image scan..."
                    trivy image \
                        --severity CRITICAL \
                        --exit-code 1 \
                        --ignore-unfixed \
                        --vuln-type os,library \
                        --format table \
                        ''' + "${DOCKER_IMAGE}:${SHORT_SHA}"
            }
        }

        // ── 5. Push to Docker Hub ────────────────────────
        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                        docker tag ${DOCKER_IMAGE}:${SHORT_SHA} ${DOCKER_IMAGE}:latest
                        docker push ${DOCKER_IMAGE}:${SHORT_SHA}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout
                    '''
                }
            }
        }

        // ── 6. Generate Dockerrun.aws.json ───────────────
        stage('Generate Dockerrun.aws.json') {
            steps {
                sh '''
                    cat > Dockerrun.aws.json << DOCKERRUN
                    {
                      "AWSEBDockerrunVersion": "1",
                      "Image": {
                        "Name": "${DOCKER_IMAGE}:${SHORT_SHA}",
                        "Update": "true"
                      },
                      "Ports": [
                        {
                          "ContainerPort": "3005",
                          "HostPort": "80"
                        }
                      ]
                    }
                    DOCKERRUN
                    cat Dockerrun.aws.json
                '''
            }
        }

        // ── 7. Zip deployment package ────────────────────
        stage('Zip Package') {
            steps {
                sh 'zip deploy.zip Dockerrun.aws.json'
            }
        }

        // ── 8. Deploy to AWS Elastic Beanstalk ───────────
        stage('Deploy to AWS Elastic Beanstalk') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id',     secretText: env.AWS_ACCESS_KEY_ID),
                    string(credentialsId: 'aws-secret-access-key', secretText: env.AWS_SECRET_ACCESS_KEY)
                ]) {
                    sh '''
                        # Install AWS CLI if not present
                        if ! command -v aws &> /dev/null; then
                            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                            unzip -q awscliv2.zip
                            ./aws/install
                        fi

                        # Configure AWS credentials
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        export AWS_DEFAULT_REGION=$AWS_REGION

                        VERSION_LABEL="${SHORT_SHA}-${BUILD_NUMBER}"

                        # Upload to S3
                        BUCKET=$(aws elasticbeanstalk create-storage-location --query S3Bucket --output text)
                        aws s3 cp deploy.zip s3://$BUCKET/$EB_APP_NAME/$VERSION_LABEL.zip

                        # Create new application version
                        aws elasticbeanstalk create-application-version \
                            --application-name $EB_APP_NAME \
                            --version-label $VERSION_LABEL \
                            --source-bundle S3Bucket=$BUCKET,S3Key=$EB_APP_NAME/$VERSION_LABEL.zip \
                            --region $AWS_REGION

                        # Deploy to environment
                        aws elasticbeanstalk update-environment \
                            --application-name $EB_APP_NAME \
                            --environment-name $EB_ENV_NAME \
                            --version-label $VERSION_LABEL \
                            --region $AWS_REGION

                        echo "Deployment triggered for version: $VERSION_LABEL"
                    '''
                }
            }
        }
    }

    // ── Post actions ─────────────────────────────────────
    post {
        success {
            echo '✅ Pipeline succeeded! CRM Panel deployed to AWS Elastic Beanstalk.'
        }
        failure {
            echo '❌ Pipeline failed! Check logs above.'
        }
        always {
            // Clean up local Docker images
            sh "docker rmi ${DOCKER_IMAGE}:${SHORT_SHA} || true"
            sh "docker rmi ${DOCKER_IMAGE}:latest || true"
            cleanWs()
        }
    }
}