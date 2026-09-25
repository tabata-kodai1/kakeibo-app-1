# Rails API を Docker で動かす EC2。パブリックサブネットに置く。

# 最新の Amazon Linux 2023。AMI の ID を直書きせず、AWS が公開する SSM パラメータから引く。
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_key_pair" "deploy" {
  key_name   = "kakeibo-deploy"
  public_key = var.ssh_public_key
}

resource "aws_instance" "api" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.deploy.key_name

  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  # ビルド中の Docker イメージ・レイヤーで 8GB（既定）は足りなくなりやすい。
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 のみ
  }

  tags = { Name = "kakeibo-api" }
}

# 再起動でグローバル IP が変わると、フロントに埋め込む API の URL（VITE_API_BASE_URL）が
# 無効になる。Elastic IP で固定する。
resource "aws_eip" "api" {
  instance = aws_instance.api.id
  domain   = "vpc"

  tags = { Name = "kakeibo-api" }
}
