provider "aws" {
  region = "${var.region}"
  shared_credentials_file = "/home/blissnd/.aws/credentials"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc-cidr}"
  enable_dns_hostnames = true
}


# Public Subnets
resource "aws_subnet" "subnet-a" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.subnet-cidr-a}"
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "subnet-b" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.subnet-cidr-b}"
  availability_zone = "${var.region}b"
}

resource "aws_subnet" "subnet-c" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.subnet-cidr-c}"
  availability_zone = "${var.region}c"
}

resource "aws_subnet" "subnet-d" {
  count = "${var.extra_subnet}"
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.subnet-cidr-d}"
  availability_zone = "${var.region}d"
}

resource "aws_route_table" "subnet-route-table" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route" "subnet-route" {
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = "${aws_internet_gateway.igw.id}"
  route_table_id          = "${aws_route_table.subnet-route-table.id}"
}

resource "aws_route_table_association" "subnet-a-route-table-association" {
  subnet_id      = "${aws_subnet.subnet-a.id}"
  route_table_id = "${aws_route_table.subnet-route-table.id}"
}

resource "aws_route_table_association" "subnet-b-route-table-association" {
  subnet_id      = "${aws_subnet.subnet-b.id}"
  route_table_id = "${aws_route_table.subnet-route-table.id}"
}

resource "aws_route_table_association" "subnet-c-route-table-association" {
  subnet_id      = "${aws_subnet.subnet-c.id}"
  route_table_id = "${aws_route_table.subnet-route-table.id}"
}

resource "aws_route_table_association" "subnet-d-route-table-association" {
  count = "${var.extra_subnet}"
  subnet_id      = "${aws_subnet.subnet-d.id}"
  route_table_id = "${aws_route_table.subnet-route-table.id}"
}

# Nginx
resource "aws_instance" "instance" {
  ami           = "${var.ami_id}"
  instance_type = "t2.micro"
  vpc_security_group_ids      = [ "${aws_security_group.security-group.id}" ]
  subnet_id                   = "${aws_subnet.subnet-a.id}"
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/sh
sudo yum install -y java-1.8.0-openjdk
sudo yum install -y maven
sudo yum install -y git
git clone https://github.com/spring-projects/spring-boot.git
sudo yum install -y wget
cd /usr/local/src
sudo wget http://www-us.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz
sudo tar -xf apache-maven-3.5.4-bin.tar.gz
sudo mv apache-maven-3.5.4/ apache-maven/
cd /etc/profile.d/
export M2_HOME=/usr/local/src/apache-maven
export PATH=${M2_HOME}/bin:${PATH}
cd ~/spring_test/spring-boot/spring-boot-samples/spring-boot-sample-tomcat
mvn spring-boot:run
yum install -y nginx
/etc/nginx
sudo sed 's/^[^#].*location\s\/\s{[.\n]*/\tlocation \/ {\n\t\tproxy_pass http:\/\/localhost:8080;/' nginx.conf | sudo tee nginx.conf
service nginx start
sudo setenforce 0
EOF
}

# Nginx-2 (Backup)
resource "aws_instance" "instance2" {
  ami           = "${var.ami_id}"
  instance_type = "t2.micro"
  vpc_security_group_ids      = [ "${aws_security_group.security-group.id}" ]
  subnet_id                   = "${aws_subnet.subnet-b.id}"
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/sh
sudo yum install -y java-1.8.0-openjdk
sudo yum install -y maven
sudo yum install -y git
git clone https://github.com/spring-projects/spring-boot.git
sudo yum install -y wget
cd /usr/local/src
sudo wget http://www-us.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz
sudo tar -xf apache-maven-3.5.4-bin.tar.gz
sudo mv apache-maven-3.5.4/ apache-maven/
cd /etc/profile.d/
export M2_HOME=/usr/local/src/apache-maven
export PATH=${M2_HOME}/bin:${PATH}
cd ~/spring_test/spring-boot/spring-boot-samples/spring-boot-sample-tomcat
mvn spring-boot:run
yum install -y nginx
sudo sed 's/^[^#].*location\s\/\s{[.\n]*/\tlocation \/ {\n\t\tproxy_pass http:\/\/localhost:8080;/' nginx.conf | sudo tee nginx.conf
/etc/nginx
service nginx start
sudo setenforce 0
EOF
}


resource "aws_security_group" "security-group" {
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress = [
    {
      from_port = "80"
      to_port   = "80"
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port = "443"
      to_port   = "443"
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port = "22"
      to_port   = "22"
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "nginx_domain" {
  value = "${aws_instance.instance.public_dns}"
}

############################# Bastion ###########################

resource "aws_instance" "bastion" {
  ami                         = "${var.ami_id}"
  key_name                    = "${aws_key_pair.bastion_key.key_name}"
  instance_type               = "t2.micro"
  vpc_security_group_ids  = ["${aws_security_group.bastion-sg.id}"]
  associate_public_ip_address = true
  subnet_id                   = "${aws_subnet.subnet-a.id}"
}

resource "aws_security_group" "bastion-sg" {
  name   = "bastion-security-group"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "hello"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0gnaIxNKWCupRDUS5d8gl/FHm2keegihvOCy+tQ3XbIyFDQdSGryNxBGcGyPDWoYzK3z1PnTjldJ9kxFVqq3PadJXq9VGYvQ4EB4SE/dVY0ACM9VKmC8kLdBrggNuZxYZc0tY0jJegSZPjvBX74qknW6gW5YghTAf1Y4G3uovJRTcl/yaQck8c3NsUwerppZxrA91XD5vwujD5zaPq+UJAUwvePqzsEi/C6ZYyJiD9KBG9QMNJd9POUWUeAHwTgbbw+er40mKIyIoXBZ47YxlQwKAfnCam7/DQagcqkqKTMuqhz+j19IrAZ95/1w8gyY6tNdmTzyi1XhWFma4NkLt blissnd@blissnd-NUC"
}

output "bastion_public_ip" {
  value = "${aws_instance.bastion.public_ip}"
}
