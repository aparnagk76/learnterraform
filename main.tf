# Create a VPC
resource "aws_vpc" "aparnavpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    env = var.environment
  }
}

# Create a Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.aparnavpc.id
  tags = {
    env = var.environment
  }
}

# Create a public and private subnet
resource "aws_subnet"  "pub" {
  vpc_id     = aws_vpc.aparnavpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    env = var.environment
  }
}
resource "aws_subnet" "pri"{
  vpc_id     = aws_vpc.aparnavpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    env = var.environment
  }
}
# Create a route table
resource "aws_route_table" "internetroute" {
  vpc_id = aws_vpc.aparnavpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    env = var.environment
  }
}

# Create a route table association
resource "aws_route_table_association" "rta" {
  route_table_id = aws_route_table.internetroute.id
  subnet_id = aws_subnet.pub.id
}

resource "tls_private_key" "terraformkeypair" {
  algorithm   = "RSA"
  ecdsa_curve = "2048"
}

resource "aws_key_pair" "terraformkeypair" {
  key_name   = join("-", ["terraformkeypair",var.environment])
  public_key = tls_private_key.terraformkeypair.public_key_openssh
}

resource "local_file" "terraformkeypair" {
  content = tls_private_key.terraformkeypair.private_key_pem
  filename = "terraformkeypair.pem"
}

# Create a security group to allow ssh and http connections
resource "aws_security_group" "allow_ssh_http" {
  vpc_id = aws_vpc.aparnavpc.id
  ingress = [
    {
      cidr_blocks = ["0.0.0.0/0"]
      from_port = 22
      to_port = 22
      protocol = "tcp"
      description = "allow ssh traffic from anywhere"
      ipv6_cidr_blocks = null,
      prefix_list_ids = null,
      security_groups = null,
      self = null,
    },
    {
      cidr_blocks = ["0.0.0.0/0"]
      from_port = 80
      to_port = 80
      protocol = "tcp"
      description = "allow http traffic from anywhere"
      ipv6_cidr_blocks = null,
      prefix_list_ids = null,
      security_groups = null,
      self = null,
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "allow all egress traffic"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = null,
      prefix_list_ids = null,
      security_groups = null,
      self = null,
    }
  ]
  name = "ssh,http security group"
  tags = {
    env = var.environment
  }
}

# Create an Ec2 instance
resource "aws_instance" "web" {
  ami = "ami-06fcc1f0bc2c8943f"
  associate_public_ip_address = "true"
  availability_zone = aws_subnet.pub.aws_availability_zones[0] #data.aws_availability_zones.available.names[0]
  subnet_id = aws_subnet.pub.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]
  key_name = aws_key_pair.terraformkeypair.key_name
  connection {
    host = self.public_ip
    user = "ec2-user"
    private_key = file("terraformkeypair.pem")
  }
  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install -y nginx1.12",
      "sudo service nginx start",
      "sudo wget http://download.redis.io/redis-stable.tar.gz"
    ]
  }
  tags = {
    env = var.environment
  }
}