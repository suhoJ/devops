provider "aws" {
  region = "ap-northeast-2"
}

# Web EC2 instance
##################################################################
resource "aws_instance" "Web-a" {
  ami           = "ami-01123b84e2a4fba05"
  instance_type = "t2.micro"
  key_name = aws_key_pair.Web_make_keypair.key_name
  vpc_security_group_ids = [aws_security_group.Web_sg.id]
  subnet_id = aws_subnet.web-subnet-a.id
  availability_zone = "ap-northeast-2a"
  associate_public_ip_address = true
  
  tags = {
    Name = "Web"
  }
}

resource "aws_instance" "Web-c" {
  ami           = "ami-01123b84e2a4fba05"
  instance_type = "t2.micro"
  key_name = aws_key_pair.Web_make_keypair.key_name
  vpc_security_group_ids = [aws_security_group.Web_sg.id]
  subnet_id = aws_subnet.web-subnet-c.id
  availability_zone = "ap-northeast-2c"
  associate_public_ip_address = true
  
  tags = {
    Name = "Web"
  }
}
##################################################################

# App EC2 instance
##################################################################
resource "aws_instance" "App-a" {
  ami           = "ami-01123b84e2a4fba05"
  instance_type = "t2.micro"
  key_name = aws_key_pair.Web_make_keypair.key_name
  vpc_security_group_ids = [aws_security_group.App_sg.id]
  subnet_id = aws_subnet.app-subnet-a.id
  availability_zone = "ap-northeast-2a"
  
  tags = {
    Name = "App"
  }
  user_data = <<EOF
#!/bin/bash
sudo -su ec2-user <<EOS
sudo yum install mysql -y
sudo mysql -h ${aws_rds_cluster.aurora-mysql-db.endpoint} -u admin -padministrator <<MYSQL_SCRIPT
CREATE DATABASE webappdb;
use webappdb;
CREATE TABLE IF NOT EXISTS transactions(id INT NOT NULL AUTO_INCREMENT, amount DECIMAL(10,2), description VARCHAR(100), PRIMARY KEY(id));
INSERT INTO transactions (amount,description) VALUES ('400','groceries');
MYSQL_SCRIPT
cd /home/ec2-user
mkdir DB/
sudo chmod 777 DB/

# Create DbConfig.js file
cat << EOT > /home/ec2-user/DB/DbConfig.js
module.exports = Object.freeze({
    DB_HOST : '${aws_rds_cluster.aurora-mysql-db.endpoint}',
    DB_USER : '${aws_rds_cluster.aurora-mysql-db.master_username}',
    DB_PWD : '${aws_rds_cluster.aurora-mysql-db.master_password}',
    DB_DATABASE : 'webappdb'
});
EOT
EOS
EOF
}

resource "aws_instance" "App-c" {
  ami           = "ami-01123b84e2a4fba05"
  instance_type = "t2.micro"
  key_name = aws_key_pair.Web_make_keypair.key_name
  vpc_security_group_ids = [aws_security_group.App_sg.id]
  subnet_id = aws_subnet.app-subnet-c.id
  availability_zone = "ap-northeast-2c"
  
  tags = {
    Name = "App"
  }
  
  user_data = <<EOF
#!/bin/bash
sudo -su ec2-user <<EOS
sudo yum install mysql -y
sudo mysql -h ${aws_rds_cluster.aurora-mysql-db.endpoint} -u admin -padministrator <<MYSQL_SCRIPT
CREATE DATABASE webappdb;
use webappdb;
MYSQL_SCRIPT
cd /home/ec2-user
mkdir DB/
sudo chmod 777 DB/

# Create DbConfig.js file
cat << EOT > /home/ec2-user/DB/DbConfig.js
module.exports = Object.freeze({
    DB_HOST : '${aws_rds_cluster.aurora-mysql-db.endpoint}',
    DB_USER : '${aws_rds_cluster.aurora-mysql-db.master_username}',
    DB_PWD : '${aws_rds_cluster.aurora-mysql-db.master_password}',
    DB_DATABASE : 'webappdb'
});
EOT
EOS
EOF
}
##################################################################

