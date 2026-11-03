# TP 3 — les ressources à utiliser


Documentation : https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs
image_url_bionic = "https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
image_url_jammy  = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
## 1. La carte des ressources

```
data  openstack_networking_network_v2  "public"  (existant)
         │
         ▼
resource openstack_networking_router_v2  (1 seul)
         ├──► openstack_networking_router_interface_v2  ◄── subnet_public
         └──► openstack_networking_router_interface_v2  ◄── subnet_private

resource openstack_images_image_v2  "bionic"   (URL 18.04)
resource openstack_images_image_v2  "jammy"    (URL 22.04)
resource openstack_compute_flavor_v2           (2 vCPU / 2048 Mo / 10 Go)
resource openstack_compute_keypair_v2

network_public ─► subnet_public ─► port_vm1 ─► VM1 (bionic, user_data nginx) ─► floating IP + associate
                                     ▲
                       secgroup_vm1 (HTTP, SSH, ICMP) + 3 rules

network_private ─► subnet_private ─► port_vm2 ─► VM2 (jammy, sans IP flottante)
                                       ▲
                        secgroup_vm2 (ICMP, SSH depuis le réseau public) + 2 rules
```

Au total **24 ressources** et 1 data source. Le `plan` doit annoncer `24 to add`.

## 2. Étape par étape

### Étape 1 — Les deux images Glance

Ressource `openstack_images_image_v2`, **deux fois** (un bloc par image) :

- `name`, `image_source_url` (la variable), `disk_format = "qcow2"`,
  `container_format = "bare"`, `visibility = "private"`.
- Optionnel : `properties = { os_distro = "ubuntu" }`.

> C'est OpenStack qui télécharge l'image depuis l'URL, pas votre poste.
> Comptez 1 à 3 minutes par image à l'apply. Les deux URLs sont des
> **variables**, voyez `cloud-images.ubuntu.com/bionic/current/` et
> `.../jammy/current/`, fichier `*-server-cloudimg-amd64.img`.

### Étape 2 — Le flavor

Ressource `openstack_compute_flavor_v2` : `name`, `vcpus`, `ram` (en Mo),
`disk` (en Go). Les trois valeurs sont des variables.

> Créer un flavor demande le rôle admin. Votre `clouds.yaml` l'a.
> Respectez 10 Go de disque : l'hyperviseur du lab n'en a que 30 pour tout.

### Étape 3 — Deux réseaux, deux sous-réseaux

Deux blocs `openstack_networking_network_v2` et deux blocs
`openstack_networking_subnet_v2`, exactement comme au TP1, avec deux CIDR
différents (par exemple `10.30.1.0/24` et `10.30.2.0/24`).

> Donnez aux blocs des noms Terraform parlants : `net_public` / `net_private`,
> `subnet_public` / `subnet_private`. Vous allez les référencer souvent.

### Étape 4 — Un routeur, deux interfaces

- **Un seul** `openstack_networking_router_v2`, `external_network_id` depuis
  le `data` sur `public`.
- **Deux** `openstack_networking_router_interface_v2` : même `router_id`,
  un `subnet_id` différent chacun.

> C'est l'indice « un routeur peut avoir plusieurs interfaces ». Avec ses
> deux pattes, le routeur fait passer les paquets de VM1 vers VM2.
> Si vous créez deux routeurs, les deux réseaux ne se parleront pas.

### Étape 5 — Deux security groups

Deux `openstack_networking_secgroup_v2` et leurs `openstack_networking_secgroup_rule_v2` :

| SG | Règles | `remote_ip_prefix` |
|---|---|---|
| VM1 (web) | TCP 80, TCP 22, ICMP | `0.0.0.0/0` |
| VM2 (privée) | ICMP ; SSH en option | `0.0.0.0/0` pour ICMP ; pour SSH, le **CIDR du réseau public** suffit |

> Rappel : une ressource `rule` par règle. Pas de `port_range_*` pour ICMP.
> Sans la règle ICMP sur VM2, le `ping` depuis VM1 échouera même si le
> routage est parfait : c'est le piège du critère de validation.

### Étape 6 — Keypair

`openstack_compute_keypair_v2` avec `public_key = file(pathexpand(var.public_key_path))`.
Une seule keypair pour les deux VMs.

### Étape 7 — Le cloud-init de VM1 dans un template

1. Créez `templates/vm1_nginx.yaml.tftpl` qui commence par `#cloud-config`,
   avec une section `runcmd:` qui fait `apt-get update`, installe `nginx`,
   puis `systemctl enable --now nginx`.
2. Dans `locals.tf`, rendez-le :
   `templatefile("${path.module}/templates/vm1_nginx.yaml.tftpl", { vm_name = ... })`.
3. Passez ce local dans `user_data` de VM1.

> **Ubuntu 18.04 est en fin de vie.** Ses dépôts `archive.ubuntu.com` et
> `security.ubuntu.com` renvoient 404. Rendez le script robuste : si
> `apt-get update` échoue, remplacez ces deux hôtes par
> `old-releases.ubuntu.com` dans `/etc/apt/sources.list` (un `sed -i`) et
> relancez `apt-get update`.
>
> Dans un `.tftpl`, `${...}` est pour Terraform. Un `$` destiné au shell
> s'écrit `$$`. Si vous n'avez aucune variable shell, pas de souci.

### Étape 8 — VM1 : port, instance, IP flottante

- `openstack_networking_port_v2` sur `net_public` / `subnet_public`,
  `security_group_ids = [sg_vm1]`.
- `openstack_compute_instance_v2` : `image_id` = l'id de l'image **bionic**
  (pas `image_name`, l'image est créée par vous), `flavor_id` = l'id du
  flavor créé, `key_pair`, `user_data`, bloc `network { port = ... }`,
  `depends_on` sur l'interface routeur du réseau **public**.
- `openstack_networking_floatingip_v2` (`pool = "public"`) et
  `openstack_networking_floatingip_associate_v2` sur le **port** de VM1.

### Étape 9 — VM2 : port et instance, sans IP flottante

Même structure que VM1 avec `net_private` / `subnet_private`, `sg_vm2`,
`image_id` = **jammy**, pas de `user_data`, `depends_on` sur l'interface
routeur du réseau **privé**. Aucune ressource floating IP.

## 3. Les outputs

| Output | Valeur |
|---|---|
| `vm1_ip_flottante` | `.address` de la floating IP |
| `vm1_url` | `"http://${...address}"` |
| `vm1_ip_privee` | `all_fixed_ips[0]` du port de VM1 |
| `vm2_ip_privee` | `all_fixed_ips[0]` du port de VM2 |
| `test_ping` | une chaîne : `ssh ubuntu@<fip>` puis `ping -c 3 <ip VM2>` |

## 4. Variables attendues dans `terraform.tfvars`

`cloud_name`, `public_key_path`, `external_network_name`,
`public_subnet_cidr`, `private_subnet_cidr`, `dns_nameservers`,
`image_url_bionic`, `image_url_jammy`, `flavor_vcpus`, `flavor_ram_mb`,
`flavor_disk_gb`. Chacune déclarée avec `type` et `description`.


