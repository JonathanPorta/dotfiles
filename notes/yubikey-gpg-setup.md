# GPG + YubiKey Setup Guide

How to generate a GPG key and move it onto a YubiKey for signing git commits and SSH authentication.

> **Goal:** A single YubiKey that handles git commit signing, SSH auth, and (optionally) email encryption — with the private key material living exclusively on the hardware token.

---

## Prerequisites

- A **YubiKey 5** series (or any YubiKey with OpenPGP support)
- `gpg2` installed (`brew install gnupg` on macOS, `dnf install gnupg2` on Fedora)
- `pinentry-mac` on macOS (`brew install pinentry-mac`) or `pinentry-curses` on Linux
- `ykman` (YubiKey Manager) — optional but helpful (`brew install ykman`)

Verify GPG is working:
```bash
gpg --version
# Should show 2.x
```

Verify YubiKey is detected:
```bash
gpg --card-status
# Should display your YubiKey details
```

---

## Step 1: Configure GPG

The GPG configuration is managed by this dotfiles repo. Running `symlink.sh` will:
- Symlink `dotfiles/gpg.conf` → `~/.gnupg/gpg.conf` (strong algorithm defaults, long key IDs)
- Copy `dotfiles/gpg-agent.conf` → `~/.gnupg/gpg-agent.conf` (SSH support, cache TTLs)
- On macOS, automatically append `pinentry-program` pointing to `pinentry-mac`

If you've already run `init.sh`, the configs are in place. Otherwise:

```bash
# Run symlink.sh to install the GPG configs (among other things)
$HOME/devel/portaj/dotfiles/installation/symlink.sh
```

Restart the agent to pick up the new config:
```bash
gpgconf --kill gpg-agent
gpg-connect-agent /bye
```

> **Manual override:** If you need to customize, edit `dotfiles/gpg.conf` or `dotfiles/gpg-agent.conf` in the repo directly.

---

## Step 2: Generate the Master Key (Certify Only)

Generate a master key that can **only certify** (sign other keys). This key should be backed up offline and never stored on the YubiKey.

```bash
gpg --expert --full-generate-key
```

Choose:
1. **(8) RSA (set your own capabilities)** — toggle off everything except **Certify**
2. Key size: **4096**
3. Expiration: **0** (does not expire) or **2y** (your call)
4. Real name: `Jonathan Porta`
5. Email: `jonathan@jonathanporta.com`
6. Passphrase: **use a strong passphrase** — you'll need this to manage subkeys

Note the key ID from the output:
```
pub   rsa4096/0xABCD1234ABCD1234 2026-04-09 [C]
```

Export and save it:
```bash
export KEYID=0xABCD1234ABCD1234
```

---

## Step 3: Add Subkeys

Add three subkeys that **will** live on the YubiKey:

```bash
gpg --expert --edit-key $KEYID
```

### 3a. Signing subkey
```
gpg> addkey
# (8) RSA (set your own capabilities) → toggle to Sign only
# Key size: 4096
# Expiration: 1y (recommended, you can extend later)
```

### 3b. Encryption subkey
```
gpg> addkey
# (8) RSA (set your own capabilities) → toggle to Encrypt only
# Key size: 4096
# Expiration: 1y
```

### 3c. Authentication subkey (for SSH)
```
gpg> addkey
# (8) RSA (set your own capabilities) → toggle to Authenticate only
# Key size: 4096
# Expiration: 1y
```

Save:
```
gpg> save
```

