# Le préfixe n'est défini qu'ici : tous les noms en dérivent.
locals {
  prefix = "ex7"

  net_name      = "${local.prefix}-net"
  subnet_name   = "${local.prefix}-subnet"
  router_name   = "${local.prefix}-router"
  sg_name       = "${local.prefix}-sg"
  key_name      = "${local.prefix}-key"
  web_name      = "${local.prefix}-web"
  lb_name       = "${local.prefix}-lb"
  listener_name = "${local.prefix}-listener-http"
  pool_name     = "${local.prefix}-pool-web"
  monitor_name  = "${local.prefix}-monitor-http"

  # cloud-init : nginx qui affiche le nom de l'instance, pour voir la répartition
  web_user_data = <<-CLOUDINIT
    #cloud-config
    package_update: true
    packages: [nginx]
    runcmd:
      - echo "<h1>$(hostname)</h1>" > /var/www/html/index.html
      - systemctl enable --now nginx
  CLOUDINIT
}