# Db instance
##################################################################
resource "aws_rds_cluster" "aurora-mysql-db" {
  cluster_identifier = "database-1"
  engine_mode = "provisioned"
  db_subnet_group_name = aws_db_subnet_group.db-subnet-group.name
  vpc_security_group_ids = [aws_security_group.Db_sg.id]
  engine = "aurora-mysql"
  engine_version = "5.7.mysql_aurora.2.11.1"
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  database_name = "privatedb"
  master_username = "admin"
  master_password = "administrator"
  skip_final_snapshot = true
}

output "rds_writer_endpoint" {
  value = aws_rds_cluster.aurora-mysql-db.endpoint
}

resource "aws_rds_cluster_instance" "aurora-mysql-db-instance" {
  count = 2
  identifier = "database-1-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora-mysql-db.id
  instance_class = "db.t3.small"
  engine = "aurora-mysql"
  engine_version = "5.7.mysql_aurora.2.11.1"

  tags = {
    Name = "Db"
  }
}
##################################################################

#key-pair
##################################################################
resource "tls_private_key" "Web_make_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "Web_make_keypair" {
  key_name   = "Web_key"
  public_key = tls_private_key.Web_make_key.public_key_openssh
}

resource "local_file" "Web_downloads_key" {
  filename = "Web_key.pem"
  content  = tls_private_key.Web_make_key.private_key_pem
}
##################################################################

# Web security group
##################################################################
resource "aws_security_group" "Web_sg" {
  name = "Web-sg"
  vpc_id = aws_vpc.groomVPC.id
  tags = { name = "Web-sg" }
}

resource "aws_security_group_rule" "Web_lb_ssh" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.Web_sg.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "Web_lb_http" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.Web_sg.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "Web_lb_https" {
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.Web_sg.id}"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "Web_lb_tomcat" {
  type = "ingress"
  from_port = 8080
  to_port = 8080
  protocol = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.Web_sg.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "Web_lb_ssh_egress" {
  type = "egress"
  from_port = 22
  to_port = 22
  protocol = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.Web_sg.id}"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "Web_lb_http_egress" {
  type = "egress"
  from_port = 80
  to_port = 80
  protocol = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.Web_sg.id}"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "Web_lb_https_egress" {
  type = "egress"
  from_port = 443
  to_port = 443
  protocol = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.Web_sg.id}"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "Web_lb_http_tomcat_egress" {
  type = "egress"
  from_port = 8080
  to_port = 8080
  protocol = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.Web_sg.id}"
  
  lifecycle {
    create_before_destroy = true
  }
}
##################################################################

# App security group
##################################################################
resource "aws_security_group" "App_sg" {
  name = "App-sg"
  vpc_id = aws_vpc.groomVPC.id
  tags = { name = "App-sg" }
}

resource "aws_security_group_rule" "App_lb_http" {
  type = "ingress"
  from_port = 8080
  to_port = 8080
  protocol = "TCP"
  security_group_id = "${aws_security_group.App_sg.id}"
  source_security_group_id = "${aws_security_group.Web_sg.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "App_lb_http_egress" {
  type = "egress"
  from_port = 8080
  to_port = 8080
  protocol = "TCP"
  security_group_id = "${aws_security_group.App_sg.id}"
  source_security_group_id = "${aws_security_group.Web_sg.id}"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "App_lb_db_egress" {
  type = "egress"
  from_port = 8080
  to_port = 8080
  protocol = "TCP"
  security_group_id = "${aws_security_group.App_sg.id}"
  source_security_group_id = "${aws_security_group.Db_sg.id}"
  
  lifecycle {
    create_before_destroy = true
  }
}
##################################################################

# Db security group
##################################################################
resource "aws_security_group" "Db_sg" {
  name = "Db-sg"
  vpc_id = aws_vpc.groomVPC.id
  tags = { name = "Db-sg" }
}

resource "aws_security_group_rule" "Db_lb_App_ingress" {
  type = "ingress"
  from_port = 3306
  to_port = 3306
  protocol = "TCP"
  security_group_id = "${aws_security_group.Db_sg.id}"
  source_security_group_id = "${aws_security_group.App_sg.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "Db_lb_App_egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  security_group_id = "${aws_security_group.Db_sg.id}"
  source_security_group_id = "${aws_security_group.App_sg.id}"
  
  lifecycle {
    create_before_destroy = true
  }
}
##################################################################

#groomVPC
##################################################################
resource "aws_vpc" "groomVPC" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "groomVPC"
  }
}
##################################################################

