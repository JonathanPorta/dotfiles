# GPG + YubiKey Setup Guide

How to generate a GPG key and move it onto a YubiKey for signing git commits and SSH authentication.

> **Goal:** Malware cannot silently sign commits or SSH into anything without your physical presence. Daily-use private key material lives on the YubiKey. Signing and authentication both require **PIN + physical touch** on every use.

> **Authentication model:** GPG on YubiKey uses **PIN + physical touch**, not biometrics. YubiKey's fingerprint reader (Bio edition) is FIDO2-only and does not apply to OpenPGP. If biometrics matter more than GPG, consider SSH commit signing with a FIDO2 flow instead.

---

## Threat Model

| Threat | Control |
|---|---|
| Malware silently signs a commit | YubiKey `sig` touch policy `fixed` + PIN always |
| Malware silently SSHes into a server | YubiKey `aut` touch policy `fixed` + short SSH cache TTL |
| Unsigned commit pushed to GitHub | GitHub ruleset: **Require signed commits** |
| YubiKey stolen, PIN unknown | PIN lockout after 3 attempts |
| YubiKey dies | Rotate keys, create new YubiKey. Backups exist separately for the master key only. |

**Caveat:** Touch stops *blind* malware. It does not stop malware that acts *while you are present* and tricks you into touching the key for the wrong thing. Physical presence is a strong gate, not magic.

---

## Prerequisites

- A **YubiKey 5** series (or any YubiKey with OpenPGP support)
- `gpg2` installed (`brew install gnupg` on macOS, `dnf install gnupg2` on Fedora)
- `pinentry-mac` on macOS (`brew install pinentry-mac`) or `pinentry-curses` on Linux
- `ykman` (YubiKey Manager) — **required** for touch/PIN policy (`brew install ykman`)

Verify GPG is working:
```bash
gpg --version
# Should show 2.x
```

Verify YubiKey is detected:
```bash
gpg --card-status
```

---

## Step 1: Install GPG and Configure

GPG packages and configuration are managed by this dotfiles repo via `installation/gpg.sh`. This script:
- Installs `gnupg`, `pinentry-mac` (macOS) or `pinentry-curses` (Linux), and `ykman`
- Symlinks `dotfiles/gpg.conf` → `~/.gnupg/gpg.conf` (strong algorithm defaults, long key IDs)
- Copies `dotfiles/gpg-agent.conf` → `~/.gnupg/gpg-agent.conf` (SSH support, aggressive cache TTLs)
- On macOS, automatically appends `pinentry-program` pointing to `pinentry-mac`

If you've already run `init.sh` followed by `run.sh`, everything is in place. Otherwise:

```bash
$HOME/devel/$USER/dotfiles/installation/gpg.sh
```

The `gpg-agent.conf` is configured for minimal caching:
```conf
enable-ssh-support
default-cache-ttl 60          # 1 minute
max-cache-ttl 300              # 5 minutes
default-cache-ttl-ssh 60       # 1 minute for SSH
max-cache-ttl-ssh 300          # 5 minutes for SSH
ignore-cache-for-signing       # always prompt for signing PIN
```

Restart the agent:
```bash
gpgconf --kill gpg-agent
gpg-connect-agent /bye
```

---

## Step 2: Generate the Master Key (Certify Only)

Generate a master key that can **only certify** (sign other keys). This key will be backed up offline and should not be stored on the YubiKey.

```bash
gpg --expert --full-generate-key
```

Choose:
1. **(8) RSA (set your own capabilities)** — toggle off everything except **Certify**
2. Key size: **4096**
3. Expiration: **0** (does not expire) or **2y** (your call)
4. Real name: `Jonathan Porta`
5. Email: `jonathan@jonathanporta.com`
6. Passphrase: **use a strong passphrase** — only needed for key management, not daily use

Note the key ID from the output:
```
pub   rsa4096/0xABCD1234ABCD1234 2026-04-09 [C]
```

```bash
export KEYID=0xABCD1234ABCD1234
```

---

## Step 3: Add Subkeys

Add two subkeys for daily use on the YubiKey:

```bash
gpg --expert --edit-key $KEYID
```

### 3a. Signing subkey
```
gpg> addkey
# (8) RSA (set your own capabilities) → toggle to Sign only
# Key size: 4096
# Expiration: 1y (you can extend later)
```

