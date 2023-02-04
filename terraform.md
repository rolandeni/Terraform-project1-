# MINI PROJECT (3)
* ### Using Terraform carry out the following task..
* ### Create 3 EC2 instances and put them behind an Elastic Load Balancer.
* ### Using Terraform export the public IPs of the Instances to a file called "host-inventory"
* ### Using Terraform connect the load balancer DNS to a Domain name of your choice.
* ### using Terraform create a record in Route53, an "A record" (terraform-test) subdomain linked to the main domain.
* ### Create an Ansible script that uses the host-inventory file Terraform created to install Apache, set timezone to Africa/Lagos and displays a simple HTML page that displays content to clearly identify all 3 EC2 instances.
* ### Your project is complete when one visits terraform-test.yoursdmain.com and it shows the content from your instances, while rotating between the servers as your refresh to display their unique content.

## REQUIREMENTS
+ internet connection
+ Basic knowledge of AWS. 
+ Basic knowledge of instances.
+ Basic knowledge of Ansible.
+ installed terraform. 
+ basic knowledge og Terraform 
+ 


### Terraform script is a bit similar to Ansible so we will be creating a single terraform file called *All.tf* for all the configurations .
# step 1
+ Open the AWS console and create an IAM USER. Give the user necessary permissions like EC2 and Route53 administrative permissions.
+ Download and install AWS CLI.
+ Link your IAM user to your CLI using the secret key, Access key, username and password. Run *AWS configure* on your Terminal. input requested details. Ignore *default input* 

NOTE: To be able to detect mistakes early in terraform, run the following terraform commands after each step below, before proceeding to the next step.
```
a. terraform init       # to initialize and generate terraform config files
```
```
b. terraform fmt        # to allign the terraform script neatly
```
```
c. terraform validate     # to test configuration for errors
```
```
d. terraform plan       # To view plan
```
```
d. terraform apply       #to implement plan
```

  
# step 2
1. create a new file called **provider.tf** this is where you specify the provider which you want to configure with. paste the below code or refer to terraform registry for the desired provider.
  
 ```       
    ---

provider  "aws_security_group" "elb-sg" {

  }

```

2. Create a Security Group:- This will be the security group for your instances. create a separate terraform file called **all.tf** and paste the below code. you can replace the CIDR BLOCK  with desired IP block. 
   
 ```       
    ---

resource "aws_security_group" "elb-sg" {
  name = "elb-sg"
#incoming traffic
  dynamic "ingress" {
    for_each = var.inbound
    content {
      from_port = ingress.value
      to_port = ingress.value
      protocol = "tcp"
      cidr_blocks = [ "0.0.0.0/0" ] 
    }
  }
  
  #outgoing traffic all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]#replace with desired ip
  }
}

```
+ The Ingress and Egress Arguments are used to specify the inbound and outbound rule.
   
3. Create EC2 instances, using the count Argument. using the *user_data* which is optional, it can be used to pre-install applications such as apache or nginx to test the accessibility of the instances thru the load balancer. in this case i pre-installed Apache using the *user-data*.

 ```       
#creating AWS instances
resource "aws_instance" "server1" {
  
  ami             = "ami-00149760ce42c967b"
  instance_type   = "t2.micro"
  key_name        = "key10"
  count         = 4
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
    name = "demo server1"
    source = "terraform"
  }
```
4. To create a load balancer for traffic distribution between instances. use this block of code below.
 ```       
#create a new load-balancer
resource "aws_elb" "balancer" {
    name            = "lb-balancer"
    availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]

    listener {
      instance_port         = 80
      instance_protocol     = "http"
      lb_port               = 80
      lb_protocol           = "http"
    }   

    health_check {
      healthy_threshold     = 2
      unhealthy_threshold   = 2
      timeout               = 5
      target                = "HTTP:80/"
      interval              = 30
    }

  # elb attachments 
  instances                       = aws_instance.server1.*.id
  cross_zone_load_balancing       = true
  idle_timeout = 40
  tags = {
    name = "demo-elb"
  }

}   
```
+ NOTE: The elb attachment block is used to attach the desired  instances to the Elastic load balancer.  

