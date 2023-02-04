
resource "aws_security_group" "elb-sg" {
  name = "elb-sg"
  #incoming traffic
  dynamic "ingress" {
    for_each = var.inbound
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] #replace with desired ip 
    }
  }

  #outgoing traffic all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #replace with desired ip
  }
}
#creating AWS instances
resource "aws_instance" "server1" {

  ami             = "ami-00149760ce42c967b"
  instance_type   = "t2.micro"
  key_name        = "key10"
  count           = 4
  security_groups = ["elb-sg"]
  user_data       = <<EOF
  #!/bin/bash
  sudo apt update &&& sudo apt upgrade
  sudo apt install apache2 -y
  sudo ufw allow 'Apache'  
  sudo systemctl start apache2 
  sudo echo "welcome to server1" > /var/www/html/index.html
EOF
  tags = {
    name   = "demo server1"
    source = "terraform"
  }


}

#create a new loadbalancer
resource "aws_elb" "balancer" {
  name               = "lb-balancer"
  availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:80/"
    interval            = 30
  }

  //elb attachments
  # number_of_instances             = length(aws_instance.server1) 
  instances                 = aws_instance.server1.*.id
  cross_zone_load_balancing = true
  idle_timeout              = 40
  tags = {
    name = "demo-elb"
  }

}

# create a hosted zone in route 53
# resource "aws_route53_zone" "zone1" {
#   name = var.domain_name 
# }
#to use a hosted zone
data "aws_route53_zone" "zone1" {
  name = var.domain_name

}
#To create a record
resource "aws_route53_record" "terraform-test" {
  zone_id = data.aws_route53_zone.zone1.zone_id
  name    = var.record_name
  type    = "A"
  alias {
    name                   = aws_elb.balancer.dns_name
    zone_id                = aws_elb.balancer.zone_id
    evaluate_target_health = true
  }
}


# output for ELB
output "aws_elb_dns" {
  description = "public ip of EC22"
  value       = aws_elb.balancer.dns_name
}
#output for instances
resource "local_file" "instance_public_ip0" {
  filename = "host-inventory"
  content  = <<EOT
%{for ip_addr in aws_instance.server1.*.public_ip~}
${ip_addr}
%{endfor~}
EOT
  #To execute Ansible Script
  provisioner "local-exec" {
    command = "ansible-playbook  apache.yml -i host-inventory --user ubuntu --key-file ~/.key10.pem"

  }

}