#web-subnet
##################################################################
resource "aws_subnet" "web-subnet-a" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.groomVPC.id
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "web-subnet-a"
  }
}

resource "aws_subnet" "web-subnet-c" {
  cidr_block = "10.0.2.0/24"
  vpc_id     = aws_vpc.groomVPC.id
  availability_zone = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = {
    Name = "web-subnet-c"
  }
}
##################################################################

#App-subnet
##################################################################
resource "aws_subnet" "app-subnet-a" {
  cidr_block = "10.0.3.0/24"
  vpc_id     = aws_vpc.groomVPC.id
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "app-subnet-a"
  }
}

resource "aws_subnet" "app-subnet-c" {
  cidr_block = "10.0.4.0/24"
  vpc_id     = aws_vpc.groomVPC.id
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "app-subnet-c"
  }
}
##################################################################

#db-subnet
##################################################################
resource "aws_subnet" "db-subnet-a" {
  cidr_block = "10.0.5.0/24"
  vpc_id     = aws_vpc.groomVPC.id
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "db-subnet-a"
  }
}

resource "aws_subnet" "db-subnet-c" {
  cidr_block = "10.0.6.0/24"
  vpc_id     = aws_vpc.groomVPC.id
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "db-subnet-c"
  }
}

resource "aws_db_subnet_group" "db-subnet-group" {
  name = "db-subnet-group"
  subnet_ids = [aws_subnet.db-subnet-a.id, aws_subnet.db-subnet-c.id]
}
##################################################################

#Internet Gateway
##################################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.groomVPC.id
  
  tags = {
    Name = "igw"
  }
}
##################################################################

#NAT Gateway
##################################################################
resource "aws_eip" "ngw-eip-a" {
  vpc = true
}

resource "aws_eip" "ngw-eip-c" {
  vpc = true
}

resource "aws_nat_gateway" "ngw-a" {
    allocation_id = aws_eip.ngw-eip-a.id
    subnet_id = aws_subnet.web-subnet-a.id
    tags = {
        Name = "ngw-web-a"
    }
}

resource "aws_nat_gateway" "ngw-c" {
    allocation_id = aws_eip.ngw-eip-c.id
    subnet_id = aws_subnet.web-subnet-c.id
    tags = {
        Name = "ngw-web-c"
    }
}
##################################################################

#Web Route Table
##################################################################
resource "aws_route" "rt-to-igw" {
  route_table_id = aws_route_table.Web_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route_table" "Web_rt" {
  vpc_id = aws_vpc.groomVPC.id
  
  tags = {
    Name = "Web-rt"
  }
}

resource "aws_route_table_association" "Web_rta-a" {
  subnet_id      = aws_subnet.web-subnet-a.id
  route_table_id = aws_route_table.Web_rt.id
}

resource "aws_route_table_association" "Web_rta-c" {
  subnet_id      = aws_subnet.web-subnet-c.id
  route_table_id = aws_route_table.Web_rt.id
}
##################################################################

#App Route Table
##################################################################
resource "aws_route_table" "App_rt-a" {
  vpc_id = aws_vpc.groomVPC.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw-a.id
  }
  
  tags = {
    Name = "App-rt-a"
  }
}

resource "aws_route_table_association" "App_rta-a" {
  subnet_id      = aws_subnet.app-subnet-a.id
  route_table_id = aws_route_table.App_rt-a.id
}

resource "aws_route_table" "App_rt-c" {
  vpc_id = aws_vpc.groomVPC.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw-c.id
  }
  
  tags = {
    Name = "App-rt-c"
  }
}

