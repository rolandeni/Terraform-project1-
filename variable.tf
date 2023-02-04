#route53 variable
variable "domain_name" {
  default     = "rolandproject.me"
  description = "domain name"
  type        = string
}

variable "record_name" {
  default     = "terraform-test"
  description = "sub domain name"
  type        = string
}


variable "inbound" {
  type    = list(number)
  default = [80, 443, 22]
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"

}
variable "subnet" {
  type = map(any)
  default = {
    subnet-a = {
      az         = "az1"
      cidr_block = "10.0.1.0/24"
    }
    subnet-b = {
      az         = "az2"
      cidr_block = "10.0.2.0/24"
    }
    subnet-c = {
      az         = "az3"
      cidr_block = "10.0.3.0/24"
    }
  }

}

