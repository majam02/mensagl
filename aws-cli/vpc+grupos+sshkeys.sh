#!/bin/bash
#
# Mario Aja Moral

# The name of the user for lab
printf "%s" "Insert personal name: "
read ALUMNO


###########################################################################################################
###########################                      V P C                          ###########################
###########################################################################################################
export EDITOR=true

# VPC Variables
VPC_NAME="vpc-mensagl-2025-${ALUMNO}"
REGION="us-east-1"
AVAILABILITY_ZONE1="${REGION}a"
AVAILABILITY_ZONE2="${REGION}b"
DESCRIPTION="Mensagl Security groups"
MY_IP="0.0.0.0/0"

# Create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block "10.201.0.0/16" --instance-tenancy "default" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_NAME}-vpc}]" \
  --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Public Subnet 1
SUBNET_PUBLIC1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.201.1.0/24" \
  --availability-zone $AVAILABILITY_ZONE1 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-public1-${AVAILABILITY_ZONE1}}]" \
  --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC1 --map-public-ip-on-launch

# Public Subnet 2
SUBNET_PUBLIC2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.201.2.0/24" \
  --availability-zone $AVAILABILITY_ZONE2 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-public2-${AVAILABILITY_ZONE2}}]" \
  --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC2 --map-public-ip-on-launch

# Private Subnet 1
SUBNET_PRIVATE1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.201.3.0/24" \
  --availability-zone $AVAILABILITY_ZONE1 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-private1-${AVAILABILITY_ZONE1}}]" \
  --query 'Subnet.SubnetId' --output text)

# Private Subnet 2
SUBNET_PRIVATE2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.201.4.0/24" \
  --availability-zone $AVAILABILITY_ZONE2 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-private2-${AVAILABILITY_ZONE2}}]" \
  --query 'Subnet.SubnetId' --output text)




# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_NAME}-igw}]" \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Create public route table
RTB_PUBLIC=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-public}]" \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PUBLIC --destination-cidr-block "0.0.0.0/0" --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_PUBLIC1
aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_PUBLIC2

# Create Elastic IP and NAT Gateway
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
NATGW_ID=$(aws ec2 create-nat-gateway --subnet-id $SUBNET_PUBLIC1 --allocation-id $EIP_ALLOC_ID \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${VPC_NAME}-nat-public1-${AVAILABILITY_ZONE1}}]" \
  --query 'NatGateway.NatGatewayId' --output text)

# Wait for NAT Gateway
aws ec2 wait nat-gateway-available --nat-gateway-ids $NATGW_ID

# Create private route table and associate both private subnets
RTB_PRIVATE=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-private}]" \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PRIVATE --destination-cidr-block "0.0.0.0/0" --nat-gateway-id $NATGW_ID
aws ec2 associate-route-table --route-table-id $RTB_PRIVATE --subnet-id $SUBNET_PRIVATE1
aws ec2 associate-route-table --route-table-id $RTB_PRIVATE --subnet-id $SUBNET_PRIVATE2

echo "VPC Created !"




###########################################################################################################
########################                    SECURITY GROUPS                        ########################
###########################################################################################################

# Security group PROXYS
SG_ID_PROXY=$(aws ec2 create-security-group \
  --group-name "Proxy-inverso" \
  --description "$DESCRIPTION" --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value="Proxy-inverso"}]" \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 22 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 80 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 443 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol udp --port 10000 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 5269 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 4443 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 5281 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 5280 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 5347 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 5222 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 12345 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_PROXY --protocol tcp --port 3306 --cidr $MY_IP





# Security group XMPP
SG_ID_XMPP=$(aws ec2 create-security-group \
  --group-name "Servidor-Mensajeria" \
  --description "$DESCRIPTION" --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value="Servidor-Mensajeria"}]" \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 1000 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 5269 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 5270 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 4443 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 5281 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 5280 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 5347 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 5222 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 80 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 443 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 22 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 12345 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol tcp --port 3306 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_XMPP --protocol -1 --source-group $SG_ID_PROXY


# Security group MYSQL
SG_ID_MYSQL=$(aws ec2 create-security-group \
  --group-name "Servidor-SGBD" \
  --description "$DESCRIPTION" --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value="Servidor-SGBD"}]" \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ID_MYSQL --protocol tcp --port 22 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_MYSQL --protocol tcp --port 3306 --cidr $MY_IP




# Security group WORDPRESS
SG_ID_WORDPRESS=$(aws ec2 create-security-group \
  --group-name "Servidor-ticketing" \
  --description "$DESCRIPTION" --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value="Servidor-ticketing"}]" \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ID_WORDPRESS --protocol tcp --port 22 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_WORDPRESS --protocol tcp --port 80 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_WORDPRESS --protocol tcp --port 443 --cidr $MY_IP
aws ec2 authorize-security-group-ingress --group-id $SG_ID_WORDPRESS --protocol -1 --source-group $SG_ID_PROXY


echo "Sec Groups Created !";



###########################################################################################################
#########################                      KEYS SSH                          ##########################
###########################################################################################################

# Key pair SSH
KEY_NAME="ssh-mensagl-2025-${ALUMNO}"

aws ec2 create-key-pair \
  --key-name "${KEY_NAME}" \
  --query "KeyMaterial" \
  --output text > ${KEY_NAME}.pem

echo "SSH KEYS !";
