# RHEL 9 Configuration & Golden-Image Pipeline

Ansible-driven build/test/bake pipeline for RHEL 9 (AlmaLinux 9) systems. The
playbook assembles a growing set of RHEL technologies onto a base image and the
pipeline proves each change works before it becomes a golden image.

CIS hardening is the first component; the same pipeline is designed to carry
additional roles over time (e.g. KVM/virtualization host setup, Cockpit, chrony,
and other platform services) without structural change — you add a role to the
playbook and it flows through both tiers below automatically.

## Pipeline tiers (both GitHub Actions)

| Tier | Workflow | Runner | What it does |
|------|----------|--------|--------------|
| **CI** | `.github/workflows/ci.yml` | GitHub-hosted | Molecule + Podman applies the playbook to an AlmaLinux 9 container, runs `molecule verify` and any role-provided audits. Gates every PR — fast feedback on config correctness. |
| **Bake** | `.github/workflows/bake.yml` | Self-hosted (KVM) | After merge to `main`: Packer boots the official AlmaLinux 9 cloud image on KVM, applies the **same** playbook to a real VM, runs the audits, and produces a versioned **golden qcow2**. |

Two tiers because a container can validate most configuration quickly, but only a
real VM can exercise things that need a true kernel/boot/services environment
(sysctl, kernel modules, virtualization, systemd units). Both tiers run the same
`playbooks/playbook.yml` + `requirements.yml` + `sysconfig/` vars — no logic is
duplicated per tier.

## Repo layout

- `playbooks/playbook.yml` — the top-level playbook (includes each component role).
- `requirements.yml` — roles + collections the playbook depends on.
- `sysconfig/` — inventory and production group_vars shared by both tiers.
- `molecule/default/` — container test scenario (CI tier).
- `packer/` — QEMU golden-image build (bake tier).

## Components

| Component | Status | Notes |
|-----------|--------|-------|
| CIS hardening (RHEL9-CIS) | active | Level 1 server profile applied and audited. |
| _future: KVM host, Cockpit, chrony, …_ | planned | Add as roles under `requirements.yml` + `playbooks/playbook.yml`; they inherit both CI and bake automatically. |

Adding a component: add its role to `requirements.yml`, include it in
`playbooks/playbook.yml` (tagged so it can be scoped), and — if it has
container-incompatible steps — guard those in `molecule/default/host_vars/` only.

## Bake tier prerequisites (one-time)

The bake runs on a **self-hosted, KVM-capable** runner (any Linux host with
`/dev/kvm` and a CPU exposing x86-64-v2 — required to boot EL9 guests).

1. **Register the runner** with labels `self-hosted,kvm`
   (repo Settings → Actions → Runners → New self-hosted runner; run as a service).
2. **Install tooling** on that host: `packer`, `qemu-kvm`/`qemu-img`, `libvirt`,
   `ansible-core`. Add the runner user to the `kvm` (and `libvirt`) groups.
3. *(Optional)* Define a libvirt pool named `cis` over `~/cis-golden-images` so
   baked images register automatically:
   ```
   virsh pool-define-as cis dir --target ~/cis-golden-images
   virsh pool-autostart cis && virsh pool-start cis
   ```
   Without it, images are still written to `~/cis-golden-images`.

The base cloud image is pinned by checksum (`packer/variables.pkr.hcl`) and cached
between runs, so it's re-downloaded only when that checksum changes.

## Local bake test

On a KVM host, before wiring the runner:

```
ansible-galaxy install -r requirements.yml
ssh-keygen -t ed25519 -N "" -f /tmp/bake_key
packer init packer/
packer build \
  -var "ssh_public_key=$(cat /tmp/bake_key.pub)" \
  -var "ssh_private_key_file=/tmp/bake_key" \
  packer/
```

Output: a golden qcow2 in `./output/` plus any audit reports fetched to
`/tmp/cis-bake-audit/`.
