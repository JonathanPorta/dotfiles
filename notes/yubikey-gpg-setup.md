# GPG + YubiKey Setup Guide

How to generate a GPG key and move it onto a YubiKey for signing git commits and SSH authentication.

> **Goal:** A single YubiKey that handles git commit signing, SSH auth, and (optionally) email encryption. Daily-use private key material lives on the hardware token; offline backups are stored separately for disaster recovery.

> **Authentication model:** GPG on YubiKey uses **PIN + physical touch**, not biometrics. YubiKey's fingerprint reader (Bio edition) only applies to FIDO2/U2F, which is a separate protocol from OpenPGP. If biometrics matter more to you than GPG, consider SSH commit signing with a FIDO2 flow instead.

---

## Prerequisites

- A **YubiKey 5** series (or any YubiKey with OpenPGP support)
- `gpg2` installed (`brew install gnupg` on macOS, `dnf install gnupg2` on Fedora)
- `pinentry-mac` on macOS (`brew install pinentry-mac`) or `pinentry-curses` on Linux
- `ykman` (YubiKey Manager) — required for touch/PIN policy (`brew install ykman`)

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

## Step 1: Install GPG and Configure

GPG packages and configuration are managed by this dotfiles repo via `installation/gpg.sh`. This script:
- Installs `gnupg`, `pinentry-mac` (macOS) or `pinentry-curses` (Linux), and `ykman`
- Symlinks `dotfiles/gpg.conf` → `~/.gnupg/gpg.conf` (strong algorithm defaults, long key IDs)
- Copies `dotfiles/gpg-agent.conf` → `~/.gnupg/gpg-agent.conf` (SSH support, cache TTLs)
- On macOS, automatically appends `pinentry-program` pointing to `pinentry-mac`

If you've already run `init.sh` followed by `run.sh`, everything is in place. Otherwise, run it directly:

```bash
$HOME/devel/$USER/dotfiles/installation/gpg.sh
```

Restart the agent to pick up the new config:
```bash
gpgconf --kill gpg-agent
gpg-connect-agent /bye
```

> **Manual override:** Edit `dotfiles/gpg.conf` or `dotfiles/gpg-agent.conf` in the repo directly.

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

**Store these files securely offline** (encrypted USB, password manager, safe deposit box — not on your laptop). These backups are your only recovery path if the YubiKey is lost or damaged.

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

## Step 6: Configure the YubiKey

### Change PINs (required)

The defaults are well-known and must be changed:

```bash
gpg --card-edit
```

```
gpg/card> admin
gpg/card> passwd
# 1 - change PIN (default: 123456) — used for daily signing/decrypt
# 3 - change Admin PIN (default: 12345678) — used for key management
gpg/card> quit
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

### Require touch for every signature (recommended)

This ensures physical presence — you must touch the YubiKey every time a commit is signed:

```bash
# Require touch for signing operations
ykman openpgp keys set-touch sig on

# Require touch for authentication (SSH)
ykman openpgp keys set-touch aut on

# Require touch for encryption/decryption
ykman openpgp keys set-touch enc on
```

### Require PIN for every signature (recommended)

By default, the PIN may be cached. Force the PIN prompt on every signature:

```bash
ykman openpgp access set-signature-policy always
```

This gives you **PIN + physical touch for every commit** — the closest thing to "must possess the key and prove it."

---

## Step 7: Configure Git to Sign with YubiKey

The dotfiles `generate_gitconfig.sh` already sets `gpg.program = gpg2`, `commit.gpgsign = true`, and `tag.gpgsign = true`. You just need to uncomment and set the signing key.

### Get your signing subkey ID:
```bash
gpg -K --keyid-format long
# Look for the [S] subkey — that's your signing key
```

### Set the signing key in dotfiles:

Edit `dotfiles/helpers/generate_gitconfig.sh` and uncomment the `signingkey` line in the `[user]` section:

```ini
[user]
  name = Jonathan Porta
  email = jonathan@jonathanporta.com
  signingkey = 0xYOUR_SIGNING_SUBKEY_ID!
```

> **The `!` suffix** tells Git to use that exact subkey rather than letting GPG choose. See [GitHub docs on signing keys](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key).

Then re-source to regenerate the config:
```bash
source ~/.helpers/generate_gitconfig.sh
```

### Verify signing works:
```bash
echo "test" | gpg --clearsign
# Should prompt for YubiKey PIN and touch
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

## Step 9: Enforce Signed Commits on GitHub (Server-Side)

Local signing defaults are not enough — anyone can bypass them with `--no-gpg-sign`, from another machine, or after disabling the config. **Server-side enforcement is required.**

### Option A: Branch Protection Rules
1. Go to your repository on GitHub
2. **Settings → Branches → Branch protection rules → Add rule**
3. Branch name pattern: `main` (or `**` for all branches)
4. Check **Require signed commits**

### Option B: Repository Rulesets (newer, recommended)
1. Go to your repository on GitHub
2. **Settings → Rules → Rulesets → New ruleset**
3. Add the **Require signed commits** rule
4. Target: **Default branch** (or all branches)

With this enabled, GitHub will reject any push containing unsigned or unverified commits to the protected branch. See [GitHub docs on rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).

---

## Step 10: SSH Authentication via YubiKey

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
Just commit normally — with `commit.gpgsign = true` and touch policy enabled:
```bash
git commit -m "signed commit"
# 1. Enter YubiKey PIN when prompted
# 2. Touch the YubiKey when it blinks
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

# Verify a commit is signed
git log --show-signature -1
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
# Option 2: unblock and set new user PIN
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

Then run `init.sh` → `run.sh` to install GPG config, helpers, and signing defaults.

---

## Summary: What Enforces What

| Layer | What it does | Bypassable? |
|---|---|---|
| `generate_gitconfig.sh` | Sets `commit.gpgsign = true`, `tag.gpgsign = true` | Yes — `--no-gpg-sign`, editing `~/.gitconfig`, or another machine |
| YubiKey touch policy | Requires physical touch per signature | No — hardware-enforced |
| YubiKey PIN policy (`always`) | Requires PIN per signature | No — hardware-enforced |
| GitHub ruleset / branch protection | Rejects unsigned pushes | No — server-enforced |

**All four layers together** give you: every commit is signed, signing requires your YubiKey (which you possess), the YubiKey requires your PIN (which you know) and your touch (which proves presence), and the server rejects anything that doesn't meet these requirements.

---

## References

- [YubiKey Guide (drduh)](https://github.com/drduh/YubiKey-Guide) — the definitive reference
- [GPG + Git signing (GitHub docs)](https://docs.github.com/en/authentication/managing-commit-signature-verification)
- [Telling Git about your signing key (GitHub docs)](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key)
- [Available rules for rulesets (GitHub docs)](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [ykman OpenPGP commands (Yubico docs)](https://docs.yubico.com/software/yubikey/tools/ykman/OpenPGP_Commands.html)
- [GnuPG documentation](https://www.gnupg.org/documentation/)
