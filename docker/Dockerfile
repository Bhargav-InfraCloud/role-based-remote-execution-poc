FROM public.ecr.aws/aws-cli/aws-cli:latest

RUN yum install -y python3-pip && pip3 install boto3

WORKDIR /app

COPY runner.py /app/runner.py

ENTRYPOINT ["python3", "/app/runner.py"]
