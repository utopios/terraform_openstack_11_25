# TP 1 — Fiche d'aide : les ressources à utiliser


| Votre clé publique `~/.ssh/id_rsa.pub` | `ls ~/.ssh/` ; sinon `ssh-keygen -t rsa` | lue avec `file()` |

## 1. La carte des ressources

Onze blocs au total, qui se branchent les uns sur les autres. Une flèche
veut dire « a besoin de l'id du bloc précédent ».

```
data  openstack_networking_network_v2  ("public", existant)
          │
          ▼
resource openstack_networking_router_v2 ──────────────────────┐
          │                                                   │
resource openstack_networking_network_v2  (votre réseau)      │
          │                                                   │
          ▼                                                   ▼
resource openstack_networking_subnet_v2 ──► openstack_networking_router_interface_v2
          │
          │        resource openstack_networking_secgroup_v2
          │                 │
          │                 ├─► openstack_networking_secgroup_rule_v2  (SSH)
          │                 └─► openstack_networking_secgroup_rule_v2  (ICMP)
          │                 │
          ▼                 ▼
resource openstack_networking_port_v2  (la "carte réseau" de la VM)
          │                       ▲
          ▼                       │
resource openstack_compute_instance_v2 ◄── openstack_compute_keypair_v2
          
resource openstack_networking_floatingip_v2 ──► openstack_networking_floatingip_associate_v2
                                                          ▲
                                                 (branchée sur le port)
```

## 2. Étape par étape

### Étape 1 — Réseau privé et sous-réseau

- `openstack_networking_network_v2` : juste un `name`.
- `openstack_networking_subnet_v2` : `network_id` (l'id du réseau créé juste
  au-dessus), `cidr`, `ip_version = 4`, `dns_nameservers` (une **liste**).

> Le `network_id` se lit sur la ressource réseau : `openstack_networking_network_v2.<nom>.id`.
> C'est ça qui crée la dépendance implicite, pas besoin de `depends_on`.

### Étape 2 — Relier au réseau externe

Question de l'énoncé : « par où transite un paquet qui sort de votre réseau ? »
Par un **routeur**. Il faut deux ressources, pas une :

- `openstack_networking_router_v2` : `name` et `external_network_id`, qui
  vient du **data source** `openstack_networking_network_v2` sur `public`.
- `openstack_networking_router_interface_v2` : `router_id` + `subnet_id`.
  C'est la « patte » du routeur dans votre sous-réseau.

> Erreur classique : créer le routeur sans l'interface. Le routeur existe,
> mais votre VM n'a aucune passerelle et l'IP flottante ne répondra jamais.

### Étape 3 — Security group

- `openstack_networking_secgroup_v2` : `name`, `description`.
- `openstack_networking_secgroup_rule_v2`, **une ressource par règle** :
  `direction = "ingress"`, `ethertype = "IPv4"`, `protocol`,
  `port_range_min` / `port_range_max` (pour TCP), `remote_ip_prefix = "0.0.0.0/0"`,
  `security_group_id`.

> Pour ICMP il n'y a pas de port : pas de `port_range_*`.
> Utilisez bien les ressources `openstack_networking_secgroup_*` (API Neutron).
> Les anciennes `openstack_compute_secgroup_*` que vous verrez dans certains
> supports sont dépréciées.

### Étape 4 — Keypair

- `openstack_compute_keypair_v2` : `name` et `public_key`.
- Pour lire le fichier : `file(pathexpand(var.public_key_path))`.

> `pathexpand()` transforme le `~` en chemin complet ; `file()` seul ne
> comprend pas `~`.

### Étape 5 — La VM, via un port

Deux façons de connecter une VM à un réseau. Celle attendue ici : créer
d'abord un **port** (la carte réseau), puis donner ce port à la VM.

- `openstack_networking_port_v2` : `name`, `network_id`,
  `security_group_ids` (liste), et un bloc `fixed_ip { subnet_id = ... }`.
- `openstack_compute_instance_v2` : `name`, `image_name`, `flavor_name`,
  `key_pair` (le **nom** de la keypair), et un bloc `network { port = ... }`.

> Avantage du port : le security group est posé sur le port, et l'IP flottante
> aussi (étape 6). Tout est au même endroit.
>
> Ajoutez sur la VM `depends_on = [<l'interface du routeur>]`. Sinon la VM
> peut démarrer avant que le routeur soit branché, et CirrOS n'obtient pas
> sa route par défaut au boot.

### Étape 6 — IP flottante

- `openstack_networking_floatingip_v2` : `pool = "public"` (le **nom** du
  réseau externe, pas son id).
- `openstack_networking_floatingip_associate_v2` : `floating_ip` (l'adresse,
  attribut `.address` de la ressource au-dessus) et `port_id`.

> Il existe aussi `openstack_compute_floatingip_associate_v2` qui prend un
> `instance_id`. Elle fonctionne mais affiche un avertissement de dépréciation :
> préférez la version `networking`, sur le port.

## 3. Les outputs

| Output | Où trouver la valeur |
|---|---|
| `ip_privee` | sur le port : `all_fixed_ips[0]` (ou sur la VM : `access_ip_v4`) |
| `ip_flottante` | sur l'IP flottante : `.address` |
| `ssh` | une chaîne construite : `"ssh cirros@${...}"` |

## 4. Les fichiers imposés et ce qu'on y met

| Fichier | Contenu |
|---|---|
| `versions.tf` | bloc `terraform { required_providers { openstack = { source = "terraform-provider-openstack/openstack", version = "~> 2.1" } } }` |
| `provider.tf` | `provider "openstack" { cloud = var.cloud_name }` |
| `variables.tf` | 7 variables : cloud, chemin clé, image, flavor, réseau externe, CIDR, DNS. Chacune avec `type` et `description` |
| `terraform.tfvars` | les 7 valeurs |
| `locals.tf` | `prefix = "tp1"` et tous les noms dérivés : `"${local.prefix}-net"`, etc. |
| `data.tf` | le data source sur `public` |
| `main.tf` | les 11 ressources, **zéro chaîne en dur** |
| `outputs.tf` | les 3 outputs |

## 5. Commandes et contrôles

```bash
cp ../../../terraform/clouds.yaml .      # ou votre propre clouds.yaml
terraform init
terraform fmt
terraform validate
terraform plan                            # attendu : 11 to add
terraform apply
terraform output
ping <ip_flottante>                       # ~1 min après l'apply

```

