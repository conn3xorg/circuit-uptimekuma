locals {
  image = "${var.image_repository}:${var.uptimekuma_version}@${var.image_digest}"
  data  = "/var/lib/uptime-kuma"

  local_host = lookup({ "0.0.0.0" = "127.0.0.1", "::" = "[::1]" }, var.listen_address, strcontains(var.listen_address, ":") ? "[${var.listen_address}]" : var.listen_address)
  local_url  = "http://${local.local_host}:${var.port}"

  # Waits for a listener on the port, read from /proc so the host needs no ss.
  wait_port = "for _ in $(seq 900); do grep -qE ':${format("%04X", var.port)} [0-9A-F]+:[0-9A-F]{4} 0A ' /proc/net/tcp /proc/net/tcp6 2>/dev/null && exit 0; sleep 1; done; echo 'Nothing listened on port ${var.port} in 15 minutes. See journalctl -u uptime-kuma.' >&2; exit 1"
}

circuit "uptimekuma" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # The SQLite database, with every monitor, user and status page. The
  # image runs as root, so nobody else on the host needs to get in.
  step "data" {
    directory {
      path  = local.data
      owner = "root"
      group = "root"
      mode  = "0700"
    }
  }
}

# Uptime Kuma runs from its official image as a Quadlet unit. It's on the
# host's network so a monitor for 127.0.0.1 checks the host, not the
# container, and UPTIME_KUMA_HOST and UPTIME_KUMA_PORT decide where it listens.
module "podman" {
  source = "github.com/conn3xorg/circuit-podman?ref=v0.1.0"

  depends_on = [conn3x_directory.uptimekuma__data]

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  containers = {
    uptime-kuma = {
      image   = local.image
      volumes = ["${local.data}:/app/data:Z"]
      environment = {
        UPTIME_KUMA_HOST = var.listen_address
        UPTIME_KUMA_PORT = tostring(var.port)
        # Without it, the first visitor picks a database in the browser.
        UPTIME_KUMA_DB_TYPE = "sqlite"
      }
      extra = ["Network=host"]
    }
  }
}

circuit "ready" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # On a first start Uptime Kuma pulls its image and sets up the database
  # before it listens, and after an upgrade it migrates the database first.
  # The wait_for below was already met before the restart, so a change that
  # restarts the container waits here.
  step "restarted" {
    depends_on = [module.podman]
    command {
      command  = local.wait_port
      triggers = sha256(jsonencode([local.image, var.listen_address, var.port]))
    }
  }

  step "port" {
    wait_for {
      port    = var.port
      timeout = "15m"
    }
  }
}
