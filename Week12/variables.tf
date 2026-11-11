variable "key_name" {
  description = "Name of YOUR EC2 key pair (AWS Console > EC2 > Key Pairs in the Learner Lab). Used for SSH."
  type        = string
}

variable "lab_instance_profile" {
  description = "IAM instance profile attached to the node. The AWS Academy Learner Lab has the profile LabInstanceProfile (LabRole). The Learner Lab blocks the creation of IAM roles, but it allows this profile."
  type        = string
  default     = "LabInstanceProfile"
}
