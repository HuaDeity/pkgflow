# pkgflow

Universal package manifest transformer for Nix. Transform between Flox manifests, Nix packages, and Homebrew.

## Features

- 📦 **Multiple manifest support** - Merge packages from multiple `manifest.toml` files
- 🏠 **Home-manager support** - Install to `home.packages`
- 🖥️ **NixOS/Darwin support** - Install to `environment.systemPackages`
- 🍺 **Homebrew integration** - Convert Nix packages to Homebrew on macOS
- 🔄 **Flake package resolution** - Support for flake-based packages in manifests
- 🔐 **Binary cache support** - Automatic substituter and trusted-public-keys configuration
- 🎯 **Explicit configuration** - No assumptions, full control over package sources
- ⚙️ **Override defaults** - Customize Homebrew and cache mappings

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

pkgflow provides 3 platform-specific module outputs:

| Module | Use For |
|--------|---------|
| `homeModules.default` | Home-manager (installs to home.packages) |
| `darwinModules.default` | nix-darwin (system or home packages, Homebrew) |
| `nixosModules.default` | NixOS (installs to environment.systemPackages) |

## Quick Start

### For Home-Manager

```nix
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.homeModules.default ];

  pkgflow.manifestFiles = [ ./manifest.toml ];
}
```

### For NixOS

```nix
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.nixosModules.default ];

  pkgflow.manifestFiles = [ ./manifest.toml ];
}
```

### For nix-darwin

```nix
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.darwinModules.default ];

  pkgflow.manifestFiles = [ ./manifest.toml ];

  # Optional: Customize package installation
  pkgflow.pkgs = {
    enable = true;
    nixpkgs = [ "home" ];  # Default: install via home.packages
    flakes = [ "home" ];
  };
}
```

### For nix-darwin with Homebrew

```nix
{ inputs, ... }:
{
  imports = [ inputs.pkgflow.darwinModules.default ];

  pkgflow.manifestFiles = [ ./manifest.toml ];

  # Use Homebrew for compatible packages, Nix for others
  pkgflow.pkgs = {
    enable = true;
    nixpkgs = [ "brew" "home" ];  # Try Homebrew first, fallback to Nix
    flakes = [ "brew" "home" ];
  };
}
```

## Configuration

### Multiple Manifests

You can merge multiple manifest files:

```nix
pkgflow.manifestFiles = [
  ./project-a/manifest.toml
  ./project-b/manifest.toml
  ./personal/manifest.toml
];
```

### Package Installation

Control where and how packages are installed:

```nix
pkgflow.pkgs = {
  enable = true;           # Enable package installation (default: true)
  nixpkgs = [ "home" ];    # Sources for nixpkgs packages (default: ["home"])
  flakes = [ "home" ];     # Sources for flake packages (default: [])
};
```

**Available sources** (can specify multiple, earlier sources have priority):
- `"home"` - Install via `home.packages` (home-manager)
- `"system"` - Install via `environment.systemPackages` (NixOS/nix-darwin)
- `"brew"` - Install via Homebrew (Darwin only, requires mapping)

**Note:** Cannot use both `"system"` and `"home"` together - choose one.

### Homebrew Mapping

On Darwin, override or add Homebrew mappings:

```nix
pkgflow.pkgs.homebrewMappingOverrides = [
  # Override existing default mapping
  { nix = "git"; brew = "git-custom"; }

  # Change neovim from formula to cask
  { nix = "neovim"; cask = "neovim"; brew = null; }

  # Add new mapping for custom package
  { nix = "myapp"; brew = "myapp"; }
];
```

Default mappings are loaded from `config/mapping.toml` automatically.

### Binary Cache Configuration

Configure substituters (binary caches) for flake packages:

```nix
pkgflow.substituters = {
  enable = false;            # Enable cache configuration (default: false)
  context = "home";          # Where to configure (default: "home")
  onlyTrusted = false;       # Use trusted-substituters (default: false)
  addNixCommunity = null;    # Auto-detect nix-community flakes (default: null)
};
```

**Context options:**
- `"home"` (default) - Configure at home-manager level using `extra-substituters` and `extra-trusted-public-keys`
- `"system"` - Configure at system level using `substituters` and `trusted-public-keys`
- `null` - Do nothing

**onlyTrusted** (independent option):
- When `true`, configures `trusted-substituters` and `trusted-public-keys` at system level
- Useful for non-trusted users who need system-level trust configuration
- Can be used together with `context`

**addNixCommunity:**
- `null` (default) - Auto-detect: add cache only if `github:nix-community/*` flakes are found
- `true` - Always add nix-community cache
- `false` - Never add nix-community cache

### Custom Cache Mappings

Override or add cache mappings for flake packages:

