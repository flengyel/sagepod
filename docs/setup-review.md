# Sage 10.10 validation record

The container and optional native-build helpers default to Sage 10.10. This
record summarizes the container build and runtime checks performed on
**2026-10-15**. The [README](../README.md) gives the current installation and
update commands; [setup provenance](setup-provenance.md) describes the setup
incorporated from SageQueue.

The complete earlier review and results for superseded configurations remain in
[repository history](https://github.com/flengyel/sagepod/blob/462273ca490e67112edd9dc6aa7e4496e19c3614/docs/setup-review.md).

## Host and platform coverage

| Component | Tested configuration |
| --- | --- |
| Host distribution | Debian 13.7 under WSL2, x86-64 (`linux/amd64`). |
| Kernel | `6.6.87.2-microsoft-standard-WSL2`. |
| Container runtime | Rootless Podman 5.4.2, `slirp4netns`, `cgroupfs`, file event logging. |
| Host storage | ext4 with working ownership mappings and access-control lists (ACLs); SELinux disabled. |
| Container identity | User and group `1000:1000`. |

These tests exercised Debian under WSL2. A complete SagePod image build and
runtime test on a native Linux host without WSL has not been recorded. The
README provides package and setup instructions for native Debian and Ubuntu;
other host distributions, CPU architectures, and SELinux relabeling remain
unvalidated.

## Image build

The tested upstream image was
`ghcr.io/sagemath/sage/sage-debian-trixie-standard-with-targets-optional:10.10`,
with manifest digest
`sha256:73c6da0bf0186dc05838a6d184d33fa1bd0f962aba069a299a0b4bbfc2e08cda`.
Its 26 layers, totaling about 4.05 GiB compressed, were pulled during validation.
The base supplied Sage 10.10, Python 3.13.5, and GCC 14.2.

`Containerfile` compiled and installed `pycryptosat==5.11.21` from source in
Sage's Python environment and registered the Sage Jupyter kernel. Installation
ran as root inside the image build. Kernel discovery, module-location checks,
and satisfiable and unsatisfiable (SAT/UNSAT) solver checks passed as runtime
user `1000:1000`. Both the compiled module and the kernelspec were available
outside the mounted home directories.

The resulting image was `localhost/sagepod-sagemath:10.10-pycryptosat`, with ID
`5268b48bd5b27df1c415b5578da10884f588894c3982f0bd7c02873c48ce7caf`.
The compiled module was
`/sage/local/var/lib/sage/venv-python3.13/lib/python3.13/site-packages/pycryptosat.cpython-313-x86_64-linux-gnu.so`.

## Isolated compatibility and persistence checks

Compose project `sagepod1010validation`, container `sagepod1010-validation`,
localhost port 8890, and temporary sources for all six mounts isolated the test
from the existing SagePod and SageQueue installations. The existing containers'
IDs, images, PIDs, and start times, and SageQueue's persistent unit states,
matched the baseline throughout this phase.

| Check | Recorded result |
| --- | --- |
| Sage and solver | Sage 10.10, Python 3.13.5, pycryptosat 5.11.21; matrix determinant, GF(2) polynomial arithmetic, GF(256), CryptoMiniSat XOR SAT/UNSAT, and the SAT factory passed. |
| Mounts | The actual permission helper prepared all six temporary paths. Host and container read, created, and edited files with inherited ACLs; existing 0600/0700 fixtures retained contents and executable status. |
| Jupyter | Authenticated status and notebook requests returned HTTP 200 through localhost and 127.0.0.1. A fresh Sage kernel factored 1023 and passed CryptoMiniSat SAT/UNSAT checks over the notebook WebSocket API. |
| Persistence | All 25 saved notebook/probe checksums matched with the container removed and after recreation. The saved notebook reopened, and both cells ran successfully in the new container. |
| Host checks | All 19 regression tests then present passed, as did Bash syntax, ShellCheck, dependency, and whitespace checks. The repository Containerfile matched the successful build recipe. |

The isolated container and pod were removed afterward. Graphical UI behavior
and Windows-browser forwarding were not tested. Other Sage tags against the
Trixie base were outside this validation.

## Production upgrade

The existing Jupyter API reported no active sessions or kernels immediately
before the upgrade. All six production mount trees were backed up with ACLs and
extended attributes, and SHA-256 checksums were recorded for the 11 preexisting
files under the notebook directory.

`man-down.sh` removed the previous container. `man-up.sh --no-follow` started the
tested Sage 10.10 image with the same six production mounts and host port 8889.
Runtime checks passed for the compiled solver and writes in every mount.
Authenticated status, kernelspec, and notebook requests returned HTTP 200
through localhost and 127.0.0.1. A temporary Sage kernel confirmed the Sage
version, arithmetic, and CryptoMiniSat SAT/UNSAT behavior, then was shut down.
All 11 notebook-directory checksums matched after the upgrade.

SageQueue retained its container ID, image, PID, start time, and persistent unit
states. SagePod was left running Sage 10.10 with Python 3.13.5 and
`pycryptosat==5.11.21` at the end of that validation.

## Helper checks and native-build limits

A follow-up audit on the same date aligned the optional native-build workflow
with Sage 10.10. Its prerequisites came from the selected Sage release's Debian
metadata. Its post-installation helper used source-built `pycryptosat==5.11.21`
and Notebook 7, JupyterLab 4, ipywidgets 8, and JupyterLab widgets 3.

All 26 host tests passed, including native command routing, source/runtime
version checks, prerequisite dry-run behavior, and failure handling. All shell
scripts passed Bash syntax checks and ShellCheck. Local documentation links and
anchors passed validation. A temporary container exercised the native
prerequisite dry run against the real Sage 10.10 metadata. The updated diagnostic
helpers passed against the running SagePod 10.10 container, including solver and
mount checks.

The [native Sage source-build helpers](../compiling_sage/README.md) are separate
from the container workflow. A complete native Sage compilation was not run for
that helper update; the prerequisite dry run and substituted-command tests do
not establish a successful native compilation.
