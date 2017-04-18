#!/bin/sh

awsInstanceTagName='ska-mvup'

osFlavor='ubuntu' # amazon rhel ubuntu
awsSSHUser='ubuntu'
awsRegionName='us-west-2'
awsPrivateKeyName='amazonaws_rsa'
awsPrivateKeyPath="~/.ssh/$awsPrivateKeyName"

# mongoResult=($(aws ec2 describe-instances --region "$awsRegionName" --filter "Name=tag:Name,Values=$awsInstanceTagName*" --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value[] | [0],PublicDnsName,PrivateDnsName,InstanceId]" --output text | sort | tr "\t" "," ))
mongoResult=($(aws ec2 describe-instances --region "$awsRegionName" --filter "Name=tag:Name,Values=$awsInstanceTagName*" --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value[] | [0],PublicDnsName]" --output text | sort | tr "\t" "," ))
mongoNames=($(printf '%s\n' "${mongoResult[@]}" | cut -d',' -f1))
mongoPublicDNS=($(printf '%s\n' "${mongoResult[@]}" | cut -d',' -f2))
mongoPrivateDNS=($(printf '%s\n' "${mongoResult[@]}" | cut -d',' -f3))
mongoInstanceIds=($(printf '%s\n' "${mongoResult[@]}" | cut -d',' -f4))

############################################################
# Create machine.info lookup file 
############################################################
echo "

# Mongo
`printf '%s\n' "${mongoResult[@]}"`
'

" > "./machines.info.txt"


