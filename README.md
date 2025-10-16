# pkgflow

Universal package manifest transformer for Nix. Transform between Flox manifests, Nix packages, and Homebrew (with more formats coming soon).

## Features

- 📦 **Automatic package installation** from Flox `manifest.toml` files
- 🏠 **Home-manager support** - Install to `home.packages`
- 🖥️ **NixOS/Darwin support** - Install to `environment.systemPackages`
- 🍺 **Homebrew integration** - Convert Nix packages to Homebrew on macOS
- 🔄 **Flake package resolution** - Support for flake-based packages in manifests
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
    pkgflow.inputs.nixpkgs.follows = "nixpkgs";
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
