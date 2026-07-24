#!/bin/bash
# Consolidated AWS resource audit for proj1-vpc
# Run from anywhere with AWS CLI configured. Outputs one file: aws-audit-output.txt

OUT="aws-audit-output.txt"
VPC_ID="vpc-01bfe876108cc219b"

echo "=== AUDIT RUN: $(date) ===" > $OUT

echo -e "\n\n########## VPC ##########" >> $OUT
aws ec2 describe-vpcs --vpc-ids $VPC_ID \
  --query "Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,DnsSupport:EnableDnsSupport,DnsHostnames:EnableDnsHostnames}" \
  --output table >> $OUT

echo -e "\n\n########## SUBNETS ##########" >> $OUT
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[].{Name:Tags[?Key=='Name'].Value|[0],SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,AutoPublicIP:MapPublicIpOnLaunch}" \
  --output table >> $OUT

echo -e "\n\n########## INTERNET GATEWAY ##########" >> $OUT
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query "InternetGateways[].{IgwId:InternetGatewayId,State:Attachments[0].State}" \
  --output table >> $OUT

echo -e "\n\n########## NAT GATEWAYS ##########" >> $OUT
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" \
  --query "NatGateways[].{ID:NatGatewayId,State:State,Subnet:SubnetId,PublicIP:NatGatewayAddresses[0].PublicIp}" \
  --output table >> $OUT

echo -e "\n\n########## ROUTE TABLES + ROUTES ##########" >> $OUT
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[].{Name:Tags[?Key=='Name'].Value|[0],RouteTableId:RouteTableId,Routes:Routes[].{Dest:DestinationCidrBlock,Target:join(\` \`,[GatewayId,NatGatewayId][?@!=null])},Associations:Associations[].SubnetId}" \
  --output json >> $OUT

echo -e "\n\n########## SECURITY GROUPS + RULES ##########" >> $OUT
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[].{Name:GroupName,GroupId:GroupId,Inbound:IpPermissions[].{Port:FromPort,Proto:IpProtocol,SourceSG:UserIdGroupPairs[0].GroupId,SourceCIDR:IpRanges[0].CidrIp}}" \
  --output json >> $OUT

echo -e "\n\n########## EC2 INSTANCES (all, with SG + subnet) ##########" >> $OUT
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name'].Value|[0],InstanceId:InstanceId,State:State.Name,Type:InstanceType,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,Subnet:SubnetId,SG:SecurityGroups[0].GroupName,KeyName:KeyName,IAMProfile:IamInstanceProfile.Arn}" \
  --output table >> $OUT

echo -e "\n\n########## AUTO SCALING GROUP ##########" >> $OUT
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names proj1-app-asg \
  --query "AutoScalingGroups[].{Name:AutoScalingGroupName,Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,HealthCheckType:HealthCheckType,GracePeriod:HealthCheckGracePeriod,Subnets:VPCZoneIdentifier,Instances:Instances[].{ID:InstanceId,AZ:AvailabilityZone,Health:HealthStatus,LifecycleState:LifecycleState}}" \
  --output json >> $OUT

echo -e "\n\n########## LAUNCH TEMPLATE VERSIONS ##########" >> $OUT
aws ec2 describe-launch-template-versions --launch-template-name proj1-app-template \
  --query "LaunchTemplateVersions[].{Version:VersionNumber,Default:DefaultVersion,Description:VersionDescription,InstanceType:LaunchTemplateData.InstanceType,SG:LaunchTemplateData.SecurityGroupIds}" \
  --output table >> $OUT

echo -e "\n\n########## LOAD BALANCER ##########" >> $OUT
aws elbv2 describe-load-balancers --names proj1-alb \
  --query "LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,Scheme:Scheme,Subnets:AvailabilityZones[].SubnetId,SG:SecurityGroups}" \
  --output table >> $OUT

echo -e "\n\n########## TARGET GROUP + HEALTH ##########" >> $OUT
TG_ARN=$(aws elbv2 describe-target-groups --names proj1-app-tg --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 describe-target-groups --target-group-arns $TG_ARN \
  --query "TargetGroups[].{Name:TargetGroupName,Protocol:Protocol,Port:Port,HealthCheckPath:HealthCheckPath,Interval:HealthCheckIntervalSeconds,HealthyThreshold:HealthyThresholdCount,UnhealthyThreshold:UnhealthyThresholdCount}" \
  --output table >> $OUT
aws elbv2 describe-target-health --target-group-arn $TG_ARN \
  --query "TargetHealthDescriptions[].{InstanceId:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}" \
  --output table >> $OUT

echo -e "\n\n########## CLOUDWATCH ALARMS ##########" >> $OUT
aws cloudwatch describe-alarms --alarm-name-prefix "proj1-" \
  --query "MetricAlarms[].{Name:AlarmName,Metric:MetricName,Threshold:Threshold,State:StateValue,ActionsEnabled:ActionsEnabled,AlarmActions:AlarmActions}" \
  --output table >> $OUT

echo -e "\n\n########## ELASTIC IPs ##########" >> $OUT
aws ec2 describe-addresses \
  --query "Addresses[].{PublicIP:PublicIp,AllocationId:AllocationId,InstanceId:InstanceId,AssociationId:AssociationId}" \
  --output table >> $OUT

echo -e "\n\n########## IAM INSTANCE PROFILES (SSM-related) ##########" >> $OUT
aws iam list-instance-profiles \
  --query "InstanceProfiles[].{Name:InstanceProfileName,Roles:Roles[].RoleName}" \
  --output table >> $OUT

echo -e "\n\nDONE. Review $OUT and share it back."
