# macOS User Guide for pkgflow

This guide explains the recommended ways to use pkgflow on macOS with nix-darwin.

## TL;DR - Quick Recommendations

### Want Homebrew for most tools? Use Strategy 1 (Homebrew-First)
### Want Nix for everything? Use Strategy 2 (Nix-Only)

---

## Strategy 1: Homebrew-First (Recommended)

**Best for**: Most macOS users who want native Homebrew performance for common tools.

### Configuration

```nix
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.darwinModules.default ];

  pkgflow.manifest = {
    file = ./manifest.toml;
    flakeInputs = inputs;
  };

  # Install Homebrew packages
  pkgflow.homebrewManifest.enable = true;

  # Install Nix-exclusive packages
  pkgflow.manifestPackages = {
    enable = true;
    requireSystemMatch = true;  # ⚠️ REQUIRED for this strategy
    output = "system";
  };
}
```

### Manifest Structure

```toml
version = 1

[install]
# ===== Homebrew packages (no 'systems' attribute) =====
git.pkg-path = "git"
neovim.pkg-path = "neovim"
nodejs.pkg-path = "nodejs"
ripgrep.pkg-path = "ripgrep"
fd.pkg-path = "fd"

# ===== Nix-only packages (with 'systems' attribute) =====
# Use for packages not in Homebrew or requiring specific versions
nixfmt-rfc-style.pkg-path = "nixfmt-rfc-style"
nixfmt-rfc-style.systems = ["aarch64-darwin", "x86_64-linux"]

# Flake packages always go through Nix
helix.flake = "github:helix-editor/helix"
helix.systems = ["aarch64-darwin"]
```

### What Happens

| Package | `systems` Attribute | Installed Via |
|---------|---------------------|---------------|
| git | ❌ No | Homebrew |
| neovim | ❌ No | Homebrew |
| nixfmt-rfc-style | ✅ Yes | Nix |
| helix (flake) | ✅ Yes | Nix |

### Benefits

✅ Native Homebrew performance for CLI tools
✅ Better macOS integration
✅ Nix for packages unavailable in Homebrew
✅ No duplicate installations
✅ Automatic updates via Homebrew for most packages

### Important Notes

- **MUST set `requireSystemMatch = true`** to avoid duplicate installations
- Add `systems = ["aarch64-darwin"]` (or your platform) to Nix-only packages
- Flake packages should always have `systems` attribute

---

## Strategy 2: Nix-Only

**Best for**: Users who want consistency with Linux or don't want Homebrew.

### Configuration

```nix
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.darwinModules.default ];

  pkgflow.manifestPackages = {
    enable = true;
    manifestFile = ./manifest.toml;
    flakeInputs = inputs;
    output = "system";
    # requireSystemMatch = false (default) - installs all packages
  };
}
```

### Manifest Structure

```toml
version = 1

[install]
# All packages installed via Nix (systems attribute optional)
git.pkg-path = "git"
neovim.pkg-path = "neovim"
nodejs.pkg-path = "nodejs"
nixfmt-rfc-style.pkg-path = "nixfmt-rfc-style"

# Flake packages
helix.flake = "github:helix-editor/helix"
```

### What Happens

| Package | Installed Via |
|---------|---------------|
| git | Nix |
| neovim | Nix |
| nixfmt-rfc-style | Nix |
| helix (flake) | Nix |

### Benefits

✅ Same behavior as Linux/NixOS
✅ Fully reproducible across platforms
✅ No Homebrew dependency
✅ Declarative package management

### Trade-offs

⚠️ Larger Nix store
⚠️ Some packages may have reduced macOS integration
⚠️ No automatic Homebrew updates

---

## Comparison Table

| Feature | Homebrew-First | Nix-Only |
|---------|----------------|----------|
| **Config complexity** | Medium (requires `requireSystemMatch = true`) | Simple |
| **Performance** | Native (Homebrew) + Nix | Nix only |
| **macOS integration** | Excellent | Good |
| **Reproducibility** | Good | Excellent |
| **Disk usage** | Lower | Higher (Nix store) |
| **Auto-updates** | Homebrew: Yes, Nix: No | No |
| **Cross-platform** | Manifest needs maintenance | Same config on all platforms |

---

## Understanding `requireSystemMatch`

This option changes how the `systems` attribute is interpreted:

### `requireSystemMatch = false` (default)

**Behavior**: "Install all packages that are compatible"

```toml
[install]
# ✅ Installed (no systems = assumed compatible)
git.pkg-path = "git"

# ✅ Installed (aarch64-darwin is in list)
neovim.pkg-path = "neovim"
neovim.systems = ["aarch64-darwin", "x86_64-linux"]

# ❌ Skipped (aarch64-darwin NOT in list)
systemd.pkg-path = "systemd"
systemd.systems = ["x86_64-linux"]
```

**Use case**: Linux/NixOS, or Nix-only on macOS

### `requireSystemMatch = true`