### 3b. Authentication subkey (for SSH)
```
gpg> addkey
# (8) RSA (set your own capabilities) → toggle to Authenticate only
# Key size: 4096
# Expiration: 1y
```

> **Note:** Encryption subkey is optional. If you don't need GPG-encrypted email or files, skip it. Fewer keys = less to manage.

Save:
```
gpg> save
```

Verify:
```bash
gpg -K $KEYID
# Should show [C], [S], [A] subkeys
```

---

## Step 4: Back Up Your Keys

**Before moving keys to the YubiKey** (this is destructive — keys are moved, not copied):

```bash
# Export secret master key + subkeys
gpg --armor --export-secret-keys $KEYID > master-key-backup.asc

# Export secret subkeys separately
gpg --armor --export-secret-subkeys $KEYID > subkeys-backup.asc

# Export public key
gpg --armor --export $KEYID > public-key.asc

# Export ownertrust
gpg --export-ownertrust > ownertrust.txt
```

**Store these files securely offline** (encrypted USB, password manager, safe deposit box — not on your laptop). If the YubiKey dies, you'll create a new one. These backups let you re-certify new subkeys with the master.

---

## Step 5: Move Subkeys to YubiKey

```bash
gpg --edit-key $KEYID
```

### Move the Signing key:
```
gpg> key 1          # select the signing subkey
gpg> keytocard
# Choose: (1) Signature key
```

### Move the Authentication key:
```
gpg> key 1          # deselect
gpg> key 2          # select auth subkey
gpg> keytocard
# Choose: (3) Authentication key
```

Save:
```
gpg> save
```

Verify the keys show `ssb>` (the `>` means "on card"):
```bash
gpg -K $KEYID
# sec   rsa4096/0xABCD... [C]
# ssb>  rsa4096/...       [S]
# ssb>  rsa4096/...       [A]
```

---

## Step 6: Harden the YubiKey

### Change PINs (required — defaults are well-known)

```bash
gpg --card-edit
```
```
gpg/card> admin
gpg/card> passwd
# 1 - change PIN (default: 123456) — used for daily signing/auth
# 3 - change Admin PIN (default: 12345678) — used for key management
gpg/card> quit
```

### Require touch for every operation (non-negotiable)

Use `fixed` — touch is mandatory and **cannot be disabled without deleting the private key**. Do NOT use `on` (can be turned off) or `cached`/`cached-fixed` (allows 15-second reuse window).

```bash
# Signing — every commit requires a touch
ykman openpgp keys set-touch sig fixed

# Authentication — every SSH connection requires a touch
ykman openpgp keys set-touch aut fixed
```

### Require PIN for every signature

```bash
ykman openpgp access set-signature-policy always
```

### Set cardholder info (optional)
```bash
gpg --card-edit
```
```
gpg/card> admin
gpg/card> name
# Surname: Porta
# Given name: Jonathan

gpg/card> login
# jonathan@jonathanporta.com

gpg/card> quit
```

---

## Step 7: Configure Git Signing

The dotfiles `generate_gitconfig.sh` already sets `gpg.program = gpg2` and has `commit.gpgsign` and `tag.gpgsign` ready to uncomment.

### Get your signing subkey ID:
```bash
gpg -K --keyid-format long
# Look for the [S] subkey
```

### Enable signing in dotfiles:

Edit `dotfiles/helpers/generate_gitconfig.sh` — uncomment and set the signing key and gpgsign lines:

```ini
[user]
  name = Jonathan Porta
  email = jonathan@jonathanporta.com
  signingkey = 0xYOUR_SIGNING_SUBKEY_ID!

[commit]
  gpgsign = true

[tag]
  gpgsign = true
```

> **The `!` suffix** tells Git to use that exact subkey rather than letting GPG choose. See [GitHub docs](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key).

Re-source to regenerate:
```bash
source ~/.helpers/generate_gitconfig.sh
```

### Verify signing works:
```bash
echo "test" | gpg --clearsign
# Should prompt for YubiKey PIN + touch
```

---

## Step 8: Upload Public Key to GitHub

```bash
# Copy GPG public key to clipboard
gpg --armor --export $KEYID | pbcopy   # macOS

# Copy SSH public key (from the auth subkey)
gpg --export-ssh-key $KEYID | pbcopy   # macOS
```

Add both to GitHub:
- **GPG key:** GitHub → Settings → SSH and GPG keys → New GPG key
- **SSH key:** GitHub → Settings → SSH and GPG keys → New SSH key

