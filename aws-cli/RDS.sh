#!/bin/bash
#
# Mario Aja Moral

# Variables for RDS
RDS_INSTANCE_ID="wordpress-db"
printf "%s" "RDS Wordpress Database: "
read wDBName
printf "%s" "RDS & MySQL XMPP Username: "
read DB_USERNAME
printf "%s" "RDS & MySQL XMPP Password: "
read DB_PASSWORD


printf "%s" "VPC ID: "
read SUBNET_PRIVATE1
printf "%s" "Subnet Priv 1: "
read SUBNET_PRIVATE1
printf "%s" "Subnet Priv 2: "
read SUBNET_PRIVATE2

REGION="us-east-1"
AVAILABILITY_ZONE="${REGION}a"


########################################################################
#######################     RDS MYSQL INSTANCE     #####################
########################################################################

# RDS Subnet Group
aws rds create-db-subnet-group \
    --db-subnet-group-name wp-rds-subnet-group \
    --db-subnet-group-description "RDS Subnet Group for WordPress" \
    --subnet-ids "$SUBNET_PRIVATE1" "$SUBNET_PRIVATE2"

# Security Group RDS
SG_ID_RDS=$(aws ec2 create-security-group \
  --group-name "RDS-MySQL" \
  --description "Security group for RDS MySQL" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG_ID_RDS" --protocol tcp --port 3306 --cidr 0.0.0.0/0

# RDS Instance
aws rds create-db-instance \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --allocated-storage 20 \
    --storage-type gp2 \
    --master-username "$DB_USERNAME" \
    --master-user-password "$DB_PASSWORD" \
    --db-subnet-group-name wp-rds-subnet-group \
    --vpc-security-group-ids "$SG_ID_RDS" \
    --backup-retention-period 7 \
    --no-publicly-accessible \
    --region "$REGION" \
    --availability-zone "$AVAILABILITY_ZONE1" \
    --no-multi-az  # Ensures Single-AZ deployment

# Wait RDS
echo "Waiting for RDS (~10 minutes)..."
aws rds wait db-instance-available --db-instance-identifier "$RDS_INSTANCE_ID"

# RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE_ID" \
  --query 'DBInstances[0].Endpoint.Address' --output text)
echo "RDS Endpoint: $RDS_ENDPOINT"