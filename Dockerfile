FROM amazon/aws-lambda-nodejs:20-x86_64 as base
COPY src/ ${LAMBDA_TASK_ROOT}/src/
CMD [ "src/index.handler" ] 