resource "aws_route_table_association" "App_rta-c" {
  subnet_id      = aws_subnet.app-subnet-c.id
  route_table_id = aws_route_table.App_rt-c.id
}
##################################################################

#DB Route Table
##################################################################
resource "aws_route_table" "db_rt" {
  vpc_id = aws_vpc.groomVPC.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw-a.id
  }
  
  tags = {
    Name = "db-rt"
  }
}

resource "aws_route_table_association" "db_rta-a" {
  subnet_id      = aws_subnet.db-subnet-a.id
  route_table_id = aws_route_table.db_rt.id
}

resource "aws_route_table_association" "db_rta-c" {
  subnet_id      = aws_subnet.db-subnet-c.id
  route_table_id = aws_route_table.db_rt.id
}
##################################################################

#web-lb
##################################################################
resource "aws_lb" "web-lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Web_sg.id]
  subnets            = [aws_subnet.web-subnet-a.id, aws_subnet.web-subnet-c.id]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = "Web-lb"
  }
}

resource "aws_lb_listener" "web-lb-ls" {
  load_balancer_arn = aws_lb.web-lb.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener_rule" "web-lb-rule" {
  listener_arn = aws_lb_listener.web-lb-ls.arn
  priority = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_target_group_attachment" "Web-a" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.Web-a.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "Web-c" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.Web-c.id
  port             = 8080
}

resource "aws_lb_target_group" "web" {
  name     = "tf-web-lb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.groomVPC.id
}
##################################################################

#App-lb
##################################################################
resource "aws_lb" "app-lb" {
  name               = "app-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.App_sg.id]
  subnets            = [aws_subnet.app-subnet-a.id, aws_subnet.app-subnet-c.id]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = "App-lb"
  }
}

resource "aws_lb_listener" "app-lb-ls" {
  load_balancer_arn = aws_lb.app-lb.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group_attachment" "app-a" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.App-a.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "app-c" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.App-c.id
  port             = 8080
}

resource "aws_lb_target_group" "app" {
  name     = "tf-app-lb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.groomVPC.id
}
##################################################################

#Auto scaling web
##################################################################
resource "aws_ami_from_instance" "web-template-ami" {
  name = "WebImage"
  source_instance_id = aws_instance.Web-a.id
  depends_on = [aws_instance.Web-a, aws_instance.Web-c]
}

resource "aws_launch_configuration" "web-launch-config" {
  name_prefix = "web-launch-config"
  image_id = aws_ami_from_instance.web-template-ami.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.Web_sg.id]
}

resource "aws_autoscaling_group" "web-autoscaling-group" {
  name = "webASG"
  launch_configuration = aws_launch_configuration.web-launch-config.name
  vpc_zone_identifier = [aws_subnet.web-subnet-a.id, aws_subnet.web-subnet-c.id]
  desired_capacity = 2
  max_size = 2
  min_size = 2
  health_check_grace_period = 300
  health_check_type = "EC2"

  target_group_arns = [aws_lb_target_group.web.arn]
  depends_on = [aws_lb_target_group.web]
}
##################################################################

#Auto scaling App
##################################################################
resource "aws_ami_from_instance" "app-template-ami" {
  name = "AppImage"
  source_instance_id = aws_instance.App-a.id
  depends_on = [aws_instance.App-a, aws_instance.App-c]
}

resource "aws_launch_configuration" "app-launch-config" {
  name_prefix = "app-launch-config"
  image_id = aws_ami_from_instance.app-template-ami.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.App_sg.id]
}

resource "aws_autoscaling_group" "app-autoscaling-group" {
  name = "appASG"
  launch_configuration = aws_launch_configuration.app-launch-config.name
  vpc_zone_identifier = [aws_subnet.app-subnet-a.id, aws_subnet.app-subnet-c.id]
  desired_capacity = 2
  max_size = 2
  min_size = 2
  health_check_grace_period = 300
  health_check_type = "EC2"

  target_group_arns = [aws_lb_target_group.app.arn]
  depends_on = [aws_lb_target_group.app]
}
##################################################################