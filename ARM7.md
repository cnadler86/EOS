# ARM7 (armv7l) Compatibility

This document describes the configuration required to run akkudoktor-eos on **ARMv7 (32-bit)** devices such as the Raspberry Pi 2/3/4 (running a 32-bit OS).

Only **Python 3.13** is supported on ARMv7.

---

## How It Works

[piwheels.org](https://www.piwheels.org/) provides pre-built binary wheels for ARMv7 (`linux_armv7l`). Without piwheels, pip would attempt to compile packages from source, which often fails on Raspberry Pi due to missing build toolchains or excessive build times.

`pyproject.toml` includes piwheels as an extra index for `uv`:

```toml
[tool.uv]
index-strategy = "unsafe-best-match"

[[tool.uv.index]]
name = "piwheels"
url = "https://www.piwheels.org/simple/"
marker = "platform_machine == 'armv7l'"
```

`marker = "platform_machine == 'armv7l'"` restricts piwheels to armv7l resolutions only — it is never consulted on x86_64, aarch64, or other platforms. `index-strategy = "unsafe-best-match"` is required because piwheels only carries a subset of packages and versions; without it, uv stops at the first index containing a package and fails if the pinned version isn't there.

When using plain `pip`, add piwheels to your pip configuration:

```ini
# ~/.pip/pip.conf  (or /etc/pip.conf for system-wide)
[global]
extra-index-url = https://www.piwheels.org/simple/
```

---

## ARMv7-specific Version Changes

Certain packages require version downgrades on ARMv7 because the versions pinned for other platforms have not yet been built (or are permanently skipped) on piwheels. These are handled automatically via `platform_machine == 'armv7l'` environment markers in `pyproject.toml`.

### Direct Dependencies

| Package | Other platforms | ARMv7 | Reason |
|---|---|---|---|
| `psutil` | `7.2.2` | `6.0.0` | psutil 7.x entirely skipped on piwheels ([issue #580](https://github.com/piwheels/packages/issues/580)); 6.0.0 uses stable ABI (abi3), compatible with Python 3.13 |
| `deap` | `1.4.3` | `1.4.2` | deap 1.4.3 has no cp313 armv7l wheel on piwheels; 1.4.2 has cp313 |
| `scipy` | `1.17.1` | `1.17.0` | scipy 1.17.1 was "Build pending" on piwheels at time of pinning; 1.17.0 has cp313 armv7l |

### Transitive Dependencies (explicitly pinned for ARMv7)

| Package | Other platforms | ARMv7 | Reason |
|---|---|---|---|
| `pillow` | `12.1.1` (via matplotlib) | `12.1.0` | pillow 12.1.1 has only cp311 armv7l on piwheels, no cp313; 12.1.0 has cp313 |

---

## Verified ARMv7/cp313 Availability on piwheels

The following packages were verified to have Python 3.13 armv7l wheels available at their pinned versions. No version changes are required for these.

| Package | Version | Notes |
|---|---|---|
| numpy | 2.4.2 | cp313 armv7l |
| scipy | 1.17.0 | cp313 armv7l (ARM7 pin) |
| pandas | 3.0.1 | cp313 armv7l |
| matplotlib | 3.10.8 | cp313 armv7l |
| contourpy | 1.3.3 | cp313 armv7l (matplotlib dep) |
| kiwisolver | 1.4.9 | cp313 armv7l (matplotlib dep) |
| pillow | 12.1.0 | cp313 armv7l (ARM7 pin; matplotlib dep) |
| pyyaml | 6.0.3 | cp313 armv7l (bokeh dep) |
| statsmodels | 0.14.6 | cp313 armv7l |
| pendulum | 3.2.0 | cp313 armv7l |
| pydantic-core | 2.41.5 | cp313 armv7l (also in PyPI manylinux_2_17_armv7l) |
| cachebox | 5.2.2 | cp313 armv7l |
| lmdb | 1.7.5 | cp313 armv7l |
| tzfpy | 1.1.1 | cp310-abi3 armv7l (stable ABI, compatible with 3.13) |
| h5py | 3.15.1 | cp313 armv7l (pvlib dep) |
| psutil | 6.0.0 | cp313 abi3 armv7l (ARM7 pin) |

Pure-Python packages (no binary component, platform-independent):

| Package | Notes |
|---|---|
| bokeh | py3-none-any |
| pvlib | py3-none-any |
| pydantic | py3-none-any |
| fonttools | py3-none-any (matplotlib dep) |
| numpydantic | py3-none-any |
| fastapi, fastapi-cli, uvicorn | py3-none-any |
| requests, loguru, linkify-it-py | py3-none-any |
| markdown-it-py, mdit-py-plugins | py3-none-any |
| pydantic-settings, pydantic-extra-types | py3-none-any |
| platformdirs, babel, beautifulsoup4 | py3-none-any |

---

## Installation on ARMv7

### Using uv (recommended)

```bash
# Install uv on the Raspberry Pi
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install the project (piwheels is already configured as extra index)
uv sync
```

### Using pip

```bash
# Configure piwheels globally (or per user in ~/.pip/pip.conf)
pip config set global.extra-index-url https://www.piwheels.org/simple/

# Install
pip install -e .
```

### System Libraries Required on Raspberry Pi OS

Some packages depend on system libraries that must be installed via `apt`:

```bash
# For h5py (used by pvlib)
sudo apt install libhdf5-hl-100 libhdf5-103-1 libaec0 libsz2

# For pillow
sudo apt install libopenjp2-7 libwebpdemux2 libwebpmux3 liblcms2-2
```

---

## Notes on psutil API Compatibility

The ARM7 pin uses `psutil==6.0.0` instead of `7.2.2`. The psutil 7.x release introduced minor API changes. If code in this project relies on psutil 7-specific APIs, those accesses should be guarded with a version check:

```python
import psutil
if psutil.version_info >= (7, 0):
    # psutil 7+ API
    ...
else:
    # psutil 6 fallback
    ...
```

---

## Updating ARM7 Pins

Check piwheels status for a package:

```
https://www.piwheels.org/project/<package-name>/
```

When a newer version becomes available on piwheels, update the ARM7 marker line in `pyproject.toml` and re-run `uv lock`.
