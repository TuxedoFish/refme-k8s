resource "aws_security_group" "api-envoy-lb-k8s-local" {
    name =  "api-envoy-lb.${var.cluster_name}.k8s.local"
    vpc_id = aws_vpc.main.id
    description = "Security group for API envoy load balancer"
    ingress {
        from_port = 50051
        to_port = 50051
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 3 
        to_port = 4 
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0 
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        KubernetesCluster = "${var.cluster_name}.k8s.local"
        Name = "api-enovy-lb.${var.cluster_name}.k8s.local"
    }
}

resource "aws_security_group" "bastion_node" {
    name =  "bastion_node"
    vpc_id = aws_vpc.main.id
    description = "Security group for allowing required traffic to bastion node"
    ingress {
        from_port = 22 
        to_port = 22 
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0 
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "sg_bastion"
    }
}

resource "aws_security_group" "k8s_worker_nodes" {
    name =  "k8s_workers_${var.cluster_name}"
    vpc_id = aws_vpc.main.id
    description = "Worker nodes security group"
    ingress {
        from_port = 0 
        to_port = 0
        protocol = "-1"
        cidr_blocks = [aws_vpc.main.cidr_block]
    }
    egress {
        from_port = 0 
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.cluster_name}_nodes"
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
}

resource "aws_security_group" "k8s_worker_nodes" {
    name =  "k8s_masters_${var.cluster_name}"
    vpc_id = aws_vpc.main.id
    description = "Master nodes security group"
    tags = {
        Name = "${var.cluster_name}_nodes"
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
}

resource "aws_security_group_rule" "traffic_from_lb" {
    type "ingress"
    description = "Allow Envoy traffic from the load balancer"
    from_port = 50051
    to_port = 50051
    protocol = "tcp"
    source_security_group_id = aws_security_group.api-envoy-lb-k8s-local.id
    security_group_id = aws_security_group.k8s_masters_nodes.id
}

resource "aws_security_group_rule" "traffic_from_workers_to_masters" {
    type "ingress"
    description = "Allow Envoy traffic from the load balancer"
    from_port = 0
    to_port = 0
    protocol = "-1"
    source_security_group_id = aws_security_group.k8s_worker_nodes.id
    security_group_id = aws_security_group.k8s_masters_nodes.id
}

resource "aws_security_group_rule" "traffic_from_bastion_to_masters" {
    type "ingress"
    description = "Allow traffic from the bastion node"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    source_security_group_id = aws_security_group.bastion_node.id
    security_group_id = aws_security_group.k8s_masters_nodes.id
}

resource "aws_security_group_rule" "masters_egress" {
    type "egress"
    description = "Allow traffic from the masters nodes"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.k8s_masters_nodes.id
}