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
