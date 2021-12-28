# SSH for access to bastion
resource "aws_key_pair" "sshkey" {
    public_key = "ssh-rsa 
AAAAB3NzaC1yc2EAAAADAQABAAABgQ
DoHCQpTA40FlpvsIYy4XzJSTJHh55z
7T+eZNDhcxQJlhyvPFTld58eayzNkw
gLUlm/14340cwdmNftpeHEAa0zSj9P
CHFVrbIzbhIVOdb9tOnkuDjN8yItbT
XJXe9BCJb3OlC6YxwIp2evpMEnzJqQ
RsEmeRyRZCCVHCWTq7b03NOaMsoM9z
8v952OZphhU121lxjGuKMf5Otl/P/E
VK1WKPxi/gg8UR5HAkrT6uhb2fdKkN
sSEVfM29u+/fJ+3DSmYACUGbGNqpWj
yM/WNh/tFlCANVpSjf7r3GzuZnyojU
YFynG0XbFm/AbwfE+nBX4vP8BZ00NK
zz+NZhkl8AcwyI7m9d2fBAvK9gYpmq
2wVlV0oWsvd4vfMu2YA5rKoK42KUgN
5qVue3l/InShZ23cgMt8nCf8N/sze7
zNZq2Y9csMB9wj27Oc//6gn+Z43y+W
QbUoQT0WDI8ehXf7n3tKTWJtRAwNd1
QLQa2ixPbNcgPWIzgmNMdIhr6HHxK7
090= liversedge@DESKTOP-MQIBNNU"
    key_name="sshkey"
}

# AMI for bastion
data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    owners = ["050351529511"]
}

# Bastion - t2.nano
resource "aws_instance" "bastion" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.nano"
    vpc_security_group_ids = [aws_security_group.bastion_node.id]
    key_name = aws_key_pair.sshkey.key_name
    subnet_id = aws_subnet.utility.id
    root_block_device {
        volume_size = 5
    }
    tags = {
        Name = "bastion.${var.cluster_name}"
    }
}

# Elastic Load Balancer
resource "aws_elb" "api-envoy-lb-k8s-local" {
    name = "api-${var.cluster_name}"
    listener {
        instance_port = 50051
        instance_protocol = "tcp"
        lb_port = 50051
        lb_protocol = "tcp"
    }
    security_groups = [aws_security_group.api-envoy-lb-k8s-local.id]
    subnets = [aws_subnet.public01.id]
    health_check {
        target = "SSL:50051"
        healthy_threshold = 2
        unhealthy_threshold = 2
        interval = 10
        timeout = 5
    }
    cross_zone_load_balancing = true
    idle_timeout = 300

    tags = {
        KubernetesCluster = var.cluster_name
        Name = "api.${var.cluster_name}"
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
}

resource "aws_launch_configuration" "masters-az01-k8s-local" {
    name_prefix = "masters.${var.cluster_name}"
    image_id = var.ami
    instance_type = var.master_instance_type
    key_name = aws_key_pair.sshkey.key_name
    iam_instance_profile = aws_iam_instance_profile.terraform_k8s_master_role-Instance-Profile.id
    security_groups = [aws_security_group.k8s_masters_nodes.id]
    # Uses AWS to set hostname of master node
    user_data            = <<EOT
#!/bin/bash
hostnamectl set-hostname --static "$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)"
EOT
    lifecycle {
        create_before_destroy = true
    }
    root_block_device {
        volume_type = "gp2"
        volume_size = "20"
        delete_on_termination = true
    }
}

resource "aws_autoscaling_group" "master-k8s-local-01" {
    name = "${var.cluster_name}_masters"
    launch_configuration = aws_launch_configuration.masters-az01-k8s-local.id
    max_size = 1
    min_size = 1
    vpc_zone_identifier = [aws_subnet.private01.id]
    load_balancers = [aws_elb.api-k8s-local.id]

    tags = [{
        key = "KubernetesCluster"
        value = var.cluster_name
        propogate_at_launch = true
    },
    {
        key = "Name"
        value = "masters.${var.cluster_name}"
        propogate_at_launch = true
    }
    {
        key = "k8s.io/role/master"
        value = "1"
        propogate_at_launch = true
    }
    {
        key = "kubernetes.io/cluster/${var.cluster_name}"
        value = "1"
        propogate_at_launch = true
    }]
}

resource "aws_launch_configuration" "worker-nodes-k8s-local" {
    name_prefix = "masters.${var.cluster_name}"
    image_id = var.ami
    instance_type = var.worker_instance_type
    key_name = aws_key_pair.sshkey.key_name
    iam_instance_profile = aws_iam_instance_profile.terraform_k8s_worker_role-Instance-Profile.id
    security_groups = [aws_security_group.k8s_worker_nodes.id]
    # Uses AWS to set hostname of master node
    user_data            = <<EOT
#!/bin/bash
hostnamectl set-hostname --static "$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)"
EOT
    lifecycle {
        create_before_destroy = true
    }
    root_block_device {
        volume_type = "gp2"
        volume_size = "20"
        delete_on_termination = true
    }
}

resource "aws_autoscaling_group" "nodes-k8s" {
    name = "${var.cluster_name}_workers"
    launch_configuration = aws_launch_configuration.worker-nodes-k8s-local.id
    max_size = var.nodes_max_size
    min_size = var.nodes_min_size
    vpc_zone_identifier = [aws_subnet.private01.id]
    
    tags = [{
        key = "KubernetesCluster"
        value = var.cluster_name
        propogate_at_launch = true
    },
    {
        key = "Name"
        value = "masters.${var.cluster_name}"
        propogate_at_launch = true
    }
    {
        key = "k8s.io/role/node"
        value = "1"
        propogate_at_launch = true
    }
    {
        key = "kubernetes.io/cluster/${var.cluster_name}"
        value = "1"
        propogate_at_launch = true
    }]
}