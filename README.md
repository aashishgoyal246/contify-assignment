# Document for Contify Assignment

This document is about how to run the TF code, ansible code and github workflows.

## Steps to provision and deploy the infrastructure

1. Directory named `terraform` states the following -

- `bootstrap` - id_rsa public key that will be used to SSH into the EC2 instance to run the playbook.
- `env` - env specific terraform code to deploy.
- `modules` - all the modules on the basis of aws service.

2. To provision navigate to `terraform/env/dev` directory and kindly make the following changes before provisioning -

- In `terraform.tfvars` file update the `account_id` variable value to your account id.
- Create a aws profile named `contify` in your local env, than only provision the infrastructure.

3. Once above steps done, then run `terraform init` -> `terraform plan` -> `terraform apply`

4. For cloudwatch alerts, its being configured through terraform itself, configuration is in `terraform.tfvars` file.


## Steps to run Ansible playbook -

1. For setting up python and gunicorn -

`ansible-playbook playbooks/python-gunicorn.yaml`

2. For setting up ngnix -

`ansible-playbook playbooks/nginx.yaml`

3. For setting up postgresql -

`ansible-playbook playbooks/psql.yaml`

4. For setting up log rotation -

`ansible-playbook playbooks/logrotate.yaml`


## Steps to run CI/CD pipeline -

1. All workflows are present in `.github/workflows` directory, states as below -

- `blue-green-deploy.yaml` file builds, test and deploy changes to the blue/green server using route53 weighted policy.

- `rollback.yaml` file checks the current live traffic first whether its blue or green server, than on basis of that it sets 100% to rollback server and 0% to live server.


## Disaster Recovery Strategy -

1. To take backup of the postgresql instance, run the script -

- `bash disaster-recovery/db-backup.sh` - It takes backup as per current timestamp and stores the file into S3 bucket in gzip format.

- Cron can be set in the instance using `crontab -e` command -

`0 0 * * * /etc/disaster-recovery/db-backup.sh`

2. To restore backup of the postgres DB into new instance, run the script -

- `bash disaster-recovery/db-restore.sh` - It fetches the latest gzip file from S3 bucket than download it, once that is done, `pg_restore` restores the DB.
