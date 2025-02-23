region  = "ap-south-1"
profile = "contify"
env     = "dev"

vpc_cidr_block = "10.3.0.0/16"

elb_account_id = "127311923021"

account_id = "544603490736"

sns_topic_arn = ""

aws_availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

allowed_ssh_ips = [
  "10.3.0.0/16"
]

contify_ebs_size = 100

contify_ami = "ami-0fd2c44049dd805b8"

contify_instance_type             = "t3.medium"
contify_autoscaling_min_count     = 1
contify_autoscaling_desired_count = 1
contify_autoscaling_max_count     = 3

database_name     = ""
database_username = ""
database_password = ""

database_instance_class           = "db.t3.medium"
database_secondary_instance_class = "db.t3.medium"

database_instance_count           = 1
database_secondary_instance_count = 1

certificate_arn = "arn:aws:acm:ap-south-1:123412345785:certificate/c838c181-7096-4854-a4ca-a14540fd7311"

contify_kms_key_alias = "contify"

rds_cluster_parameter_group = {
  family = "aurora-postgresql16"

  parameter = [
    {
      name         = "rds.logical_replication"
      value        = 1
      apply_method = "pending-reboot"
    },
    {
      name         = "max_logical_replication_workers"
      value        = 8
      apply_method = "pending-reboot"
    },
    {
      name         = "max_replication_slots"
      value        = 10
      apply_method = "pending-reboot"
    },
    {
      name         = "max_wal_senders"
      value        = 12
      apply_method = "pending-reboot"
    },
    {
      name         = "max_worker_processes"
      value        = 10
      apply_method = "pending-reboot"
    },
    {
      name         = "tls_version"
      value        = "TLSv1.2"
      apply_method = "pending-reboot"
    }
  ]
}
