variable "key_name" {
  description = "Enter the name of YOUR EC2 key pair (AWS Console > EC2 > Key Pairs in the Learner Lab). SSH uses this key pair."
  type        = string
}

variable "lab_instance_profile" {
  description = "Terraform attaches this IAM instance profile to each node. The AWS Academy Learner Lab has the profile LabInstanceProfile (LabRole). The Learner Lab blocks the creation of IAM roles, but it allows this profile."
  type        = string
  default     = "LabInstanceProfile"
}
