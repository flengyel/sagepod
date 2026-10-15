# Standalone setup review — 2026-10-15

## Current validated release

SagePod currently defaults to **Sage 10.10 on Debian Trixie**, with Python 3.13.5
and source-built `pycryptosat==5.11.21`. The running container uses this image.
See [Sage 10.10 upgrade validation](#sage-1010-upgrade-validation--2026-10-15)
for the build, solver, Jupyter, persistence, and production-upgrade results.
The [native source-build helpers](../compiling_sage/README.md) also default to
Sage 10.10; a complete native host build remains outside the container validation.

The earlier Sage 10.7 and 10.8 sections below preserve the versions and results
observed during those historical tests. References to 10.8 in the migration
instructions describe the retained rollback image.

The revised setup removes SagePod's repository-level dependency on SageQueue.
Host-side checks and live validation pass on Debian 13 under WSL2, including the
rootless image build, mount access, Jupyter Sage execution, and persistence after
container removal and recreation. Live validation found and repaired the image
installation and inherited-ACL defects described below.

## Documentation scope and source

The editorial review covers the complete original `README.md` at SagePod commit
`3c70e9b7aa7db49c1bc7434b0d11c8b4451ba597`, the SageQueue installation instructions
at `80140ea1d2d0053b8015dc9092812fabd0c0e053`, and the revised SagePod README and
setup provenance. That original review excluded the separate `compiling_sage/`
workflow; its later update is documented in the native-build instructions.
There are no mathematical theorems or proofs in the reviewed material.

The governing source consulted was Donald E. Knuth, Tracy Larrabee, and Paul M.
Roberts, [*Mathematical Writing*, Stanford report CS-TR-88-1193](https://www-cs-faculty.stanford.edu/~knuth/papers/cs1193.pdf),
Section 1 (printed pages 1–6; PDF pages 3–8) and Section 13 on user manuals
(printed pages 28–30; PDF pages 30–32). The applications below concern technical
exposition; they do not certify the software.

## Original outline

| Original section, in reading order | Function |
| --- | --- |
| Opening and restore model | Describe the container and its default paths, image, and port. |
| Prerequisites: WSL2 with systemd; required Debian/Ubuntu packages; rootless Podman defaults for WSL2 | Prepare the host. |
| Shared Sage image | Send the reader to SageQueue for setup and image creation. |
| Bind-mount directories | List persistent paths and repair permissions. |
| Start and stop | Run Jupyter and access logs and a shell. |
| Validation | Check the container and solver import. |
| Compose notes | Show image, port, and network settings. |
| Troubleshooting: missing Compose; nftables error; GHCR TLS error; runtime-directory permissions; wrong container name | Repair common failures. |
| License | State MIT licensing. |

The central task is to install and operate SagePod from one checkout. The original
outline described an existing two-repository installation and supplied no SagePod
bootstrap command.

## Findings and implemented repairs

| Original anchor | Difficulty | Source principle or editorial rationale | Repair |
| --- | --- | --- | --- |
| Opening; “Shared Sage image” | Installation depends on another checkout. | Independent technical requirement: the requested repository must contain its setup. Section 1, point 12 supports explaining the reader's next step. | State the standalone scope, then give a single clone-and-setup sequence. |
| Prerequisites; missing-Compose troubleshooting | Compose paths lead to SageQueue, while local repair deletes checkout directories. | Independent correctness finding; Section 13 supports actionable recovery instructions. | Document `.venv`, the local repair command, and its precise deletion scope. |
| Bind-mount directories | Manual follow-up commands repair directories omitted by the helper. | Section 1, point 14 supports consistent names; the missing operations are a technical defect. | Use one six-directory mapping and one permission helper. |
| Validation; Compose notes; wrong-container troubleshooting | Container names and image ownership are inconsistent across commands. | Section 1, point 14, applied to identifiers in prose and code. | Use the same configured container name in Compose and every helper. |
| Start and stop | Persistence and the effect of stopping log following are unstated. | Section 13 discusses explaining how to leave or recover from an operation. | Distinguish stopping logs, stopping the container, persistent files, and kernel state. |
| TLS troubleshooting | An environment-specific workaround is presented as the general cause. | Independent scope correction. | Diagnose the reported trust or proxy failure without prescribing one vendor's configuration. |

The revised opening is: “SagePod runs SageMath and Jupyter in a rootless Podman
container on Linux or WSL2.” It immediately identifies the included setup and
CryptoMiniSat support, the absence of a SageQueue requirement, and the remaining
upstream downloads. The installation command is `bin/setup.sh`; repair commands
stay next to the conditions that require them.

## Definitions and revised order

ACL is expanded at its first use. The configuration table identifies each variable
before override examples. The persistent-data section explains a bind mount before
listing host and container paths. Host port 8889 is distinguished from container
port 8888. `.sagepod-local` retains its existing target `/home/sage/.local`.
No mathematical notation or definition-order changes are required.

The revised sequence is: prerequisites (including WSL2), installation, start and
stop, configuration, persistent data, rebuilding and repair, migration from the
shared-image installation, troubleshooting, repository contents, and license.
The installation procedure is moved ahead of storage and configuration detail so
that the reader can first follow a complete working sequence. Reference detail
remains available in tables; it is not duplicated as a second setup procedure.

## Live validation — 2026-10-15

The checkout was fetched and switched to `codex/self-contained-setup` at published
commit `c5c4438a3288ccacbdcd08866148c6b672bf9238`. The local untracked `txt` file was
preserved. No applicable `AGENTS.md` was present. Container operations ran as the
normal host user outside the editing sandbox; the sandbox mounts Podman's runtime
directory read-only and blocks host network access.

### Host prerequisites and notebook activity

- Debian 13.7, WSL2 kernel `6.6.87.2-microsoft-standard-WSL2`, systemd as PID 1,
  and `systemd=true` in `/etc/wsl.conf`.
- The documented packages `git`, `podman`, `slirp4netns`, `uidmap`, `acl`, and
  `python3-venv` were installed. Podman 5.4.2 reported rootless operation,
  `cgroupfs`, file event logging, and `slirp4netns`.
- Both UID and GID maps were `0 -> 1000` for one ID and `1 -> 100000` for 65536
  IDs. Container user/group 1000 map to host `100999:100999`. The data directories
  reside on ext4, and actual recursive ownership and ACL operations succeeded.
- The existing SagePod Jupyter server reported empty session and kernel lists
  and zero connections. These checks were repeated immediately before stopping
  it with `./man-down.sh`. No user notebooks were present in `~/Jupyter`.
- SageQueue's `sagemath` container and twelve service/timer/slice units were
  recorded before testing. No SageQueue container or service commands were used
  to change their state.

### Defects found and repaired

1. The initial image build compiled `pycryptosat` but failed to install it because
   Sage's base-image Python environment is root-owned. `Containerfile` now installs
   the package as root inside the image build, then switches to `1000:1000` before
   testing the module location and solver. Runtime remains `1000:1000`.
2. Recursive `setfacl ... rwX` could expose inherited execute entries that had
   been masked off on a nonexecutable file. The permission helper now classifies
   directories and executable files by their mode and sets explicit ACL masks
   separately for nonexecutable files. A new regression test uses real inherited
   ACLs across all six mount paths and repeats the repair twice; namespace entry,
   UID mapping, and ownership changes are substituted in this host-side test.

### Results after repair

| Check | Actual result |
| --- | --- |
| `bin/venvfix.sh` | Pinned requirements installed with real Python 3.13 and pip; `pip check` passed; Compose reported 1.3.0. |
| `bin/setup.sh` | Passed; repaired all six mount trees, built `localhost/sagepod-sagemath:10.7-pycryptosat`, and started SagePod. A subsequent setup reused the image and environment. |
| Image build | Source-built `pycryptosat==5.11.21`; module-location and SAT/UNSAT checks passed as user `1000:1000`. Image ID: `e4fe4933876a015f25743db714f06e02750e72d415dbc5d17e13f4e74fc90ca0`. |
| `bin/verify.sh` | Passed before and after container recreation: Sage calculation, CryptoMiniSat SAT/UNSAT, and writes in all six container mounts. |
| Mount ownership and ACLs | Nested fixtures initially using directory mode 0700 and file modes 0600/0700 retained their contents and executable status. Host and container both read, created, and edited files in every mount, including new directories and files inheriting ACLs. |
| Host Jupyter access | Authenticated HTTP 200 for `/api/status` and `/tree` through both `localhost:8889` and `127.0.0.1:8889`. |
| Sage notebook | Jupyter HTTP/WebSocket APIs created a notebook with kernel `sagemath`; `factor(2^10 - 1)` returned `3 * 11 * 31`; a second cell passed CryptoMiniSat SAT/UNSAT assertions. Both outputs were saved and read from the host. |
| Stop and restart | `./man-down.sh` removed SagePod; all 25 notebook/probe SHA-256 checksums remained readable while it was down. `./man-up.sh --no-follow` created a new container ID using the same image. All checksums matched, and the saved notebook reopened and both cells ran successfully again. |
| SageQueue isolation | The `sagemath` container retained its ID, image, PID, and start time. All twelve unit states and worker process timestamps were unchanged. The existing recovery timer continued to run its service automatically. |
| Regression suite | `.venv/bin/python -m unittest discover -s tests -v`: 19 tests passed, none skipped, including real Compose rendering and the new ACL regression. |
| Shell checks | All fourteen active scripts passed Bash syntax checks and ShellCheck 0.10.0 with source lookup via `-x -P SCRIPTDIR`. The earlier editorial pass used ShellCheck 0.11.0. |

The installed module was
`/sage/local/var/lib/sage/venv-python3.12.5/lib/python3.12/site-packages/pycryptosat.cpython-312-x86_64-linux-gnu.so`,
outside every home-directory mount. Validation kernels were shut down after each
notebook run. Temporary probes and the notebook were removed from the data mounts;
the executed notebook and redacted logs remain locally under
`/tmp/sagepod-live-20261015/`. SagePod was left running.

### Remaining limits

- The host already cached the upstream Sage base image and the apt dependency
  layer. The solver source was downloaded and compiled during validation, but a
  completely empty-cache registry pull and apt installation were not repeated.
- This initial validation covered Sage 10.7 on this WSL2/ext4 host with SELinux
  disabled. The subsequent Sage 10.8 validation is recorded below. Other hosts
  and SELinux relabeling remain untested.
- Jupyter was exercised through authenticated HTTP and kernel WebSockets. No
  graphical notebook UI, Windows-browser port forwarding, or rendered Markdown
  was inspected.
- With pinned `podman-compose==1.3.0`, rerunning setup against an existing
  container emits a name-in-use diagnostic before starting that container. The
  command exits successfully, reuses the image, and passes runtime verification;
  a fresh start after `man-down.sh` has no such diagnostic.
- No preexisting user notebooks were available; persistence was demonstrated with
  the generated notebook and controlled files in all six mounts. The separate
  source-build helpers under `compiling_sage/` were not validated.

## Sage 10.8 compatibility validation — 2026-10-15

Sage 10.8 passed an isolated compatibility test with Python 3.12.5 and the existing
`pycryptosat==5.11.21` pin after two image-recipe repairs. The starting checkout was
the merged `main` commit `c0cad3b168a63156b9cd22f5be2043bfc60de214`; the repairs and
this record are on `codex/sage-10-8-validation`. At validation time the default
remained Sage 10.7; the subsequent review changed the default to the validated
Sage 10.8 image with source-built `pycryptosat==5.11.21`.

### Isolation and build repairs

The test used rootless Podman 5.4.2 on the same Debian 13.7/WSL2 host, Compose
project `sagepod108validation`, container `sagepod108-validation`, and host port
`127.0.0.1:8890`. The repository's Compose configuration was rendered with Sage
10.8 and the test container name, then its six host sources were replaced with
temporary directories. Production data directories were not mounted. The actual
permission-helper body was run in `podman unshare` against these temporary paths.
The full production `bin/setup.sh` was not invoked for this isolated test.

The production `sagepod` container was absent at the start and remained absent.
SageQueue's `sagemath` container retained its ID, image, PID, and start time; all
eight worker PIDs and process start times and the other persistent unit states
matched the baseline throughout. Its existing recovery timer continued normally.
The local untracked `txt` file was preserved.

Two failures were found before notebook validation could pass:

1. `build-essential` required `dpkg-dev` and an updated `libdpkg-perl`, whose
   version 1.20.14 archives returned HTTP 404 from Debian security repositories.
   Refreshing all indexes over HTTPS reproduced the failure. The recipe now
   requests `make gcc g++ cmake pkg-config` directly. These required build tools
   were already present in the upstream image, and the apt step succeeded.
2. With fresh data mounts, Jupyter listed only `python3`; no Sage kernelspec was
   discoverable. The image now calls `SageKernelSpec.update()` as build root to
   install the kernel under Sage's Python prefix. A build check as runtime user
   `1000:1000` requires the kernel to be discoverable, use language `sage`, and
   reside outside `/home/sage`. The repaired image was tested with six newly
   prepared temporary mounts, without a preexisting Sage kernelspec.

### Actual results

| Check | Result |
| --- | --- |
| `bin/build-image.sh --sage-tag 10.8` | Passed after the repairs. The upstream 10.8 image was pulled, and `pycryptosat==5.11.21` was downloaded and compiled from source. Subsequent recipe checks reused build layers. |
| Final image | `localhost/sagepod-sagemath:10.8-pycryptosat`, ID `312f10bb456fd26f5ea62d549a8bfdef4e4d113c48f50c591ec2bcd25d50835b`. |
| Runtime identity | Sage 10.8, Python 3.12.5, pycryptosat 5.11.21, UID/GID `1000:1000`; all six mounts and the test project label matched the isolated configuration. |
| `bin/verify.sh` | Passed using `CONTAINER_NAME=sagepod108-validation`, including SAT/UNSAT and all six writable mounts, before and after recreation. |
| Additional Sage calculations | Integer-matrix determinant, polynomial arithmetic over GF(2), and arithmetic in GF(256) passed. |
| Additional solver checks | XOR SAT and UNSAT cases passed through `CryptoMiniSat`; SAT and UNSAT also passed through `SAT(solver='cryptominisat')`. |
| Host/container access | Both sides created, read, and edited files in every mount, including inherited ACLs on new directories and files. Nested 0600 and 0700 fixtures retained their contents and executable status. |
| Jupyter HTTP | Authenticated HTTP 200 for `/api/status` and `/tree` through both `localhost:8890` and `127.0.0.1:8890`. |
| Sage notebook | A `sagemath` kernel evaluated `factor(2^10 - 1)` as `3 * 11 * 31` and passed CryptoMiniSat SAT/UNSAT assertions. Both cell outputs were saved and read from the host. |
| Container removal/recreation | All 25 notebook/probe SHA-256 checksums matched while the container was down and after recreation. The new container used the same image; the saved notebook reopened and both cells ran again. |
| Host regression suite | `.venv/bin/python -m unittest discover -s tests -v`: all 19 tests passed, none skipped, after the image-recipe repairs. `pip check`, local documentation links, and whitespace checks also passed. |

The solver module remained outside the mounts at
`/sage/local/var/lib/sage/venv-python3.12.5/lib/python3.12/site-packages/pycryptosat.cpython-312-x86_64-linux-gnu.so`.
Validation sessions and kernels were shut down after notebook execution. The test
container and its Compose pod were removed after testing; the image, executed
notebook, temporary test data, scripts, and redacted logs are retained locally
under `/tmp/sagepod-108-20261015/`.

This validates the tested SagePod operations with Sage 10.8, rather than every
Sage API or an in-place migration of existing user notebooks and configuration.
The graphical notebook UI, Windows-browser forwarding, SELinux relabeling, and
other hosts were not tested. The complete Sage 10.7 rebuild was not repeated with
the modified recipe; the earlier 10.7 results above predate these two repairs.

## Default version review — 2026-10-15

The follow-up review found that the build, helpers, and Compose configuration
still defaulted to Sage 10.7 despite the successful Sage 10.8 validation. Their
defaults, help text, README, and regression expectations now select Sage 10.8.
Explicit `SAGE_TAG` overrides remain supported.

The existing Sage 10.8 image's build history confirms the source installation of
`pycryptosat==5.11.21`. SagePod was started with that image on host port 8889.
Runtime checks confirmed Sage 10.8, the compiled Python extension, UID/GID
`1000:1000`, SAT/UNSAT solver operation, and writes in all six mounts.
Authenticated Jupyter status and kernelspec requests returned HTTP 200, and a
temporary Sage Jupyter kernel passed arithmetic and CryptoMiniSat SAT/UNSAT
checks before being shut down. All 19 host regression tests, Bash syntax checks,
ShellCheck, dependency checks, and whitespace checks passed. SagePod was left
running.

An isolated Sage 10.7 image build also passed the current recipe's build checks
during review. Its temporary review image was removed afterward.

## Sage 10.10 upgrade validation — 2026-10-15

The upgrade moves the default from Sage 10.8 to
[Sage 10.10](https://github.com/sagemath/sage/releases/tag/10.10). The upstream
Bullseye image repository has no `10.10` tag; registry checks also found no
Bookworm tag. `Containerfile` now uses
`ghcr.io/sagemath/sage/sage-debian-trixie-standard-with-targets-optional:10.10`.
Its manifest digest is
`sha256:73c6da0bf0186dc05838a6d184d33fa1bd0f962aba069a299a0b4bbfc2e08cda`.
The 26 layers, totaling about 4.05 GiB compressed, were pulled during validation.

The Trixie base supplies Python 3.13.5 and GCC 14.2. The existing source-build
command compiled and installed `pycryptosat==5.11.21` for Python 3.13 without a
recipe change beyond the Sage tag and Debian base. The image registered the Sage
kernel as root; kernelspec discovery, module-location, and SAT/UNSAT build checks
passed as runtime user `1000:1000`.
The resulting image is `localhost/sagepod-sagemath:10.10-pycryptosat`, ID
`5268b48bd5b27df1c415b5578da10884f588894c3982f0bd7c02873c48ce7caf`.
The compiled module is
`/sage/local/var/lib/sage/venv-python3.13/lib/python3.13/site-packages/pycryptosat.cpython-313-x86_64-linux-gnu.so`.

### Isolated compatibility and persistence checks

Tests ran on the same Debian 13.7/WSL2 rootless Podman host as the earlier
validation. Compose project `sagepod1010validation`, container
`sagepod1010-validation`, localhost port 8890, and temporary sources for all six
mounts kept the test separate from the running SagePod 10.8 and SageQueue
containers. Their IDs, images, PIDs, start times, and SageQueue persistent unit
states matched the baseline throughout this phase.

| Check | Actual result |
| --- | --- |
| Sage and solver | Sage 10.10, Python 3.13.5, pycryptosat 5.11.21, UID/GID `1000:1000`; matrix determinant, GF(2) polynomial arithmetic, GF(256), CryptoMiniSat XOR SAT/UNSAT, and the SAT factory passed. |
| Mounts | The actual permission-helper body prepared all six temporary paths. Host and container read, created, and edited files with inherited ACLs; existing 0600/0700 fixtures retained contents and executable status. |
| Jupyter | Authenticated HTTP 200 for status and notebook routes through localhost and 127.0.0.1. A fresh Sage kernel factored 1023 and passed CryptoMiniSat SAT/UNSAT checks over the notebook WebSocket API. |
| Persistence | All 25 saved notebook/probe checksums matched with the container removed and after recreation. The saved notebook reopened, and both cells ran successfully in the new container. |
| Host checks | All 19 regression tests, Bash syntax, ShellCheck, dependency checks, and whitespace checks passed. The repository Containerfile matches the recipe used for the successful image build. |

The isolated container and pod were removed after validation. The executed
notebook, temporary test data, scripts, and redacted logs remain under
`/tmp/sagepod-1010-20261015/`. Graphical UI behavior, Windows-browser forwarding,
SELinux relabeling, and other hosts or architectures were not tested. Rebuilding
older Sage tags against the new Trixie base has not been validated.

### Production upgrade

SagePod's Jupyter API reported no active sessions or kernels immediately before
the switch. All six production mount trees were backed up with ACLs and extended
attributes to
`/tmp/sagepod-1010-20261015/backup/sagepod-10.8-data-before-upgrade.tar.gz`.
The backup directory is private to the host user. SHA-256 checksums were recorded
for the 11 preexisting files under the notebook directory.

`man-down.sh` removed SagePod 10.8, and `man-up.sh --no-follow` started the tested
10.10 image using the same six production mounts and port 8889. Runtime checks
passed for the compiled solver and writes in every mount. Authenticated status,
kernelspec, and notebook routes returned HTTP 200 through localhost and
127.0.0.1. A temporary production Sage kernel confirmed Sage 10.10, arithmetic,
and CryptoMiniSat SAT/UNSAT behavior, then was shut down. All 11 notebook-directory
checksums matched after the upgrade.

SageQueue retained its container ID, image, PID, start time, and persistent unit
states. SagePod was left running Sage 10.10 with Python 3.13.5 and
`pycryptosat==5.11.21`. The existing SagePod 10.8 image remains available for
rollback; the README describes selecting it with `SAGE_TAG=10.8`.

### Documentation and helper audit

The follow-up audit updated the optional native-build workflow to the shared
Sage 10.10 default, replaced its Sage 10.5 path and old package/extension commands,
and added native-build instructions. Native prerequisites now come from the
selected release's Debian metadata. The post-installation helper compiles the
same `pycryptosat==5.11.21` pin and uses Notebook 7/JupyterLab 4 widget packages.
Container diagnostics now report the actual Sage and Python versions.

All 26 host tests passed, including native command routing, source/runtime
version checks, prerequisite dry-run behavior, and failure handling. All shell
scripts passed Bash syntax checks and ShellCheck. Local documentation links and
anchors passed validation. A temporary container exercised the native
prerequisite dry run against the real Sage 10.10 metadata. The updated diagnostic
helpers passed against the running SagePod 10.10 container, including solver and
mount checks. A complete native host compilation was not repeated.
