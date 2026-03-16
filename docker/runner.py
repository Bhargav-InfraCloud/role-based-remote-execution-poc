import boto3
import time
import os

def main():
    region = os.environ.get('AWS_REGION', 'us-east-2')
    ami_id = os.environ.get('AMI_ID', 'ami-00399ec92321828f5') # Amazon Linux 2 AMI for Ubuntu 20.04 for us-east-2
    instance_type = os.environ.get('INSTANCE_TYPE', 't2.micro')
    wait_seconds = int(os.environ.get('WAIT_SECONDS', '60'))

    subnet_id = os.environ.get('SUBNET_ID')
    security_group_id = os.environ.get('SECURITY_GROUP_ID')
    print(f"SUBNET_ID: '{subnet_id}'")
    print(f"SECURITY_GROUP_ID: '{security_group_id}'")
    if not subnet_id or not security_group_id:
        raise Exception('SUBNET_ID and SECURITY_GROUP_ID environment variables must be set')
    ec2 = boto3.client('ec2', region_name=region)
    print('Launching EC2 instance...')
    resp = ec2.run_instances(
        ImageId=ami_id,
        InstanceType=instance_type,
        MinCount=1,
        MaxCount=1,
        SubnetId=subnet_id,
        SecurityGroupIds=[security_group_id]
    )
    instance_id = resp['Instances'][0]['InstanceId']
    print(f'Launched instance: {instance_id}')

    print(f'Waiting {wait_seconds} seconds...')
    time.sleep(wait_seconds)

    print('Terminating instance...')
    ec2.terminate_instances(InstanceIds=[instance_id])
    print('Terminated.')

if __name__ == '__main__':
    main()
