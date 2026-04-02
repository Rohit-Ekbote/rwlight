# 1️⃣ Identify your disk

Check all attached disks:
```sh
lsblk
```

Example output:
```sh
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   10G  0 disk
└─sda1   8:1    0   10G  0 part /
sdb      8:16   0  256G  0 disk
```

`/dev/sda` → boot disk

`/dev/sdb` → your 256 GB disk (unmounted)

---
# 2️⃣ Format the disk

We need to create a filesystem. I’ll use ext4 (common choice):
```sh
sudo mkfs.ext4 /dev/sdb
```
⚠ Warning: this erases all data on /dev/sdb.

You can label the disk (optional):
```sh
sudo e2label /dev/sdb k3d-disk
```

---
# 3️⃣ Create a mount point

Decide where you want to mount the disk, e.g.:
```sh
sudo mkdir -p /mnt/k3d-disk
```

`/mnt/k3d-disk` is the directory that will represent the disk in the filesystem.

---
# 4️⃣ Mount the disk
```sh
sudo mount /dev/sdb /mnt/k3d-disk
```
Verify:
```sh
df -h /mnt/k3d-disk
```
You should see ~256 GB available.

---
# 5️⃣ Make it permanent
To mount automatically on reboot, add it to /etc/fstab:
```sh
sudo nano /etc/fstab
```
Add the line:
```sh
/dev/sdb  /mnt/k3d-disk  ext4  defaults  0  2
```
Test without reboot:
```sh
sudo umount /mnt/k3d-disk
systemctl daemon-reload
sudo mount -a
df -h /mnt/k3d-disk
```

---
# 6️⃣ Set permissions
Docker (or your helper scripts) must write to this disk. Either:

- **Allow all users to write**:
```sh
sudo chmod 777 /mnt/k3d-disk
```

- **Or chown to your user**:
```sh
sudo chown $USER:$USER /mnt/k3d-disk
```

---
# Move Docker’s storage to the new disk
```sh
sudo systemctl stop docker

# Move existing Docker data (optional)
sudo rsync -aP /var/lib/docker/ /mnt/k3d-disk/docker/

# Configure Docker to use the new location
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "data-root": "/mnt/k3d-disk/docker",
  "dns": ["8.8.8.8", "1.1.1.1"]
}
EOF

# Start Docker
sudo systemctl start docker

# Verify
docker info | grep "Docker Root Dir"
```
