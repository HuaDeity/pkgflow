# Flox Manifest Nix Modules

Nix modules for automatically installing packages from [Flox](https://flox.dev) manifest files.

## Features

- 📦 **Automatic package installation** from Flox `manifest.toml` files
- 🏠 **Home-manager support** - Install to `home.packages`
- 🖥️ **NixOS/Darwin support** - Install to `environment.systemPackages`
- 🍺 **Homebrew integration** - Convert Nix packages to Homebrew on macOS
- 🔄 **Flake package resolution** - Support for flake-based packages in manifests
- 🎯 **System filtering** - Optionally filter packages by compatible systems
- ⚙️ **Flexible configuration** - Multiple ways to specify manifest files

## Installation

### As a Flake Input (Recommended)

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";

    flox-manifest.url = "github:yourusername/flox-manifest-nix";
    flox-manifest.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, flox-manifest, ... }: {
    # Home-manager configuration
    homeConfigurations."user@host" = home-manager.lib.homeManagerConfiguration {
      modules = [
        flox-manifest.homeModules.default
        {
          flox.manifestPackages = {
            enable = true;
            manifestFile = ./path/to/manifest.toml;
          };
        }
      ];
    };

    # NixOS configuration
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      modules = [
        flox-manifest.nixosModules.default
        {
          flox.manifestPackages = {
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
  flox-manifest = builtins.fetchGit {
    url = "https://github.com/yourusername/flox-manifest-nix";
    ref = "main";
  };
in
{
  imports = [ "${flox-manifest}/default.nix" ];

  flox.manifestPackages = {
    enable = true;
    manifestFile = ./manifest.toml;
  };
}
```

## Usage

### Basic Home-Manager Usage

```nix
{
  flox.manifestPackages = {
    enable = true;
    manifestFile = ./my-project/.flox/env/manifest.toml;
  };
}
```

### With Flake Package Support

```nix
{ inputs, ... }:
{
  flox.manifestPackages = {
    enable = true;
    manifestFile = ./manifest.toml;
    flakeInputs = inputs;  # Pass flake inputs for flake package resolution
  };
}
```

### NixOS/Darwin System Packages

```nix
{
  flox.manifestPackages = {
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
  flox.manifest.file = ./default/.flox/env/manifest.toml;

  flox.manifestPackages = {
    enable = true;
    # Will use flox.manifest.file
  };
}
```

### Homebrew Integration (macOS)

For nix-darwin users who want to convert Nix packages to Homebrew:

```nix
{
  flox.homebrewManifest = {
    enable = true;
    manifestFile = ./manifest.toml;
  };
}
```

## Configuration Options

### `flox.manifestPackages`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable package installation from manifest |
| `manifestFile` | path | `null` | Path to manifest.toml file |
| `flakeInputs` | attrs | `null` | Flake inputs for resolving flake packages |
| `requireSystemMatch` | bool | `false` | Only install packages matching current system |
| `output` | enum | `"home"` | Where to install: `"home"` or `"system"` |

### `flox.homebrewManifest` (Darwin only)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Homebrew package installation |
| `manifestFile` | path | `null` | Path to manifest.toml file |
| `mappingFile` | path | `./config/mapping.toml` | Nix → Homebrew mapping file |

### `flox.manifest`

| Option | Type | Description |
|--------|------|-------------|
| `file` | path | Global default manifest path |

## Manifest Format

This module reads standard Flox `manifest.toml` files:

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

1. Reads the Flox `manifest.toml` file
2. Parses the `[install]` section for package definitions
3. Resolves packages from nixpkgs or flake inputs
4. Filters by system compatibility (if enabled)
5. Installs to `home.packages` or `environment.systemPackages`

## Limitations

- Flake packages require passing `flakeInputs` option
- Homebrew mapping requires maintaining the mapping file
- System filtering is opt-in (defaults to installing all packages)

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT License - See LICENSE file for details

## Credits

Created for use with [Flox](https://flox.dev) manifest files in Nix/NixOS environments.
