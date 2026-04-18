variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cep_api_url" {
  description = "CEP API URL"
  type        = string
  default     = "https://cep.awesomeapi.com.br/json/01001000"
}

variable "glue_job_max_capacity" {
  description = "Maximum DPU for Glue job"
  type        = number
  default     = 2
}
