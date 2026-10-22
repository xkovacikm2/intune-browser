# On-demand Intune browser

Experimental Ubuntu 24.04 container with Microsoft Edge, the Intune app, and
Microsoft's identity broker. Windows appear directly on the Linux host's X11
desktop. No full desktop, VM, host D-Bus connection, or privileged container is
used.

**Containers are not a Microsoft-supported Intune enrollment target.** Successful
startup does not prove enrollment or Conditional Access will work. Your
organization must permit this setup; compliance checks can reject it. This
project does not bypass checks or report fabricated compliance.

## Requirements

- An x86-64 Linux host with Docker, Bash, `flock`, and `xauth`.
- A local X11 display with a valid authentication cookie.
- Permission from your organization to enroll this environment.

## First use

```sh
./browser build
./browser password
./browser enroll
```

`password` sets the container user's password, not your host password. It may be
needed for compliance. In the Intune window, sign in and complete enrollment.
Close the window when finished. GNOME Keyring may ask you to create or unlock an
encrypted keyring; use a nonempty password. The container does not automatically
unlock it, and its password need not match the container account password.
Each launch checks that both the `default` and `login` keyring aliases can store
and retrieve a temporary test value (deleted immediately afterward).
Microsoft's broker explicitly writes to `login`, a reserved GNOME alias that
cannot be mapped to another keyring. If the login keyring is missing, a dialog
asks for a nonempty password and creates it through GNOME Keyring's normal
login/unlock mechanism. Existing keyrings are preserved. This prompts for an unlock before
Intune or Edge starts, rather than letting the broker fail later while caching
credentials. Canceling the prompt aborts the launch.

Then open Edge and sign into its work profile using the same organization account:

```sh
./browser open 'https://your-work-resource.example'
```

Close all Edge windows to stop the container. Background mode is disabled. Only
one session can run at a time. `./browser stop` also stops a session.

## Persistence and updates

The stopped container `workutils-intune-browser` retains its own machine ID,
enrollment, keyring, and browser profile. It uses no running processes while
stopped and has no preallocated virtual disk or RAM reservation. Disk use grows
with installed packages and browser data; this is not an Alpine-sized image.

**Do not remove or clone the enrolled container.** Its writable layer holds the
device identity and credentials, not a separate backup volume. Rebuilding the
image does not upgrade an existing container. To update that container:

```sh
./browser update
./browser status
./browser logs
```

Updates stop the container when finished. For a fresh device, first retire the
old enrollment using your organization's procedure. Never publish an enrolled
container as an image.

## Isolation and limitations

- Root services run inside the container; Edge and the portal run as UID 1000.
- The container has a private system bus and each launch has a private session
  bus and keyring service. The host's home directory and enrollment are not
  mounted.
- X11 access uses a temporary copy of your display cookie, not `xhost +`.
  **X11 clients can observe or interact with other applications on that display.**
  This is not a strong desktop isolation boundary.
- Edge's sandbox stays enabled. `browser-seccomp.json` is Docker's default
  seccomp profile with `clone` and `unshare` allowed for its namespace sandbox.
  No additional Linux capabilities or unconfined AppArmor mode are requested.
  The host must permit unprivileged user namespaces.
- Intune's system daemon binds its own private Unix socket; the identity device broker is
  supervised alongside a private D-Bus daemon and private system journal.
  Journal storage is bounded to 32 MB and its live output appears in
  `./browser logs`. Logs may contain account and organization details; redact
  them before sharing. There is no full systemd or
  GNOME login session, and Intune's systemd user timer is not run. Use the portal
  to check/synchronize device status as needed.
- Password/PAM tracking, encrypted-disk detection, hardware identity, Defender,
  and policies requiring a real login session may not work in a container.
  A normally installed Ubuntu VM working does not establish container compliance.
- Your organization can see/manage the enrolled environment. Keeping it stopped
  can make its compliance stale; open the portal to synchronize before retrying.
- Audio, camera, microphone, GPU acceleration, and smart-card devices are not
  passed through. GTK4 dialogs use the Cairo renderer to avoid GL/X11 shared
  memory requirements across the container boundary.

## Seccomp provenance

`browser-seccomp.json` is derived from Moby's
[`seccomp/default.json`](https://github.com/moby/profiles/blob/4b8214fc4971e06172938a1f1554ccff6647ee80/seccomp/default.json)
at commit `4b8214fc4971e06172938a1f1554ccff6647ee80`. The only change is an appended
`SCMP_ACT_ALLOW` rule for `clone` and `unshare`. The upstream Apache 2.0 license
is included as `docker-seccomp.LICENSE`.

## Local checks

After building, `./test` checks service startup, sandboxed headless rendering,
machine-ID persistence across restarts, and clean shutdown in a disposable
container. It does not enroll a device or test organization access. Its
`--password-store=basic` flag is only for that credential-free rendering check;
normal sessions use GNOME Keyring.

Microsoft documentation:
[Linux enrollment](https://learn.microsoft.com/en-us/intune/user-help/enrollment/enroll-linux)
and [Intune app installation](https://learn.microsoft.com/en-us/intune/user-help/company-portal/intune-app-linux).
