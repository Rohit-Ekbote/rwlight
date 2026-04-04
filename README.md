# rwlight

Lightweight RunWhen platform for small VMs (4 CPU / 8 GB RAM).

## Quick Start

### macOS

```bash
# Install Lima
brew install lima

# Create VM (defaults: 4 CPU, 10 GiB RAM, 80 GiB disk)
./rwlight-vm create

# SSH into the VM
./rwlight-vm ssh

# Inside the VM, run setup
cd /path/to/rwlight
./setup/setup.sh
```

### Linux

```bash
# Run setup directly (requires 4+ CPU, 8+ GB RAM)
./setup/setup.sh
```

## VM Management (macOS only)

```bash
./rwlight-vm create              # Create VM
./rwlight-vm create --cpus 6 --memory 12  # Custom resources
./rwlight-vm ssh                 # SSH into VM
./rwlight-vm status              # Check VM status
./rwlight-vm stop                # Stop VM
./rwlight-vm start               # Start stopped VM
./rwlight-vm delete              # Delete VM
```

## What's different from RWDev

rwlight is a resource-optimized variant of RWDev targeting smaller VMs:

- Mimir runs in monolithic mode (1 pod instead of 20)
- Single shared Redis sentinel cluster (3 pods instead of 10)
- Ingress-nginx scaled to 1 replica
- All workloads right-sized for actual usage
- macOS support via Lima VM

See `docs/superpowers/specs/2026-04-02-rwlight-design.md` for the full design.
