# Foundation scripts

This directory contains the **Phase 0** bootstrap scripts that prepare Azure for Terraform:

## Phase 0

### Setup (create prerequisites)

Run all steps:

```bash
./setup-phase0.sh
```

Or run individual steps:

```bash
./setup-rg.sh
./setup-state-storage.sh
./setup-access-user.sh
```

### Verify (read-only checks)

```bash
./verify-phase0.sh
```

### Cleanup (reverse of setup)

Dry-run by default:

```bash
./cleanup-phase0.sh
```

Apply (destructive):

```bash
./cleanup-phase0.sh --execute --confirm "DELETE phase0 <project>"
```

## Common flags

Most scripts share a consistent CLI:

* `--dry-run` / `--execute`
* `--env <dev|test|stage|prod>` (repeatable) / `--all-envs`

Cleanup scripts additionally require a `--confirm` phrase when executing.
