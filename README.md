# Manifest Repository

This repository contains the manifest for managing multiple Git repositories using the `repo` tool. It simplifies the process of checking out and managing a collection of related projects. This setup also utilizes `dotbot` to create symbolic links for configuration files.

## Usage

1.  **Initialize the repo client:**
    ```shell
    repo init -u https://github.com/HIDE-r/Manifest.git -b main
    ```

2.  **Sync all repositories:**
    ```shell
    repo sync
    ```

## Managed Repositories

This manifest manages the following repositories:

| Path              | Repository                  |
| ----------------- | --------------------------- |
| `Manifest`        | `HIDE-r/Manifest`           |
| `.dotbot`         | `anishathalye/dotbot`       |
| `DotFiles`        | `HIDE-r/DotFiles`           |
| `ScriptTools`     | `HIDE-r/ScriptTools`        |
| `Cheatsheet-navi` | `HIDE-r/Cheatsheet-navi`    |
| `CodeDemo`        | `HIDE-r/CodeDemo`           |
| `DockerEnv`       | `HIDE-r/DockerEnv`          |

## Dotbot Integration

This project uses `dotbot` to manage symlinks for configuration files. After running `repo sync`, the following files from the `Manifest` repository will be linked to the root of the workspace:

*   `install.conf.yaml`
*   `.envrc`
*   `Makefile`

To apply the dotbot configuration and create the symlinks, run the following command from the root of your workspace:

```shell
./.dotbot/bin/dotbot -c install.conf.yaml
```