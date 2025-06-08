# Yandex Cloud 认证和配置信息
variable "yc_token" {
  description = "Yandex Cloud OAuth token. Can be created by running 'yc iam create-token'."
  type        = string
  sensitive   = true # 将此变量标记为敏感信息，不会在日志中显示
}

variable "yc_cloud_id" {
  description = "Yandex Cloud ID where resources will be created."
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID where resources will be created."
  type        = string
}