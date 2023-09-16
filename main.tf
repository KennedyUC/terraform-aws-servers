resource "aws_launch_configuration" "ServerLaunchConfig" {
  name                 = "ServerLaunchConfig"
  image_id             = var.ec2_ami_id
  instance_type        = var.ec2_instance_type
  security_groups      = [var.security_group_id]
  key_name             = var.aws_key_pair_name

  ebs_block_device {
    device_name = "/dev/sdk"
    volume_type = "standard"
    volume_size = 10
  }
}

resource "aws_lb_target_group" "ServerTargetGroup" {
  name     = "ServerTargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    interval            = 10
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    timeout             = 8
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  depends_on = [aws_launch_configuration.ServerLaunchConfig]
}

resource "aws_autoscaling_group" "ServerAutoScaleGroup" {
  name                 = "ServerAutoScaleGroup"
  vpc_zone_identifier  = var.private_subnet_ids
  launch_configuration = aws_launch_configuration.ServerLaunchConfig.name
  min_size             = var.min_instance_count
  max_size             = var.max_instance_count
  target_group_arns    = [aws_lb_target_group.ServerTargetGroup.arn]

  depends_on = [aws_lb_target_group.ServerTargetGroup]
}

resource "aws_lb" "ServerLB" {
  name               = "ServerLB"
  subnets            = var.public_subnet_ids
  security_groups    = [var.security_group_id]

  depends_on = [aws_autoscaling_group.ServerAutoScaleGroup]
}

resource "aws_lb_listener" "Listener" {
  load_balancer_arn = aws_lb.ServerLB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ServerTargetGroup.arn
  }

  depends_on = [aws_lb.ServerLB]
}

resource "aws_lb_listener_rule" "ALBListenerRule" {
  listener_arn = aws_lb_listener.Listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ServerTargetGroup.arn
  }

  condition {
    path_pattern {
    values = ["/"]
    }
  }

  depends_on = [aws_lb_listener.Listener]
}