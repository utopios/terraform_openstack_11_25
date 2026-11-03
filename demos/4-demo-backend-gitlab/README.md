# Démo — Backend GitLab : un code, 3 backends, 3 tfvars

Démo volontairement minimale (`null_resource`, aucune infrastructure réelle)
pour se concentrer sur **la mécanique de l'état distant** : un seul dossier de
code, trois environnements qui ne diffèrent que par leur fichier de backend
et leur fichier de variables.

```
demo-backend-gitlab/
├── main.tf             # null_resource avec triggers + local-exec
├── variables.tf
├── outputs.tf
├── versions.tf         # backend "http" {} VIDE -> configuration partielle
├── .gitlab-ci.yml      # pipeline : fmt/validate -> plan x3 -> apply dev/staging/prod -> destroy
├── backends/
│   ├── dev.hcl         # état GitLab "null-dev"
│   ├── staging.hcl     # état GitLab "null-staging"
│   └── prod.hcl        # état GitLab "null-prod"
└── tfvars/
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

## Où vit l'état ?

Dans le **stockage d'états Terraform de GitLab** du projet
[`mohamed.aijjou1780/backend`](https://gitlab.com/mohamed.aijjou1780/backend)
(ID 84876184) — PAS dans les fichiers git du dépôt : GitLab expose une API
dédiée (`/projects/84876184/terraform/state/<nom>`) avec **verrouillage**
(deux `apply` simultanés sont impossibles). Les états sont visibles dans le
projet : **Operate → Terraform states** (`null-dev`, `null-staging`,
`null-prod`).

## Authentification — JAMAIS dans le code

Le username est dans les `.hcl` (pas un secret). Le PAT (scope `api`) passe
par une variable d'environnement, à définir dans votre terminal :

```powershell
$env:TF_HTTP_PASSWORD = "<votre PAT>"
```

```bash
export TF_HTTP_PASSWORD="<votre PAT>"
```

## Exécution

Le backend est choisi au moment du **init**, les valeurs au moment du
**plan/apply**. Toujours les deux fichiers du MÊME environnement :

```bash
terraform init -reconfigure -backend-config=backends/dev.hcl
terraform apply -var-file=tfvars/prod.tfvars
```

Pour changer d'environnement, on ré-initialise (c'est le `-reconfigure` qui
rebranche le backend) :

```bash
terraform init -reconfigure -backend-config=backends/staging.hcl
terraform apply -var-file=tfvars/staging.tfvars
```

```bash
terraform init -reconfigure -backend-config=backends/prod.hcl
terraform apply -var-file=tfvars/prod.tfvars
```

## ⚠️ La limite de ce pattern (à bien comprendre)

Le dossier n'a qu'UN backend actif à la fois (celui du dernier `init`).
Le danger classique : être initialisé sur **prod** et lancer
`apply -var-file=tfvars/dev.tfvars` → les valeurs de dev écrasent l'état de
prod. Rien ne vous en protège à part la discipline (toujours enchaîner
init + apply du même env, vérifier `terraform output environnement` avant
d'agir). C'est pour cette raison que le pattern « un dossier par
environnement » (cf. `demo-environnements/`) est recommandé en équipe ;
celui-ci reste pratique pour un usage solo ou piloté par une CI (où chaque
job fait son propre init).

## À observer pendant la démo

- Après chaque apply : l'état apparaît dans GitLab (Operate → Terraform states).
- Relancez `apply` sans rien changer : `0 to add` — l'état distant fait foi.
- Changez `message` dans un tfvars puis `apply` : le `null_resource` est
  **remplacé** (ses `triggers` ont changé) et le `local-exec` réaffiche le
  nouveau message.
- Pendant un `apply`, tentez-en un second dans un autre terminal : refusé,
  l'état est **verrouillé** par GitLab.

## Pipeline GitLab CI (`.gitlab-ci.yml`)

Le pattern « un code, trois backends » prend tout son sens en CI : **chaque
job fait son propre `init -reconfigure`** sur le backend de son `ENV`, puis
plan ou apply avec le tfvars du même `ENV`. L'erreur « init prod + apply
dev » devient impossible.

```
validate ─► plan (dev | staging | prod, en parallèle) ─► apply:dev (auto)
                                                        └► apply:staging (manuel)
                                                            └► apply:prod (manuel)
destroy (dev | staging | prod) : manuel uniquement
```

| Job | Quand | Ce qu'il fait |
|---|---|---|
| `fmt`, `validate` | MR et branche par défaut | `fmt -check`, `init -backend=false`, `validate` |
| `plan` ×3 | MR et branche par défaut | `plan -out=tfplan-ENV`, le plan lisible est un **artefact** |
| `apply:dev` | branche par défaut, auto | `apply tfplan-dev` : rejoue exactement le plan approuvé |
| `apply:staging` / `apply:prod` | branche par défaut, **bouton manuel**, après l'env précédent | idem, avec `environment:` (visible dans Operate → Environments) |
| `destroy` ×3 | manuel | `destroy -auto-approve` |

Points à montrer :

- **`-out=tfplan` puis `apply tfplan`** : ce qui est appliqué est ce qui a
  été relu dans la MR, pas un nouveau plan calculé plus tard.
- **`resource_group: ${ENV}`** : GitLab sérialise les jobs d'un même env,
  en plus du verrou d'état côté backend.
- **`needs`** : staging attend dev, prod attend staging. Une promotion.
- **Authentification sans secret dans le code** : par défaut le job utilise
  `CI_JOB_TOKEN` (états dans le même projet). Si les états sont dans un autre
  projet (ici `backend`, 84876184), définir une variable CI/CD **masquée**
  `GITLAB_TF_TOKEN` (PAT scope `api`) dans Settings → CI/CD → Variables.
- Le `.hcl` fixe `username = ...` : le job le surcharge par un second
  `-backend-config="username=..."`, le dernier gagne.

Mise en place :

1. Pousser ce dossier comme projet GitLab (le `.gitlab-ci.yml` est alors à la
   racine), ou depuis le dépôt complet créer un `.gitlab-ci.yml` racine avec
   `include: { local: demo-backend-gitlab/.gitlab-ci.yml }`.
2. Si besoin, créer la variable `GITLAB_TF_TOKEN`.
3. Ouvrir une MR : `fmt`, `validate` et les trois `plan` tournent, les plans
   sont téléchargeables dans les artefacts.
4. Merger : `apply:dev` part seul, `apply:staging` puis `apply:prod`
   attendent un clic. L'état apparaît dans Operate → Terraform states.
