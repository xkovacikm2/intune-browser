FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg \
    && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main' \
        > /etc/apt/sources.list.d/microsoft-intune.list \
    && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main' \
        > /etc/apt/sources.list.d/microsoft-edge.list \
    && apt-get update

RUN apt-get install -y --no-install-recommends \
        dbus dbus-user-session dbus-x11 fonts-liberation \
        gnome-keyring libpam-systemd libsecret-tools microsoft-edge-stable \
        procps tini xauth xdg-utils zenity

# Intune's postinst assumes that this directory means systemd is running.
RUN if [ -d /run/systemd/users ]; then rmdir /run/systemd/users; fi \
    && apt-get install -y --no-install-recommends intune-portal \
    && pam-auth-update --package \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN usermod --login browser --home /home/browser --move-home ubuntu \
    && groupmod --new-name browser ubuntu \
    && install -d -o browser -g browser -m 0700 /home/browser \
    && truncate -s 0 /etc/machine-id \
    && rm -f /var/lib/dbus/machine-id \
    && ln -s /etc/machine-id /var/lib/dbus/machine-id

COPY --chmod=0755 container-init container-session /usr/local/bin/
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/container-init"]
