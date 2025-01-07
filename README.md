# Light-mosdns
A mosdns management script for quickly deploying a clean mosdns service in a suitable network environment.

## Features
- Supports automatic installation of release versions [mosdns](https://github.com/IrineSistiana/mosdns/releases)
- Supports installation of custom mosdns versions
- Uses BGP source CNIP
- Caches domain name resolution results for mainland China
- Passes through ECS information requests
- Hijacks custom domain name resolution

## Options
1. Install mosdns
    ```bash
    $ ./light-mosdns.sh install -r
    ```
2. Automatically update rules
    ```bash
    $ ./light-mosdns.sh install -a
    ```

## Usage
```bash
$ git clone https://github.com/wikeolf/light-mosdns.git
$ cd light-mosdns
$ chmod +x light-mosdns.sh
$ ./light-mosdns.sh
```
