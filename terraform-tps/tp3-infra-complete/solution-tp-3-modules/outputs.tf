# Le root re-expose les sorties des modules

output "vm1_ip_flottante" {
  description = "IP flottante de VM1"
  value       = module.vm1.floating_ip
}

output "vm1_url" {
  description = "Page nginx par défaut de VM1"
  value       = "http://${module.vm1.floating_ip}"
}

output "vm1_ip_privee" {
  description = "IP de VM1 sur network-public"
  value       = module.vm1.private_ip
}

output "vm2_ip_privee" {
  description = "IP de VM2 sur network-private"
  value       = module.vm2.private_ip
}

output "test_ping" {
  description = "À lancer depuis VM1 pour valider le routage inter-réseaux"
  value       = "ssh ubuntu@${module.vm1.floating_ip} puis : ping -c 3 ${module.vm2.private_ip}"
}
