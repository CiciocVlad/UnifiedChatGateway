def WEB_HOOK_URL = 'https://premiercontactpoint.webhook.office.com/webhookb2/a3b9ea59-90b6-43d9-b4a3-2298beed9285@c55a2769-2c61-48f8-b87e-bdb617956b54/JenkinsCI/da9db3709b4d4acda2b24928d410a238/a55c64c2-8f0e-4342-aed0-b64e766a1aae'
def DOCKER_REGISTRY = "registry.premiercontactpoint.dev"

pipeline {
  agent {
    label 'docker_new'
  }
  environment {
    // Necessary to enable Docker buildkit features such as --ssh
    DOCKER_BUILDKIT = "1"
  }
  stages {
    stage('Prep') {
      steps {
        echo 'Prep'
      }
    }
    stage('Git') {
      steps {
        //Clean up the workspace
        step([$class: 'WsCleanup'])
        //Chckout
        checkout scm
      }
    }
    stage('Build') {
      parallel {
        stage('Build Tag') {
          when {
            buildingTag()
          }
          steps {
            script {
              sh 'export APP_VSN=1.0.0'
              echo 'Building..'
              docker.withRegistry('https://062186273248.dkr.ecr.ap-southeast-2.amazonaws.com', 'ecr:ap-southeast-2:AWS ECR') {
                sshagent(['new_deployment_key']) {
                  def image = docker.build("unified-chat-gateway:${env.TAG_NAME}", '-f ./Dockerfile --no-cache --ssh default .')
                  image.push()
                }
              }
            }
          }
        }
        stage('Build Branches') {
          when {
            anyOf {
              branch 'master'
              branch 'develop'
              branch 'deploy'
            }
          }
          steps {
            sh 'export APP_VSN=1.0.0'
            echo 'Building..'
            script {
              docker.withRegistry("https://${DOCKER_REGISTRY}") {
                sshagent(['new_deployment_key']) {
                  def image = docker.build("unified-chat-gateway:${env.BRANCH_NAME}", '-f ./Dockerfile --no-cache --ssh default .')
                  image.push()
                }
              }
            }
          }
        }
      }
    }
    stage('Test') {
      steps {
        echo 'Testing..'
      }
    }

    stage('Deploy') {
      parallel {
        stage('Deploy') {
          when {
            branch 'deploy'
          }
          steps {
            script {
              office365ConnectorSend message: 'Starting an Unified Chat Gateway deployment into master.dev', webhookUrl: "${WEB_HOOK_URL}"
              docker.withRegistry("https://${DOCKER_REGISTRY}") {
                sh "ssh -o StrictHostKeyChecking=no -l jenkins 10.3.65.99 \"docker stop unified-chat-gateway-deploy || true\""
                sh "ssh -o StrictHostKeyChecking=no -l jenkins 10.3.65.99 \"docker rm unified-chat-gateway-deploy || true\""
                sh "ssh -o StrictHostKeyChecking=no -l jenkins 10.3.65.99 \"docker rmi -f ${DOCKER_REGISTRY}/unified-chat-gateway:deploy || true\""
                sh "ssh -o StrictHostKeyChecking=no -l jenkins 10.3.65.99 \"docker run -d -it --name unified-chat-gateway-deploy --restart always --network=host -v /opt/unified-chat-gateway/etc/:/opt/unified-chat-gateway/etc/ -v /opt/unified-chat-gateway/log/:/opt/unified-chat-gateway/log/:z -v /opt/unified-chat-gateway/vm.args:/opt/unified-chat-gateway/vm.args ${DOCKER_REGISTRY}/unified-chat-gateway:deploy\""
              }

              office365ConnectorSend message: 'Unified Chat Gateway has deployed into master.dev', status:'Done', webhookUrl: "${WEB_HOOK_URL}"
            }
          }
        }
      }
    }
  }
}
