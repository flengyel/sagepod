# Standalone setup review — 2026-10-15

The revised setup removes SagePod's repository-level dependency on SageQueue.
Host-side checks pass. A rootless Podman image build and live Jupyter session
remain unverified in the editing environment.

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

## Verification and limits

- Eighteen regression tests pass, including real configuration rendering with
  `podman-compose==1.3.0`; orchestration tests replace Podman with command substitutes.
- All fourteen active shell scripts pass Bash syntax checks and ShellCheck 0.11.0.
- `bin/venvfix.sh` was run from outside the checkout with real Python and pip. The
  pinned packages installed successfully, `pip check` passed, and Compose reported
  version 1.3.0 without invoking Podman.
- The diff passes whitespace checks. Active setup and runtime code has no SageQueue
  path or image dependency; source attribution remains in documentation/comments.
- The environment lacks Podman and rejects user-namespace creation with
  `Operation not permitted`. Consequently, the image build, rootless ACL changes,
  live solver execution, and browser access to Jupyter have not been tested here.
  The on-host acceptance procedure is `bin/setup.sh`, `bin/verify.sh`, and a Sage
  notebook cell at the printed Jupyter URL.

The source files and documentation were reviewed directly. No rendered Markdown
or notebook UI was inspected. The source-build helpers under `compiling_sage/` were
retained and were not validated by these checks.