```nix
pkgflow.substituters.mappingOverrides = [
  # Override existing default mapping
  {
    flake = "github:helix-editor/helix";
    substituter = "https://my-custom-cache.org";
    trustedKey = "my-cache.org-1:customkey==";
  }

  # Add new mapping for custom flake
  {
    flake = "github:myorg/myflake";
    substituter = "https://myflake.cachix.org";
    trustedKey = "myflake.cachix.org-1:key==";
  }
];
```

Default mappings are loaded from `config/caches.nix` automatically.

## Binary Cache Scenarios

### Scenario 1: System (trusted only) + Home (full config)

Best for systems where users are not in `trusted-users`:

```nix
# system configuration (NixOS/nix-darwin)
{
  imports = [ inputs.pkgflow.darwinModules.default ];
  pkgflow.substituters = {
    enable = true;
    onlyTrusted = true;  # Set trusted-substituters and trusted-public-keys
  };
}

# home-manager configuration
{
  imports = [ inputs.pkgflow.homeModules.default ];
  pkgflow.manifestFiles = [ ./manifest.toml ];
  pkgflow.substituters = {
    enable = true;
    context = "home";  # Set extra-substituters and extra-trusted-public-keys
  };
}
```

### Scenario 2: System only

```nix
{
  imports = [ inputs.pkgflow.nixosModules.default ];
  pkgflow.manifestFiles = [ ./manifest.toml ];
  pkgflow.substituters = {
    enable = true;
    context = "system";  # Configure at system level
  };
}
```

### Scenario 3: Home-manager only (default)

```nix
{
  imports = [ inputs.pkgflow.homeModules.default ];
  pkgflow.manifestFiles = [ ./manifest.toml ];
  pkgflow.substituters = {
    enable = true;
    # context = "home" is the default
  };
}
```

## Flake Package Support

Flake packages are **automatically resolved** from your flake inputs:

1. **Add the flake to your inputs:**

```nix
{
  inputs = {
    helix.url = "github:helix-editor/helix";
    helix.inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

2. **Reference in manifest:**

```toml
[install]
helix.flake = "github:helix-editor/helix"
helix.systems = ["aarch64-darwin", "x86_64-linux"]
```

3. **pkgflow automatically uses `inputs`** - No configuration needed!

## Manifest Format

pkgflow reads standard Flox `manifest.toml` files:

```toml
version = 1

[install]
# Regular nixpkgs packages
git.pkg-path = "git"
neovim.pkg-path = "neovim"

# With system filters
python3.pkg-path = "python3"
python3.systems = ["x86_64-linux", "aarch64-darwin"]

# Flake packages (requires flake input)
helix.flake = "github:helix-editor/helix"
helix.systems = ["aarch64-darwin", "x86_64-linux"]
```

## Configuration Reference

### `pkgflow.manifestFiles`

```nix
pkgflow.manifestFiles = [ ./manifest.toml ];
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `manifestFiles` | list(path) | (required) | List of manifest files to merge |

### `pkgflow.pkgs`

```nix
pkgflow.pkgs = {
  enable = true;
  nixpkgs = [ "home" ];
  flakes = [ ];
  homebrewMappingOverrides = [ ];
};
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `true` | Enable package installation |
| `nixpkgs` | list | `["home"]` | Sources for nixpkgs packages |
| `flakes` | list | `[]` | Sources for flake packages |
| `homebrewMappingOverrides` | list | `[]` | Override/add Homebrew mappings (Darwin only) |

### `pkgflow.substituters`

```nix
pkgflow.substituters = {
  enable = false;
  context = "home";
  onlyTrusted = false;
  addNixCommunity = null;
  mappingOverrides = [ ];
};
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable substituter configuration |
| `context` | "home"\|"system"\|null | `"home"` | Where to configure substituters |
| `onlyTrusted` | bool | `false` | Use trusted-substituters at system level |
| `addNixCommunity` | bool\|null | `null` | Control nix-community.cachix.org |
| `mappingOverrides` | list | `[]` | Override/add cache mappings |

## Examples

See the `examples/` directory for complete examples:
- `examples/home-manager.nix` - Home-manager configuration
- `examples/nixos.nix` - NixOS configuration
- `examples/darwin.nix` - nix-darwin with multiple strategies
- `examples/with-flakes.nix` - Using flake packages with caches

## How It Works

1. **Reads** multiple manifest files and merges packages
2. **Filters** packages by system compatibility
3. **Resolves** packages from nixpkgs or flake inputs
4. **Splits** packages by configured sources (home/system/brew)
5. **Configures** substituters based on flake packages
6. **Installs** packages to appropriate locations

## Contributing

Contributions welcome! Please open an issue or PR on [GitHub](https://github.com/HuaDeity/pkgflow).

## Credits

Created by [HuaDeity](https://github.com/HuaDeity) for universal package manifest management in Nix/NixOS environments.

Works great with [Flox](https://flox.dev) manifest files!
