# TP 4 — Créer son premier module : `network` ★★

## Contexte

Vous venez de voir en démo le module `compute` : la VM, son port, sa keypair
et son IP flottante sont encapsulés dans `modules/compute/`, et le fichier
racine ne fait plus que l'appeler. Mais le réseau, le sous-réseau et le
routeur sont encore écrits « en dur » dans `main.tf` racine, et ils seront
identiques dans chaque projet.

Votre mission : **extraire le socle réseau dans un module `network`**, sur le
même modèle que `compute`, puis brancher les deux modules l'un sur l'autre.

## Point de départ

Copiez la démo dans un nouveau dossier de travail :

```bash
cp -r 3-demo-modules/01-module-compute tp2-module-network
cd tp2-module-network
rm -rf .terraform terraform.tfstate*      # repartir d'un état vide
```

Vous avez :

```
tp2-module-network/
├── main.tf              ← réseau, subnet, routeur, SG en dur + module "vm"
├── modules/
│   └── compute/         ← le module vu en démo, à NE PAS modifier
├── data.tf, locals.tf, variables.tf, terraform.tfvars, outputs.tf, ...
```

Avant de toucher au code, changez le préfixe dans `locals.tf` (`tp4`) et le
CIDR dans `terraform.tfvars` (`10.44.1.0/24`) pour ne pas entrer en conflit
avec les démos.

## Objectif final

```
main.tf racine
   ├── module "network"  ──► network_id, subnet_id ──┐
   ├── security group (reste inline)                 │
   └── module "vm"  ◄─────────────────────────────────┘
```

`terraform apply` crée exactement la même infrastructure qu'avant (une VM
CirrOS joignable en SSH par IP flottante), mais le `main.tf` racine ne
contient plus aucune ressource `openstack_networking_network_v2`,
`subnet_v2`, `router_v2` ni `router_interface_v2`.

---

## Étape 1 — Le squelette du module (10 min)

Un module est un dossier avec des fichiers `.tf`. Créez :

```
modules/network/
├── versions.tf      ← déclare le provider requis (copiez celui de compute)
├── variables.tf     ← les ENTRÉES du module
├── main.tf          ← les ressources
└── outputs.tf       ← les SORTIES du module
```

> Un module ne contient **jamais** de bloc `provider` ni de `clouds.yaml` :
> il hérite du provider configuré par la racine. Il déclare seulement, dans
> `versions.tf`, de quel provider il a besoin (bloc `required_providers`
> avec `source`, sans `version`).

✅ **Contrôle 1** : `terraform validate` passe encore (le module existe mais
n'est pas appelé, c'est normal).

## Étape 2 — Les entrées (15 min)

Regardez les quatre ressources réseau du `main.tf` racine et listez tout ce
qui vient de l'extérieur : une variable, un local, un data source. Ce sont
les entrées du module.

Vous devez aboutir à **quatre variables** dans `modules/network/variables.tf` :

| Variable | Type | Pourquoi |
|---|---|---|
| `name` | `string` | nom de base, les noms `-net`, `-subnet`, `-router` en dérivent |
| `cidr` | `string` | le sous-réseau |
| `dns_nameservers` | `list(string)` | avec une valeur par défaut `["8.8.8.8"]` |
| `external_network_id` | `string` | l'**ID** du réseau externe, pas son nom |

Chaque variable a un `type` et une `description`.

> Question piège : pourquoi passer l'`external_network_id` plutôt que de
> mettre le `data "openstack_networking_network_v2"` dans le module ?
> Réponse attendue : un module doit recevoir ce dont il a besoin, pas aller
> le chercher. La racine fait le `data`, le module reçoit l'id. Le module
> reste ainsi utilisable même si le réseau externe s'appelle autrement.

## Étape 3 — Les ressources (15 min)

Déplacez (couper-coller) les quatre ressources réseau depuis le `main.tf`
racine vers `modules/network/main.tf`, puis adaptez-les :

- remplacez `local.net_name` par `"${var.name}-net"`, idem subnet et router ;
- remplacez `var.subnet_cidr` par `var.cidr` ;
- remplacez `data.openstack_networking_network_v2.public.id` par
  `var.external_network_id` ;
- renommez les ressources `this` (convention des modules : une ressource
  principale par type s'appelle `this`).

> Le module ne connaît ni `local.*` de la racine, ni `data.*` de la racine,
> ni `var.*` de la racine. Tout ce qu'il utilise doit être une de SES
> variables ou une de SES ressources. `terraform validate` vous le rappellera.

✅ **Contrôle 2** : `terraform validate` depuis la racine renvoie
« Success ». Si vous avez une erreur « Reference to undeclared input
variable », une entrée manque à l'étape 2.

## Étape 4 — Les sorties (10 min)

Le module `compute` a besoin de deux choses du réseau : `network_id` et
`subnet_id`. Ajoutez-les dans `modules/network/outputs.tf`.

Ajoutez une troisième sortie, `router_interface_id`. Elle ne sert à rien en
valeur, mais elle permettra à la racine d'exprimer « la VM se crée après le
raccordement du routeur ».

Chaque output a une `description`.

## Étape 5 — Appeler le module depuis la racine (15 min)

Dans le `main.tf` racine, ajoutez un bloc `module "network"` avec
`source = "./modules/network"` et les quatre entrées. Puis modifiez l'appel
de `module "vm"` :

- `network_id` et `subnet_id` doivent venir du module network ;
- `depends_on` ne peut plus pointer sur `openstack_networking_router_interface_v2.iface`
  (elle n'existe plus à la racine) : pointez sur le module entier.

```bash
terraform init          # OBLIGATOIRE : un nouveau module = terraform init
terraform validate
terraform plan
```

✅ **Contrôle 3** : le plan annonce **12 to add**, avec des adresses de la
forme `module.network.openstack_networking_network_v2.this` et
`module.vm.openstack_compute_instance_v2.this`. Plus aucune ressource réseau
à la racine.

> Oubli classique : `terraform init` après avoir ajouté un bloc `module`.
> Sans lui : « Module not installed ».

## Étape 6 — Déployer et vérifier (10 min + boot)

```bash
terraform apply
terraform output
ping <ip_flottante>
ssh cirros@<ip_flottante>
```

✅ **Contrôle 4** : SSH fonctionne. Dans Horizon, réseau `tp2-net`, routeur
`tp2-router` branché sur `public`, VM `tp2-vm`.

```bash
terraform state list     # observez les préfixes module.network. et module.vm.
terraform destroy
```



- Documentation des modules : https://developer.hashicorp.com/terraform/language/modules/develop