5. Creating a record for Route53:- in this section i used the Data source to reference an already existing AWS Hosted Zone. which is connected to my domain name created on NAMECHEAP.COM. The commented part is used for creating a Hosted Zone if one does not exist already. 
   
```       
    # To create a hosted zone in route 53
    # resource "aws_route53_zone" "zone1" {
    #   name = var.domain_name 
    # }
    # To use a hosted zone
    data "aws_route53_zone" "zone1"  {
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
```


6. To create an output that displays the Load Balancer DNS to test if the load Balancer functions properly. use the output resource block.
```
 # output for ELB
 output "aws_elb_dns" {
  description = "public ip of EC22"
  value = aws_elb.balancer.dns_name 
 }
```
On the CLI the Load balancer DNS is displayed after running terraform apply, with the DNS output of the load balancer, paste it an your browser to test if it functions. It should display "welcome to server1" or the Apache Home page.  
1. To create a second output that sends the instance public IP Address to a new file called host-inventory. This method is specifically used when using the count argument for instances.
```
#output for instances
resource "local_file" "instance_public_ip0" {
 filename  = "host-inventory"
 content   = <<EOT
%{for ip_addr in aws_instance.server1.*.public_ip~}
${ip_addr}
%{endfor~}
EOT
```
NOTE: If a terraform command is ended before completion you would run into statelock error. to solve this you would need to use -lock=false or delete the statelock files and all terraform files generated by terraform(Not Recommended). 

# STAGE 2 
## Ansible  
This is a simple Ansible script to install Apache and set up a HTML page, that displays the ip address of each server and the time and timezone.
The template is gotten from a github Repo.  
## step 1
1. Create a file called apache.yml (file can be named anything), it must have the .yml extension.
create the first block of code to update and upgrade your linux server.
```
- hosts: all
  become: yes
  tasks:

  - name: update & upgrade server
    apt:
      update_cache: yes
      upgrade: yes

``` 
2. install Apache and remove the default home page of Apache.
```
  - name: install Apache
    apt:
      name: apache2
      state: latest

  - name: remove the default apache page 
    file:
      path: /var/www/html
      state: absent
```
3. Now to get server template from githum and replace in location of Apache homepage.
```

  - name: TO GET web application FROM REPO
    git: >
      repo=https://github.com/rolandeni/HTML
      dest=/opt/html
      force=yes
      accept_hostkey=yes

  - name: TO replace web applicatin folder
    shell: sudo mv -f /opt/html /var/www/

  
```
4. Then we install PHP to convert our template to HTML format.
```

  - name: install php extension
    shell: sudo apt install php7.4-cli -y
  
  # - name: TO convert php to html
  - name: convert php to html
    shell:
      chdir: /var/www/html/
      cmd: php index.php > index.html

``` 
5. the final part to restart apache
```

  - name: restart Apache
    service:
      name: apache2
      state: restarted
      enabled: yes
```

  NOTE: For Ansible Sript to run smoothly, be cautions of the spacing and indentations. All the above codes should be in a single file called apache.yml. Also create a variable file called *variable.tf* and define your variables. 

6. Your private key should be stored as an environment varialbe using 
*export key=~/key10.pem* replace with your keyname. Also create a configuration file called **ansible.cfg** and set all necessary commands, which will help your ansible script run smoothly.

# Stage 3
+ Now to connect your ansible script to Terraform. This will enable a single Terraform command to setup the whole process once you run *terraform apply*. you add the ansible command to terraform script using the local_exe resource block.
```
   #To execute Ansible Script
     provisioner "local-exec" {
 	    command = "ansible-playbook  apache.yml -i host-inventory --user ubuntu --key-file ~/.key10.pem"

 	  }  

```

+ For tutorials on Ansible visit my youtube channel [@rolandtutorials/ansible](https://youtu.be/huhpX5Y47r8).
+ For tutorials on how to get a free domainname visit my youtube channel.[@rolandtutorials/freedomain](https://youtu.be/qopoU3lHdBY).
+ For tutorial on how to connect a custom domain to AWS route53 hosted zone visit my youtube channel. [@rolandtutorials/AWS](https://youtu.be/EeyKW5QR4xs). 

images are below.

![1](images/1.png)
![2](images/2.png)
![3](images/3.png)
![4](images/4.png)

