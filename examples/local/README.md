# Local example

Applies circuit-uptimekuma to a throwaway Rocky Linux 10 container with systemd. You need Conn3x and Podman.

Uptime Kuma runs under Podman inside that container, so the host container is privileged, which is simplest with rootful Podman. On a Mac, use the Podman machine's root connection. On Linux, use `sudo podman`:

```sh
export CONTAINER_CONNECTION=podman-machine-default-root   # macOS
export PODMAN="sudo podman"                               # Linux
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The first apply takes a few minutes: it installs Podman, pulls Uptime Kuma's image and waits for it to listen. The second plan says `No changes.`

Uptime Kuma listens on `127.0.0.1:3001` inside the container. To see the dashboard, forward that port over SSH, then open `http://localhost:3001` and create the admin:

```sh
ssh -p 2222 -i id_ed25519 -o UserKnownHostsFile=known_hosts -L 3001:127.0.0.1:3001 root@127.0.0.1
```

[`check.js`](check.js) is what CI runs instead of a browser. It talks to Uptime Kuma over the same socket.io API the dashboard uses: `setup` creates the admin `admin` with a test password and two monitors, and `verify` logs in again and waits for their next results. Run it with Node inside Uptime Kuma's container:

```sh
podman exec -i circuit-uptimekuma podman exec -i uptime-kuma node - setup < check.js   # sudo podman on Linux
```

`up.sh` listens on `127.0.0.1:2222`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINER_NAME` to name the container something other than `circuit-uptimekuma`, and pass it to `down.sh` too. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` removes the container, its volumes, the key and the state.
