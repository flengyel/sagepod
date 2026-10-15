# Standalone setup review — 2026-10-15

The revised setup removes SagePod's repository-level dependency on SageQueue.
Host-side checks and live validation pass on Debian 13 under WSL2, including the
rootless image build, mount access, Jupyter Sage execution, and persistence after
container removal and recreation. Live validation found and repaired the image
installation and inherited-ACL defects described below.

## Documentation scope and source

The editorial review covers the complete original `README.md` at SagePod commit
`3c70e9b7aa7db49c1bc7434b0d11c8b4451ba597`, the SageQueue installation instructions
at `80140ea1d2d0053b8015dc9092812fabd0c0e053`, and the revised SagePod README and
setup provenance. The separate `compiling_sage/` workflow is outside this review.
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
- The tested configuration is Sage 10.7 on this WSL2/ext4 host with SELinux
  disabled. Other Sage versions, hosts, and SELinux relabeling remain untested.
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
