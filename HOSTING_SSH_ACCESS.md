# Hosting SSH Access

This file describes how to connect from the current MacBook/macOS machine to the Hoster.KZ cloud server over SSH.

## Server

- Provider: Hoster.KZ
- Server name: `cloud-001.h-152115.kz`
- IP address: `188.244.115.77`
- SSH user: `root`
- SSH port: `22`

Do not commit the server password to this repository. Keep it in a password manager or the original provider message, and enter it only when `ssh` asks for it interactively.

## Connect From macOS

Open Terminal and check that SSH is available:

```bash
ssh -V
```

Optionally check that the SSH port is reachable:

```bash
nc -vz 188.244.115.77 22
```

Connect to the server:

```bash
ssh root@188.244.115.77
```

On the first connection, SSH may ask whether to trust the server host key:

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

If the IP address is correct and the host key fingerprint is expected, type `yes`. SSH will save the host key in `~/.ssh/known_hosts`. When prompted for the password, enter the password from the Hoster.KZ access message. The password will not be shown while typing.

## Recommended: Add an SSH Key

After the first password login, add a local SSH key so future logins do not require typing the server password.

Generate a dedicated key if you do not already have one for this server:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/oldwhale_hoster_kz -C "oldwhale hoster.kz"
```

Install the public key on the server. This command will ask for the server password one last time:

```bash
ssh root@188.244.115.77 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" < ~/.ssh/oldwhale_hoster_kz.pub
```

Add a local SSH config alias:

```bash
cat >> ~/.ssh/config <<'EOF'

Host oldwhale-hoster
  HostName 188.244.115.77
  User root
  Port 22
  IdentityFile ~/.ssh/oldwhale_hoster_kz
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config
```

Connect with the alias:

```bash
ssh oldwhale-hoster
```

## Troubleshooting

- `Permission denied`: confirm that the username is `root`, the password is current, or the SSH key was installed correctly.
- `Operation timed out`: check the IP address, network connectivity, and whether port `22` is open on the hosting firewall.
- `REMOTE HOST IDENTIFICATION HAS CHANGED`: stop and verify the server identity with the provider before removing any `known_hosts` entry.

