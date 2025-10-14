# pkgflow

Universal package manifest transformer for Nix. Transform between Flox manifests, Nix packages, and Homebrew (with more formats coming soon).

## Features

- 📦 **Automatic package installation** from Flox `manifest.toml` files
- 🏠 **Home-manager support** - Install to `home.packages`
- 🖥️ **NixOS/Darwin support** - Install to `environment.systemPackages`
- 🍺 **Homebrew integration** - Convert Nix packages to Homebrew on macOS
- 🔄 **Flake package resolution** - Support for flake-based packages in manifests
- 🎯 **System filtering** - Optionally filter packages by compatible systems
- ⚙️ **Flexible configuration** - Multiple ways to specify manifest files
- 🚀 **Future-ready** - Designed for multi-directional format transformation

## Installation

### As a Flake Input (Recommended)

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";

    pkgflow.url = "github:HuaDeity/pkgflow";
    pkgflow.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, pkgflow, ... }: {
    # Home-manager configuration
    homeConfigurations."user@host" = home-manager.lib.homeManagerConfiguration {
      modules = [
        pkgflow.homeModules.default
        {
          pkgflow.manifestPackages = {
            enable = true;
            manifestFile = ./path/to/manifest.toml;
          };
        }
      ];
    };

    # NixOS configuration
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      modules = [
        pkgflow.nixosModules.default
        {
          pkgflow.manifestPackages = {
            enable = true;
            manifestFile = ./path/to/manifest.toml;
            output = "system";
          };
        }
      ];
    };
  };
}
```

### Direct Import (Without Flakes)

```nix
{ pkgs, ... }:
let
  pkgflow = builtins.fetchGit {
    url = "https://github.com/HuaDeity/pkgflow";
    ref = "main";
  };
in
{
  imports = [ "${pkgflow}/default.nix" ];

  pkgflow.manifestPackages = {
    enable = true;
    manifestFile = ./manifest.toml;
  };
}
```

## Usage

### Basic Home-Manager Usage

```nix
{
  pkgflow.manifestPackages = {
    enable = true;
    manifestFile = ./my-project/.flox/env/manifest.toml;
  };
}
```

### With Flake Package Support

```nix
{ inputs, ... }:
{
  pkgflow.manifestPackages = {
    enable = true;
    manifestFile = ./manifest.toml;
    flakeInputs = inputs;  # Pass flake inputs for flake package resolution
  };
}
```

### NixOS/Darwin System Packages

```nix
{
  pkgflow.manifestPackages = {
    enable = true;
    manifestFile = ./manifest.toml;
    output = "system";  # Install to environment.systemPackages
  };
}
```

### Global Manifest Path

Set a global default manifest path:

```nix
{
  pkgflow.manifest.file = ./default/.flox/env/manifest.toml;

  pkgflow.manifestPackages = {
    enable = true;
    # Will use pkgflow.manifest.file
  };
}
```

### Homebrew Integration (macOS)

For nix-darwin users who want to convert Nix packages to Homebrew:

```nix
{
  pkgflow.homebrewManifest = {
    enable = true;
    manifestFile = ./manifest.toml;
  };
}
```

## Configuration Options

### `pkgflow.manifestPackages`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable package installation from manifest |
| `manifestFile` | path | `null` | Path to manifest.toml file |
| `flakeInputs` | attrs | `null` | Flake inputs for resolving flake packages |
| `requireSystemMatch` | bool | `false` | Only install packages matching current system |
| `output` | enum | `"home"` | Where to install: `"home"` or `"system"` |

### `pkgflow.homebrewManifest` (Darwin only)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Homebrew package installation |
| `manifestFile` | path | `null` | Path to manifest.toml file |
| `mappingFile` | path | `./config/mapping.toml` | Nix → Homebrew mapping file |

### `pkgflow.manifest`

| Option | Type | Description |
|--------|------|-------------|
| `file` | path | Global default manifest path |

## Manifest Format

This module currently reads standard Flox `manifest.toml` files:

```toml
version = 1

[install]
# Regular nixpkgs packages
git.pkg-path = "git"
neovim.pkg-path = "neovim"

# Packages with system filters
nodejs.pkg-path = "nodejs"
nodejs.systems = ["x86_64-linux", "aarch64-darwin"]

# Flake-based packages (requires flakeInputs)
helix.flake = "github:helix-editor/helix"
```

## Examples

See the [examples/](./examples/) directory for complete configurations:

- [home-manager.nix](./examples/home-manager.nix) - Home-manager standalone
- [nixos.nix](./examples/nixos.nix) - NixOS system configuration
- [darwin.nix](./examples/darwin.nix) - macOS with nix-darwin
- [with-flakes.nix](./examples/with-flakes.nix) - Using flake packages

## How It Works

1. Reads the Flox `manifest.toml` file (or other supported formats)
2. Parses the `[install]` section for package definitions
3. Resolves packages from nixpkgs or flake inputs
4. Filters by system compatibility (if enabled)
5. Installs to `home.packages` or `environment.systemPackages`

## Roadmap

- 🔄 **CLI tool** - Convert between formats: `pkgflow convert manifest.toml --to brewfile`
- 📝 **Brewfile support** - Direct Brewfile to Nix conversion
- 📦 **APT/DNF support** - Support for Debian/RedHat package lists
- 🔀 **Bi-directional** - Convert from Nix to other formats
- 🎯 **Custom formats** - Plugin system for custom manifest formats

## Limitations

- Flake packages require passing `flakeInputs` option
- Homebrew mapping requires maintaining the mapping file
- System filtering is opt-in (defaults to installing all packages)

## Contributing

Contributions welcome! Please open an issue or PR on [GitHub](https://github.com/HuaDeity/pkgflow).

## License

MIT License - See [LICENSE](./LICENSE) file for details.

## Credits

Created by [HuaDeity](https://github.com/HuaDeity) for universal package manifest management in Nix/NixOS environments.

Works great with [Flox](https://flox.dev) manifest files!
