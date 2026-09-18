variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet" {
  type = string
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "app" {
  name   = "lacrei-${var.environment}"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Project     = "LacreiChallenge"
  }
}

resource "aws_iam_role" "ec2" {
  name = "lacrei-${var.environment}-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "lacrei-${var.environment}-ec2"
  role = aws_iam_role.ec2.name
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/lacrei/${var.environment}"
  retention_in_days = 3

  tags = {
    Environment = var.environment
    Project     = "LacreiChallenge"
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023.value
<<<<<<< HEAD
  instance_type          = "t3.micro"
=======
  instance_type          = "t2.micro"
>>>>>>> staging
  subnet_id              = var.public_subnet
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data = <<-EOF_USER_DATA
    #!/bin/bash
    set -e
    dnf update -y
    dnf install -y docker nginx amazon-cloudwatch-agent openssl
    systemctl enable --now docker
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/server.key -out /etc/nginx/ssl/server.crt -subj "/CN=lacrei-${var.environment}"
    cat > /etc/nginx/conf.d/lacrei.conf <<'EOF_NGINX'
    server {
      listen 443 ssl;
      server_name _;
      ssl_certificate /etc/nginx/ssl/server.crt;
      ssl_certificate_key /etc/nginx/ssl/server.key;

      location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
      }
    }
    EOF_NGINX
    setsebool -P httpd_can_network_connect 1 || true
    systemctl enable --now nginx
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF_CW'
    {
      "agent": {
        "metrics_collection_interval": 60
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/nginx/access.log",
                "log_group_name": "${aws_cloudwatch_log_group.app.name}",
                "log_stream_name": "{instance_id}/nginx-access"
              },
              {
                "file_path": "/var/log/nginx/error.log",
                "log_group_name": "${aws_cloudwatch_log_group.app.name}",
                "log_stream_name": "{instance_id}/nginx-error"
              },
              {
                "file_path": "/var/lib/docker/containers/*/*.log",
                "log_group_name": "${aws_cloudwatch_log_group.app.name}",
                "log_stream_name": "{instance_id}/docker"
              }
            ]
          }
        }
      },
      "metrics": {
        "namespace": "Lacrei/${var.environment}",
        "metrics_collected": {
          "mem": {
            "measurement": ["mem_used_percent"]
          },
          "disk": {
            "measurement": ["used_percent"],
            "resources": ["/"]
          }
        }
      }
    }
    EOF_CW
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  EOF_USER_DATA

  depends_on = [aws_cloudwatch_log_group.app]

  tags = {
    Name        = "lacrei-${var.environment}"
    Environment = var.environment
    Project     = "LacreiChallenge"
  }
}

output "instance_id" {
  value = aws_instance.app.id
}

output "public_ip" {
  value = aws_instance.app.public_ip
}
