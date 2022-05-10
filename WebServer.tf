provider "aws" {
    region = "ap-south-1"
}

    // 1. Create VPC

    resource "aws_vpc" "WebServer-VPC" {
        cidr_block = "10.0.0.0/16"
        tags = {
            Name = "WebServer-VPC"
        }
    }

    // 2. Create a Internet Gateway

    resource "aws_internet_gateway" "WebServer-Gateway" {
        vpc_id = aws_vpc.WebServer-VPC.id
         tags = {
             Name = "WebServer-Gateway"
         }
    }

    // 3. Create a Custom Route Table

    resource "aws_route_table" "WebServer-Custom-Route" {
        vpc_id = aws_vpc.WebServer-VPC.id
        route {
            cidr_block = "0.0.0.0/0"
               gateway_id = aws_internet_gateway.WebServer-Gateway.id
        }
    }
    // 4. Create a Subnet

    resource "aws_subnet" "WebServer-Subnet" {
        vpc_id = aws_vpc.WebServer-VPC.id
        cidr_block = "10.0.1.0/24"
        availability_zone = "ap-south-1a"
        tags = {
            Name = "WebServer Subnet"
        }
    }

    // 5. Associate subnet with route table

    resource "aws_main_route_table_association" "WebServer-Route-Table-Association" {
        vpc_id         = aws_vpc.WebServer-VPC.id
        route_table_id = aws_route_table.WebServer-Custom-Route.id
    }

    // 6. Create Security Group to alllow HTTP, HTTPS, SSH

    resource "aws_security_group" "WebServer_Traffic" {
        name        = "allow_WebServer_Traffic"
        description = "Allow WebServer inbound traffic"
        vpc_id      = aws_vpc.WebServer-VPC.id
        
        ingress {
            description      = "Https"
            from_port        = 443
            to_port          = 443
            protocol         = "tcp"
            cidr_blocks      = ["0.0.0.0/0"]
        }

        ingress {
            description      = "Http"
            from_port        = 80
            to_port          = 80
            protocol         = "tcp"
            cidr_blocks      = ["0.0.0.0/0"]
        }

        ingress {
            description      = "SSH"
            from_port        = 22
            to_port          = 22
            protocol         = "tcp"
            cidr_blocks      = ["0.0.0.0/0"]
        }

        egress {
            from_port        = 0
            to_port          = 0
            protocol         = "-1"
            cidr_blocks      = ["0.0.0.0/0"]
        }
        tags ={
            Name = "WebServer-Traffic"
        }
    } 
    // 7. Create a Network Interface with an IP in the  subnet that was created in step 4

    resource "aws_network_interface" "WebServer-Network-Interface" {
        subnet_id       = aws_subnet.WebServer-Subnet.id
        private_ips     = ["10.0.1.50"]
        security_groups = [aws_security_group.WebServer_Traffic.id]    
    }

    // 8. Assign a Elastic IP to the Network Interface

    resource "aws_eip" "WebServer-Elastic-IP" {
        vpc      = true
        network_interface = aws_network_interface.WebServer-Network-Interface.id
        associate_with_private_ip = "10.0.1.50"
        depends_on = [aws_internet_gateway.WebServer-Gateway]
    }
    // 9. Create Ubuntu Server and Install Apache2

    resource "aws_instance" "WebServer-Instance" {
        ami = "ami-0756a1c858554433e"
        instance_type = "t2.micro"
        availability_zone = "ap-south-1a"
        key_name = "WebServer-Key"

        network_interface {
          device_index = 0
          network_interface_id = aws_network_interface.WebServer-Network-Interface.id
        }

        user_data = <<-EOF
                    #!/bin/bash
                    sudo apt update -y
                    sudo apt install apache2 -y
                    sudo systemctl start apache2
                    sudo bash -c "echo First web server created by Mayur Chavan > /var/www/html/index.html"
                    EOF

        tags = {
          "Name" = "WebServer"
        }

    }

    output "WebServer-Public-IP" {
        value = aws_instance.WebServer-Instance.public_ip
    }