---

## Step 9: Enforce Signed Commits on GitHub (Server-Side)

Local signing defaults can be bypassed (`--no-gpg-sign`, another machine, editing `.gitconfig`). **Server-side enforcement is required.**

### Option A: Branch Protection Rules
1. Repository → **Settings → Branches → Branch protection rules → Add rule**
2. Branch name pattern: `main` (or `**` for all branches)
3. Check **Require signed commits**

### Option B: Repository Rulesets (recommended)
1. Repository → **Settings → Rules → Rulesets → New ruleset**
2. Add the **Require signed commits** rule
3. Target: **Default branch** or all branches

GitHub rejects any push containing unsigned or unverified commits to the protected branch. See [GitHub docs on rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).

---

## Step 10: SSH Authentication via YubiKey

Your `.profile` already configures `gpg-agent` with SSH support. To get your SSH public key:

```bash
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

# Get the SSH public key
ssh-add -L
# or
gpg --export-ssh-key $KEYID
```

Add the SSH public key output to `authorized_keys` on any machines you need access to.

---

## Day-to-Day Usage

### Signing a commit
```bash
git commit -m "signed commit"
# 1. Enter YubiKey PIN when prompted
# 2. Touch the YubiKey when it blinks
```

### SSH into a server
```bash
ssh user@host
# Touch the YubiKey when it blinks
```

### Verify it's working
```bash
gpg --card-status             # GPG sees the card
ssh-add -L                    # SSH agent sees the key
echo "test" | gpg --clearsign # Signing works (PIN + touch)
git log --show-signature -1   # Commit is signed
```

---

## Troubleshooting

### "No secret key" or "No card"
```bash
gpg_reboot  # alias from .profile

# Or manually:
gpgconf --kill gpg-agent
gpg-connect-agent /bye
```

### SSH not using YubiKey
```bash
echo $SSH_AUTH_SOCK
# Should be: ~/.gnupg/S.gpg-agent.ssh
# NOT: /private/tmp/com.apple.launchd.xxx/Listeners
```

### PIN blocked after too many wrong attempts
```bash
gpg --card-edit
gpg/card> admin
gpg/card> passwd
# Option 2: unblock and set new user PIN
```

### Moving to a new machine
```bash
# Import public key
gpg --import public-key.asc

# Tell GPG to look at the card
gpg --card-status

# Trust the key
gpg --edit-key $KEYID
gpg> trust
# 5 (ultimate)
gpg> quit
```

Then run `init.sh` → `run.sh` to install GPG config, helpers, and signing defaults.

### YubiKey dies or is lost
1. Revoke the old subkeys using your offline master key backup
2. Generate new subkeys, move them to a new YubiKey
3. Update GitHub with the new GPG/SSH public keys
4. This is a legitimate operational model, not a failure

---

## Enforcement Summary

| Layer | What it does | Bypassable? |
|---|---|---|
| `generate_gitconfig.sh` | `commit.gpgsign = true`, `tag.gpgsign = true` | Yes — `--no-gpg-sign`, editing config, other machine |
| YubiKey touch `fixed` | Physical touch for every sig and auth | No — hardware-enforced, cannot be turned off |
| YubiKey PIN `always` | PIN required for every signature | No — hardware-enforced |
| `ignore-cache-for-signing` | Agent never caches signing PIN | No — agent-enforced |
| Short SSH cache TTLs (60s/300s) | Minimizes session reuse window | No — agent-enforced |
| GitHub ruleset | Rejects unsigned pushes | No — server-enforced |

**All layers together:** every commit is signed, signing requires your YubiKey (possession), the YubiKey requires your PIN (knowledge) and your touch (presence), the agent never caches signing credentials, and the server rejects anything unsigned.

---

## References

- [YubiKey Guide (drduh)](https://github.com/drduh/YubiKey-Guide) — the definitive reference
- [ykman OpenPGP commands (Yubico docs)](https://docs.yubico.com/software/yubikey/tools/ykman/OpenPGP_Commands.html) — touch policies, PIN policies
- [GPG Agent Options (GnuPG docs)](https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html) — cache TTLs, ignore-cache-for-signing
- [GPG + Git signing (GitHub docs)](https://docs.github.com/en/authentication/managing-commit-signature-verification)
- [Telling Git about your signing key (GitHub docs)](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key)
- [Available rules for rulesets (GitHub docs)](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
