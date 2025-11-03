# pkgflow

Universal package manifest transformer for Nix. Transform between Flox manifests, Nix packages, and Homebrew (with more formats coming soon).

## Features

- 📦 **Automatic package installation** from Flox `manifest.toml` files
- 🏠 **Home-manager support** - Install to `home.packages`
- 🖥️ **NixOS/Darwin support** - Install to `environment.systemPackages`
- 🍺 **Homebrew integration** - Convert Nix packages to Homebrew on macOS
- 🔄 **Flake package resolution** - Support for flake-based packages in manifests
- 🔐 **Binary cache support** - Automatic substituter and trusted-public-keys configuration
- 🎯 **System filtering** - Smart filtering by compatible systems
- 🚀 **Zero configuration** - Import and go, no `enable` switches needed
- 🧠 **Context-aware** - Automatically detects home-manager vs system context

## Installation

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pkgflow.url = "github:HuaDeity/pkgflow";
  };
}
```

## Module Structure

pkgflow provides 3 simple, independent module outputs:

| Module | Use For | Auto-detects Context |
|--------|---------|---------------------|
| `sharedModules.default` | Shared manifest path | N/A |
| `nixModules.default` | Nix packages (home OR system) | ✅ Yes |
| `brewModules.default` | Darwin Homebrew | No |

**Key Features:**

- ✅ **Import = Enable** - No `enable` option needed
- ✅ **Auto-detection** - `nixModules` detects home-manager vs system context automatically
- ✅ **Flake inputs** - Automatically uses your flake's `inputs` for flake packages

## Quick Start

### For Home-Manager

```nix
{ inputs, ... }:
{
  imports = [
    inputs.pkgflow.sharedModules.default # Optional: for global config
    inputs.pkgflow.nixModules.default # Auto-detects home.packages
  ];

  pkgflow.manifest.file = ./manifest.toml;
}
```

### For NixOS/nix-darwin

```nix
{ inputs, ... }:
{
  imports = [
    inputs.pkgflow.sharedModules.default
    inputs.pkgflow.nixModules.default # Auto-detects environment.systemPackages
  ];

  pkgflow.manifest.file = ./manifest.toml;
}
```

### For nix-darwin with Homebrew

```nix
{ inputs, ... }:
{
  imports = [
    inputs.pkgflow.sharedModules.default
    inputs.pkgflow.nixModules.default # For Nix packages
    inputs.pkgflow.brewModules.default # For Homebrew
  ];

  pkgflow.manifest.file = ./manifest.toml;

  # Optional: Only install packages that explicitly declare systems
  pkgflow.manifestPackages.requireSystemMatch = true;
}
```

## Binary Cache Support

pkgflow can automatically configure binary caches (substituters) and trusted public keys for flake packages in your manifest. This is especially useful for Cachix caches and other binary cache services.

### How It Works

When enabled, pkgflow:
1. Reads your manifest to find flake packages
2. Auto-detects `github:nix-community/*` flakes and adds nix-community.cachix.org (see `addNixCommunity` option)
3. Matches other flakes against the cache mapping in `config/caches.nix`
4. Automatically sets `nix.settings.substituters` and `nix.settings.trusted-public-keys`
5. Only configures caches for packages that match your current system

### Configuration Options

```nix
pkgflow.caches = {
  enable = false;              # Enable binary cache configuration
  onlyTrusted = false;         # System-only: Set only trusted-* settings
  addNixCommunity = null;      # null=auto-detect, true=always, false=never
  mapping = [ ... ];           # Override default cache mappings
};
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable binary cache configuration |
| `onlyTrusted` | bool | `false` | System-only: Set trusted-substituters and trusted-public-keys (useful for non-trusted users) |
| `addNixCommunity` | bool\|null | `null` | **null**: Auto-detect nix-community flakes and add cache if found<br>**true**: Always add nix-community cache<br>**false**: Never add nix-community cache |
| `mapping` | list | `config/caches.nix` | Cache mappings (flake → substituter + key) |

### Installation Scenarios

**Scenario 1: System (trusted only) + Home (full config)**

Best for systems where users are not in `trusted-users`:

```nix
# system configuration (NixOS/nix-darwin)
{
  imports = [ inputs.pkgflow.nixModules.default ];
  pkgflow.caches.onlyTrusted = true;  # Set trusted-substituters and trusted-public-keys
}

# home-manager configuration
{
  imports = [ inputs.pkgflow.nixModules.default ];
  pkgflow.manifest.file = ./manifest.toml;
  pkgflow.caches.enable = true;  # Set substituters and trusted-public-keys
}
```

**Scenario 2: System only (full config + packages)**

```nix
# system configuration
{
  imports = [ inputs.pkgflow.nixModules.default ];
  pkgflow.manifest.file = ./manifest.toml;
  pkgflow.caches.enable = true;  # Set substituters and trusted-public-keys at system level
}
```

**Scenario 3: Home-manager only (full config + packages)**

```nix
# home-manager configuration
{
  imports = [ inputs.pkgflow.nixModules.default ];
  pkgflow.manifest.file = ./manifest.toml;
  pkgflow.caches.enable = true;  # Set substituters and trusted-public-keys at home level
}
```

### Default Cache Mappings

pkgflow includes default mappings for popular flake caches in `config/caches.nix`:

```nix
[
  {
    flake = "github:helix-editor/helix";
    substituter = "https://helix.cachix.org";
    trustedKey = "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs=";
  }
]
```

**Note:** By default (`addNixCommunity = null`), `github:nix-community/*` flakes are automatically detected and configured to use `nix-community.cachix.org`. Set to `false` to disable, or `true` to always add regardless of detection.

### Custom Cache Mappings

You can override or extend the default mappings:

```nix
{
  pkgflow.caches = {
    enable = true;
    mapping = [
      # Add your custom caches
      {
        flake = "github:myorg/myflake";
        substituter = "https://mycache.example.com";
        trustedKey = "mycache.example.com-1:xxxxx";
      }
      # Or include defaults and add more
    ] ++ (import "${inputs.pkgflow}/config/caches.nix");
  };
}
```

### Example Manifest

```toml
version = 1

[install]
# Regular nixpkgs packages (no cache configuration needed)
git.pkg-path = "git"

# Flake packages (cache automatically configured if in mapping)
helix.flake = "github:helix-editor/helix"
helix.systems = ["aarch64-darwin", "x86_64-linux"]

# Nix-community flakes (automatically use nix-community.cachix.org)
neovim-nightly-overlay.flake = "github:nix-community/neovim-nightly-overlay"
neovim-nightly-overlay.systems = ["aarch64-darwin", "x86_64-linux"]
```

When `pkgflow.caches.enable = true`:
- **Helix** cache is configured from `config/caches.nix` mapping
- **Neovim Nightly** cache is automatically detected and configured (nix-community.cachix.org)

## Configuration Options

### `pkgflow.manifest` (Shared)

```nix
pkgflow.manifest.file = ./path/to/manifest.toml;
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `file` | path | `null` | Path to manifest.toml file |

### `pkgflow.manifestPackages` (Nix Packages)

```nix
pkgflow.manifestPackages = {
  manifestFile = ./custom-manifest.toml;  # Optional: override shared
  requireSystemMatch = true;              # Optional: filter packages
};
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `manifestFile` | path | `null` | Override shared manifest path |
| `requireSystemMatch` | bool | `false` | Control package filtering (see below) |

#### System Filtering Behavior

**The `systems` attribute is ALWAYS respected when present.**

`requireSystemMatch` only controls packages **WITHOUT** a `systems` attribute:

| Package Type | `requireSystemMatch = false` | `requireSystemMatch = true` |
|--------------|------------------------------|----------------------------|
| Has `systems` with current system | ✅ Installed | ✅ Installed |
| Has `systems` without current system | ❌ Skipped | ❌ Skipped |
| **No `systems` attribute** | **✅ Installed** | **❌ Skipped** |

**Example on `aarch64-darwin`:**

```toml
[install]
# No systems - behavior depends on requireSystemMatch
git.pkg-path = "git"

# Has systems including aarch64-darwin - always installed
helix.flake = "github:helix-editor/helix"
helix.systems = ["aarch64-darwin", "x86_64-linux"]

# Has systems without aarch64-darwin - always skipped
mihomo.pkg-path = "mihomo"
mihomo.systems = ["aarch64-linux", "x86_64-linux"]
```

### `pkgflow.caches` (Binary Caches)

```nix
pkgflow.caches = {
  enable = true;                       # Enable cache configuration
  onlyTrusted = false;                 # System-only: trusted settings
  addNixCommunity = null;              # null=auto-detect, true=always, false=never
  mapping = import ./config/caches.nix; # Cache mappings
};
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable binary cache configuration |
| `onlyTrusted` | bool | `false` | System-only: Set trusted-substituters/keys |
| `addNixCommunity` | bool\|null | `null` | **null**: auto-detect, **true**: always add, **false**: never add |
| `mapping` | list | `./config/caches.nix` | Flake → cache mappings |

See [Binary Cache Support](#binary-cache-support) for detailed documentation.

### `pkgflow.homebrewManifest` (Darwin only)

```nix
pkgflow.homebrewManifest = {
  manifestFile = ./custom-manifest.toml;  # Optional: override shared
  mappingFile = ./my-mapping.toml;        # Optional: custom mapping
};
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `manifestFile` | path | `null` | Override shared manifest path |
| `mappingFile` | path | `./config/mapping.toml` | Nix → Homebrew mapping |

**Homebrew module behavior:**

- ✅ Installs packages **WITHOUT** `systems` attribute
- ❌ Skips packages **WITH** `systems` attribute (reserved for Nix)

## macOS Configuration Strategy

On macOS, use both `nixModules` and `brewModules` together:

```nix
{ inputs, ... }:
{
  imports = [
    inputs.pkgflow.sharedModules.default
    inputs.pkgflow.nixModules.default
    inputs.pkgflow.brewModules.default
  ];

  pkgflow.manifest.file = ./manifest.toml;

  # Only install Nix packages that explicitly declare systems
  pkgflow.manifestPackages.requireSystemMatch = true;
}
```

**Manifest example:**

```toml
[install]
# → Homebrew (no systems attribute)
git.pkg-path = "git"
nodejs.pkg-path = "nodejs"
neovim.pkg-path = "neovim"

# → Nix only (has systems attribute)
nixfmt-rfc-style.pkg-path = "nixfmt-rfc-style"
nixfmt-rfc-style.systems = ["aarch64-darwin", "x86_64-linux"]

helix.flake = "github:helix-editor/helix"
helix.systems = ["aarch64-darwin", "x86_64-linux"]
```

**Result:**

- ✅ Homebrew: git, nodejs, neovim
- ✅ Nix: nixfmt-rfc-style, helix
- ✅ No duplicates

## Flake Package Support

Flake packages are **automatically resolved** from your flake inputs:

1. **Add the flake to your inputs:**

```nix
{
  inputs = {
    helix.url = "github:helix-editor/helix";
    mcp-hub.url = "github:ravitemer/mcp-hub";
  };
}
```

2. **Reference in manifest:**

```toml
[install]
helix.flake = "github:helix-editor/helix"
helix.systems = ["aarch64-darwin", "x86_64-linux"]

mcp-hub.flake = "github:ravitemer/mcp-hub"
mcp-hub.systems = ["aarch64-darwin", "x86_64-linux"]
```

3. **pkgflow automatically uses `inputs`** - No configuration needed!

**If a flake package is missing:**

```
pkgflow: Flake package 'helix' not found in flake inputs.

The manifest references: helix.flake = "github:helix-editor/helix"
But 'helix' is not available in your flake inputs.

To fix this, add to your flake.nix:
  inputs.helix.url = "github:helix-editor/helix";
  inputs.helix.inputs.nixpkgs.follows = "nixpkgs";

Then run: nix flake update helix
```

## Manifest Format

pkgflow reads standard Flox `manifest.toml` files:

```toml
version = 1

[install]
# Regular nixpkgs packages
git.pkg-path = "git"
neovim.pkg-path = "neovim"

# With nested paths
nodejs.pkg-path = "nodejs"

# With system filters
python3.pkg-path = "python3"
python3.systems = ["x86_64-linux", "aarch64-darwin"]

# Flake packages (requires flake input)
helix.flake = "github:helix-editor/helix"
helix.systems = ["aarch64-darwin", "x86_64-linux"]
```

## Examples

### Minimal Home-Manager

```nix
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.nixModules.default ];
  pkgflow.manifestPackages.manifestFile = ./manifest.toml;
}
```

### Shared Manifest Across Modules

```nix
# In shared config
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.sharedModules.default ];
  pkgflow.manifest.file = ./default/.flox/env/manifest.toml;
}

# In home-manager config
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.nixModules.default ];
  # Uses pkgflow.manifest.file from shared config
}
```

## How It Works

1. **Reads** the Flox `manifest.toml` file
2. **Filters** packages by system compatibility
3. **Resolves** packages from nixpkgs or flake inputs
4. **Detects** context (home-manager vs system)
5. **Installs** to appropriate location

## Roadmap

- 🔄 **CLI tool** - Convert between formats: `pkgflow convert manifest.toml --to brewfile`
- 📝 **Brewfile support** - Direct Brewfile to Nix conversion
- 📦 **APT/DNF support** - Support for Debian/RedHat package lists
- 🔀 **Bi-directional** - Convert from Nix to other formats

## Contributing

Contributions welcome! Please open an issue or PR on [GitHub](https://github.com/HuaDeity/pkgflow).

## Credits

Created by [HuaDeity](https://github.com/HuaDeity) for universal package manifest management in Nix/NixOS environments.

Works great with [Flox](https://flox.dev) manifest files!
