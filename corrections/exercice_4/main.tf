# Corrigé — Exercice "Templates et fonctions intégrées" (support p.32)
# Aucun provider nécessaire : variables, fonctions, templatefile et outputs.
#   terraform init && terraform apply -auto-approve
#   terraform apply -auto-approve -var='names=["Ihab","Sara"]'

variable "names" {
  description = "Liste de noms"
  type        = list(string)
  default     = ["Alice", "Bob", "Charlie"]
}

# 1. Combiner les noms en une seule chaîne séparée par des virgules
output "names_joined" {
  description = "join() : liste -> chaîne"
  value       = join(", ", var.names)
}

# 2. Compter le nombre de noms
output "names_count" {
  description = "length() : taille de la liste"
  value       = length(var.names)
}

# 3. Rendre example.tpl ("Hello, ${name}!") pour chaque nom de la liste.
#    templatefile() rend UN fichier avec UN jeu de variables : pour l'appliquer
#    à chaque nom, on le place dans une expression for.
output "greetings" {
  description = "templatefile() appelé pour chaque nom"
  value       = [for n in var.names : templatefile("${path.module}/example.tpl", { name = n })]
}

# Variante : les trois salutations en un seul texte, prêt pour un user_data
# ou un fichier (trimspace retire le saut de ligne final du template).
output "greetings_text" {
  value = join("\n", [for n in var.names : trimspace(templatefile("${path.module}/example.tpl", { name = n }))])
}
