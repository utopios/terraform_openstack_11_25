# Lab OpenStack AIO pour Mac Apple Silicon (Parallels Desktop)

Equivalent du lab VirtualBox x86 de la racine (`../Vagrantfile`), pour le poste formateur.
Memes adresses : API/Horizon `192.168.56.250`, VM `192.168.56.10`, IP flottantes `192.168.57.100-200`
joignables directement depuis le Mac (`192.168.57.1`).

```bash
vagrant up --provider=parallels      # ~45 min (Kolla-Ansible), clouds.yaml genere dans terraform/
vagrant ssh -c 'sudo bash /vagrant/scripts/05-swift-host.sh'   # optionnel : Swift pour la demo 04
vagrant halt / vagrant up            # arret / redemarrage (les conteneurs Kolla reviennent seuls)
```

Puis copier `terraform/clouds.yaml` dans le dossier de la demo a tester, comme pour le lab x86.

## Differences avec le lab des stagiaires (OVA x86 / VirtualBox)

| | Stagiaires (OVA) | Ce lab |
|---|---|---|
| Hote / box | Ubuntu 22.04 x86_64 | Ubuntu 24.04 arm64 (`bento/ubuntu-24.04`) |
| OpenStack | 2024.1 Caracal (Kolla 18.x) | 2025.1 Epoxy (Kolla 20.x) : quay.io ne publie plus les images 2024.1 |
| Images Kolla | ubuntu-jammy | debian-bookworm-aarch64 (seules images arm64 publiees) |
| Nova | QEMU (TCG) | QEMU (TCG), modele CPU `cortex-a72`, `force_config_drive` (cloud-init arm64) |
| Swift | Kolla | paquets Ubuntu, hors Kolla (`scripts/05-swift-host.sh`) |
| Images Glance pour TP2/TP3 | `*-amd64.img` | passer `*-arm64.img` via `-var image_url=...` |

Le KVM imbrique de Parallels expose `/dev/kvm` mais les instances plantent dans le firmware UEFI :
laisser Nova en `qemu` (`VIRT_TYPE=kvm vagrant provision` pour re-essayer).
