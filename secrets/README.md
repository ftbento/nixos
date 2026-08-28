# Agenix Secrets Management

Secrets are encrypted using SSH public keys and decrypted automatically on the target hosts.

## Key Naming Convention

Each host uses a unique SSH key pair following the format: `<username>-<hostname>`

## Adding a New Host / Key

1. **Generate a new SSH key pair** on the host:
   ```bash
   ssh-keygen -t ed25519 -C "<username>-<hostname>" -f ~/.ssh/id_ed25519
   ```

2. **Add the public key to `secrets.nix`**:
   ```nix
   <username>-<hostname> = "ssh-ed25519 PUBLIC_KEY_COMMENT";
   ```

3. **Add the key variable to the secret's `publicKeys` array** in `secrets.nix`:
   ```nix
   "secret-name.age".publicKeys = [ <username>-<hostname> ... ];
   ```

4. **Rekey existing secrets** to include the new host:
   ```bash
   agenix --rekey OR agenix -r
   ```

   This requires the private key for the host to be present at `~/.ssh/id_ed25519`.

## Adding a New Service

1. **Generate credentials** for the service:
   - For SSH keys: `ssh-keygen -t ed25519 -f secrets/<service-name>`
   - For API keys: Generate through the service's dashboard

2. **Encrypt the secret** using agenix:
   ```bash
   agenix -e secrets/<service-name>.age
   ```

3. **Paste the secret** (private key or API key) into the editor that opens

4. **Add the secret to `secrets.nix`**:
   ```nix
   "<service-name>.age".publicKeys = [ ... ];
   ```

5. Deleted the unencrypted file

## Editing Secrets

To create or edit an existing secret:

```bash
agenix -e secrets/<name>.age
```

## NixOS Configuration

Declare secrets in host's `configuration.nix`:

```nix
age.secrets.<name> = {
  file = ../secrets/<name>.age;
  mode = "600";  # optional, default is "600"
  owner = "user";  # optional, default is "root"
};
```

The decrypted secret will be available at `/run/agenix/<name>` on the target host.