Verify:
```bash
gpg -K $KEYID
# Should show [C], [S], [E], [A] subkeys
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

**Store these files securely offline** (encrypted USB, password manager, safe deposit box — not on your laptop).

---

## Step 5: Move Subkeys to YubiKey

```bash
gpg --edit-key $KEYID
```

### Move the Signing key:
```
gpg> key 1          # select the first subkey (signing)
gpg> keytocard
# Choose: (1) Signature key
```

### Move the Encryption key:
```
gpg> key 1          # deselect
gpg> key 2          # select encryption subkey
gpg> keytocard
# Choose: (2) Encryption key
```

### Move the Authentication key:
```
gpg> key 2          # deselect
gpg> key 3          # select auth subkey
gpg> keytocard
# Choose: (3) Authentication key
```

Save:
```
gpg> save
```

Verify the keys now show `ssb>` (the `>` means "on card"):
```bash
gpg -K $KEYID
# sec   rsa4096/0xABCD... [C]
# ssb>  rsa4096/...       [S]
# ssb>  rsa4096/...       [E]
# ssb>  rsa4096/...       [A]
```

---

## Step 6: Configure the YubiKey (Optional)

Set a custom PIN, Admin PIN, and reset code:

```bash
gpg --card-edit
```

```
gpg/card> admin
gpg/card> passwd
# 1 - change PIN (default: 123456)
# 3 - change Admin PIN (default: 12345678)
```

Set cardholder info:
```
gpg/card> name
# Surname: Porta
# Given name: Jonathan

gpg/card> login
# jonathan@jonathanporta.com

gpg/card> quit
```

---

## Step 7: Configure Git to Sign with YubiKey

Your dotfiles `generate_gitconfig.sh` already sets `gpg.program = gpg2`. Add the signing key:

```bash
# Get your signing subkey fingerprint
gpg -K --keyid-format long

# Tell git to use it
git config --global user.signingkey $KEYID
git config --global commit.gpgsign true
git config --global tag.gpgsign true
```

Or add these lines to `generate_gitconfig.sh` in the `[user]` section:
```
  signingkey = <YOUR_SIGNING_SUBKEY_ID>

[commit]
  gpgsign = true

[tag]
  gpgsign = true
```

---

## Step 8: Upload Public Key to GitHub

```bash
# Copy public key to clipboard
gpg --armor --export $KEYID | pbcopy   # macOS
# gpg --armor --export $KEYID | xclip  # Linux
```

Then go to **GitHub → Settings → SSH and GPG keys → New GPG key** and paste it.

---

## Step 9: SSH Authentication via YubiKey

Your `.profile` already configures `gpg-agent` with SSH support. To get your SSH public key from the YubiKey:

```bash
# Ensure gpg-agent is running with SSH support
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

# Get the SSH public key
ssh-add -L
# or
gpg --export-ssh-key $KEYID
```

Add the SSH public key output to GitHub (Settings → SSH keys) and any `authorized_keys` files you need.

---

## Day-to-Day Usage

### Signing a commit
Just commit normally — with `commit.gpgsign = true`, it will prompt for your YubiKey PIN:
```bash
git commit -m "signed commit"  # touch YubiKey when it blinks
```

### SSH into a server
```bash
ssh user@host  # touch YubiKey when it blinks
```

### Verify it's working
```bash
# Verify GPG sees the card
gpg --card-status

# Verify SSH agent sees the key
ssh-add -L

# Verify git signing works
echo "test" | gpg --clearsign
```

---

## Troubleshooting

### "No secret key" or "No card"
```bash
# Restart the agent
gpg_reboot  # alias from .profile

# Or manually:
gpgconf --kill gpg-agent
gpg-connect-agent /bye
```

### SSH not using YubiKey
Make sure `SSH_AUTH_SOCK` points to the gpg-agent socket, not the macOS ssh-agent:
```bash
echo $SSH_AUTH_SOCK
# Should be: /Users/portaj/.gnupg/S.gpg-agent.ssh
# NOT: /private/tmp/com.apple.launchd.xxx/Listeners
```

### PIN blocked after too many wrong attempts
Use the Admin PIN to reset:
```bash
gpg --card-edit
gpg/card> admin
gpg/card> passwd
# Option 2: unblock and set new PIN
```

### Moving to a new machine
You only need the **public key** — the private keys live on the YubiKey:
```bash
# Import your public key on the new machine
gpg --import public-key.asc

# Tell GPG to look at the card for the private keys
gpg --card-status

# Trust the key
gpg --edit-key $KEYID
gpg> trust
# 5 (ultimate)
gpg> quit
```

---

## References

- [YubiKey Guide (drduh)](https://github.com/drduh/YubiKey-Guide) — the definitive reference
- [GPG + Git signing (GitHub docs)](https://docs.github.com/en/authentication/managing-commit-signature-verification)
- [GnuPG documentation](https://www.gnupg.org/documentation/)
