variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "uptimekuma_version" {
  type        = string
  default     = "2.5.9"
  nullable    = false
  description = "Tag of the Uptime Kuma image, such as \"2.5.9\" or \"2.5.9-slim\". Change image_digest with it."

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", var.uptimekuma_version))
    error_message = "uptimekuma_version must be an image tag, such as \"2.5.9\"."
  }
}

variable "image_digest" {
  type        = string
  default     = "sha256:e88415a90dd2f7efecdbc18de0490aff292764a3ac471531bf1d0481725591bd"
  nullable    = false
  description = "Digest of the image for uptimekuma_version, such as \"sha256:e884...\". Podman pulls by the digest, so a tag that moves upstream can't change what runs."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.image_digest))
    error_message = "image_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "image_repository" {
  type        = string
  default     = "ghcr.io/louislam/uptime-kuma"
  nullable    = false
  description = "Where to pull Uptime Kuma's image from. \"docker.io/louislam/uptime-kuma\" serves the same image, by the same digest, with Docker Hub's pull limits."

  validation {
    condition     = can(regex("^[a-z0-9.-]+(:[0-9]+)?(/[a-z0-9._-]+)+$", var.image_repository))
    error_message = "image_repository must be a registry and path without a tag, such as \"ghcr.io/louislam/uptime-kuma\"."
  }
}

variable "listen_address" {
  type        = string
  default     = "127.0.0.1"
  description = "Address Uptime Kuma listens on. The default keeps it on the host for a reverse proxy in front; \"0.0.0.0\" listens on every address."

  validation {
    condition     = can(cidrhost("${var.listen_address}/${strcontains(var.listen_address, ":") ? 128 : 32}", 0))
    error_message = "listen_address must be an IPv4 or IPv6 address, such as \"127.0.0.1\"."
  }
}

variable "port" {
  type        = number
  default     = 3001
  description = "Port Uptime Kuma listens on."

  validation {
    condition     = var.port >= 1 && var.port <= 65535 && floor(var.port) == var.port
    error_message = "port must be a whole number from 1 to 65535."
  }
}