**Behavior**: "Only install packages that explicitly list this system"

```toml
[install]
# ❌ Skipped (no systems = not explicitly listed)
git.pkg-path = "git"

# ✅ Installed (aarch64-darwin explicitly listed)
neovim.pkg-path = "neovim"
neovim.systems = ["aarch64-darwin", "x86_64-linux"]

# ❌ Skipped (aarch64-darwin NOT in list)
systemd.pkg-path = "systemd"
systemd.systems = ["x86_64-linux"]
```

**Use case**: Homebrew-first strategy on macOS

---

## Common Patterns

### Pattern: Mix Homebrew and Nix

```toml
[install]
# Common CLI tools → Homebrew
git.pkg-path = "git"
bat.pkg-path = "bat"
fd.pkg-path = "fd"
ripgrep.pkg-path = "ripgrep"

# Development tools → Homebrew
nodejs.pkg-path = "nodejs"
python3.pkg-path = "python3"

# Nix-specific packages → Nix
nixfmt-rfc-style.pkg-path = "nixfmt-rfc-style"
nixfmt-rfc-style.systems = ["aarch64-darwin", "x86_64-linux"]

cachix.pkg-path = "cachix"
cachix.systems = ["aarch64-darwin", "x86_64-linux"]

# Flake packages → Nix
neovim-nightly.flake = "github:nix-community/neovim-nightly-overlay"
neovim-nightly.systems = ["aarch64-darwin"]
```

### Pattern: Platform-Specific Packages

```toml
[install]
# Cross-platform (Homebrew on macOS, Nix on Linux)
git.pkg-path = "git"
neovim.pkg-path = "neovim"

# macOS-only via Nix
darwin-rebuild.pkg-path = "darwin-rebuild"
darwin-rebuild.systems = ["aarch64-darwin", "x86_64-darwin"]

# Linux-only via Nix
systemd.pkg-path = "systemd"
systemd.systems = ["x86_64-linux", "aarch64-linux"]
```

---

## Troubleshooting

### Problem: Packages installed twice (Homebrew + Nix)

**Cause**: Using Homebrew-first strategy without `requireSystemMatch = true`

**Solution**:
```nix
pkgflow.manifestPackages = {
  enable = true;
  requireSystemMatch = true;  # Add this!
  output = "system";
};
```

### Problem: Nix packages not installing

**Cause**: Using `requireSystemMatch = true` but packages lack `systems` attribute

**Solution**: Add `systems` attribute to packages you want via Nix:
```toml
nixfmt.pkg-path = "nixfmt-rfc-style"
nixfmt.systems = ["aarch64-darwin"]  # Add this!
```

### Problem: Flake packages not found

**Cause**: Missing `flakeInputs` or incorrect flake input name

**Solution**:
```nix
pkgflow.manifest.flakeInputs = inputs;  # Add this!
```

And ensure flake is in your inputs:
```nix
inputs.neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
```

---

## Migration Guide

### From Manual Homebrew + Nix

**Before** (manual Brewfile + Nix config):
```nix
# Brewfile
brew "git"
brew "neovim"

# Nix config
environment.systemPackages = with pkgs; [
  nixfmt-rfc-style
  cachix
];
```

**After** (unified manifest):
```toml
# manifest.toml
[install]
git.pkg-path = "git"
neovim.pkg-path = "neovim"

nixfmt-rfc-style.pkg-path = "nixfmt-rfc-style"
nixfmt-rfc-style.systems = ["aarch64-darwin"]

cachix.pkg-path = "cachix"
cachix.systems = ["aarch64-darwin"]
```

```nix
# nix-darwin config
pkgflow.manifest.file = ./manifest.toml;
pkgflow.homebrewManifest.enable = true;
pkgflow.manifestPackages = {
  enable = true;
  requireSystemMatch = true;
  output = "system";
};
```

---

## Quick Reference

### Homebrew-First Setup Checklist

- [ ] Set `pkgflow.homebrewManifest.enable = true`
- [ ] Set `pkgflow.manifestPackages.enable = true`
- [ ] Set `pkgflow.manifestPackages.requireSystemMatch = true` ⚠️ **IMPORTANT**
- [ ] Packages for Homebrew: No `systems` attribute
- [ ] Packages for Nix: Add `systems = ["aarch64-darwin"]` (or your platform)
- [ ] Flake packages: Always add `systems` attribute

### Nix-Only Setup Checklist

- [ ] Set `pkgflow.manifestPackages.enable = true`
- [ ] Do NOT set `requireSystemMatch = true`
- [ ] Do NOT enable `homebrewManifest`
- [ ] `systems` attribute optional (used only for cross-platform filtering)

---

## Further Reading

- [README.md](./README.md) - General pkgflow documentation
- [AGENTS.md](./AGENTS.md) - Architecture and internals
- [CHANGELOG.md](./CHANGELOG.md) - Version history and migration guide
- [examples/darwin.nix](./examples/darwin.nix) - Example configurations
