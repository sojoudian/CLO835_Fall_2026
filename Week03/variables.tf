variable "key_name" {
  description = "Name of YOUR EC2 key pair (AWS Console > EC2 > Key Pairs in the Learner Lab). Used for SSH."
  type        = string
}

variable "lab_instance_profile" {
  description = "IAM instance profile attached to the node. The AWS Academy Learner Lab ships one called LabInstanceProfile (LabRole); the Learner Lab forbids creating IAM roles but allows passing this one."
  type        = string
  default     = "LabInstanceProfile"
}
