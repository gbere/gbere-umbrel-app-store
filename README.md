# gBere Umbrel App Store ☂️

This is a community-driven and independently maintained [Umbrel Community App Store](https://github.com/getumbrel/umbrel-community-app-store). It allows you to install apps on your [umbrelOS](https://umbrel.com/) device that are not (yet) available in the official Umbrel App Store.

## How to install this app store

1. Open the **App Store** on your umbrelOS device.
2. Click the **⋯** (three dots) in the top right corner and select **Community App Stores**.
3. Paste the URL of this repository and click **Add**:

   ```
   https://github.com/gbere/gbere-umbrel-app-store
   ```

4. Click **Open** next to *gBere Umbrel App Store* and install any app from the list below.

## Currently available apps

| Nr. | Logo | App-Name | Description | Port |
| :-: | :--: | -------- | ----------- | :--: |
| 1 | <img src="https://raw.githubusercontent.com/gbere/gbere-umbrel-app-gallery/main/gbere-power-nut/logo.png" width="50" height="50"> | [Network UPS Tools](https://github.com/networkupstools/nut) | Monitor and manage your UPS with NUT. Includes the [PeaNUT](https://github.com/Brandawg93/PeaNUT) web dashboard to check battery charge, load and runtime from your browser. | 3494 |
| 2 | <img src="https://raw.githubusercontent.com/gbere/gbere-umbrel-app-gallery/main/gbere-home-egress/logo.png" width="50" height="50"> | [Home Egress](gbere-home-egress) | Lend your home connection to one server you own, for a short list of websites only. Outbound reverse SSH tunnel plus a domain-allowlisted proxy: no port opened at home, no access to your device or network. | 3495 |

## About Network UPS Tools (NUT)

[Network UPS Tools](https://networkupstools.org/) is a collection of programs which provide a common interface for monitoring and administering UPS, PDU and SCD hardware.

This app packages two services:

- **NUT server (`upsd`)** — talks to your UPS over USB (driver `nutdrv_qx`) and exposes the standard NUT TCP protocol on port `3493`, so external clients such as `upsmon`, Home Assistant or other PeaNUT instances can connect to `umbrel.local:3493`.
- **PeaNUT web dashboard** — the interface behind the app's **Open** button (port `3494`), showing your UPS status (battery charge, load, estimated runtime, variables, etc.) in the browser.

### Credentials

The NUT username and a unique per-install password are shown in the app's page in umbrelOS (click the app icon). Use them to connect your NUT clients:

- **Host:** `umbrel.local` (or your device's IP)
- **Port:** `3493`
- **Username:** `upsmon`
- **Password:** shown in the umbrelOS app page

### Example: Home Assistant

Add the [NUT integration](https://www.home-assistant.io/integrations/nut/) in Home Assistant and point it to `umbrel.local:3493` with the credentials above.

## About Home Egress

Some websites refuse visitors coming from datacenter addresses. Home Egress lets a server you own reach a short list of such sites through your home internet connection instead — and nothing else.

This app runs one unprivileged container (read-only filesystem, no capabilities, no published ports) with two jobs:

- **Allowlisted HTTP proxy** — forwards only to the domains you list, subdomains included, on ports 80 and 443. Everything else is refused. The check also covers the address a name resolves to: a listed domain that points at a private, loopback or link-local address is refused too, so your local network cannot be reached through it. The list starts empty: nothing is forwarded until you add a domain.
- **Reverse SSH tunnel** — an outbound connection from your Umbrel to your server that publishes the proxy there. Because the connection always starts at home, you need no open port, no port forwarding and no static IP address; it reconnects on its own when the line drops or the address changes.

The app's **Open** button (port `3495`) shows the status page, behind umbrelOS authentication: the tunnel's state, the public key, the destination and the allowed domains.

### Setup

1. Install the app and open it. A key pair is generated on first start; copy the **public key** shown.
2. On your server, authorise that key for the account the tunnel will use, restricted so it can do nothing but open the tunnel port. In that account's `~/.ssh/authorized_keys`:

   ```
   restrict,port-forwarding,permitlisten="127.0.0.1:1080",permitopen="127.0.0.1:1",command="/usr/sbin/nologin" ssh-ed25519 AAAA... home-egress
   ```

   `restrict` removes the terminal, agent and X11 forwarding; `command` removes the ability to run anything; `permitlisten` limits the key to that one listening port; `permitopen` points outgoing forwards at a dead end. Use a dedicated account with no password and no sudo rights.
3. Back in the app, enter the **destination** as `user@server` or `user@server:port` and save. The server's host key is pinned on the first connection; a different key later is refused.
4. Enter the **allowed domains**, one per line, and save. The change applies immediately.
5. On the server, point your client at the proxy: `http://127.0.0.1:1080`.

The proxy is published on the server at `127.0.0.1:1080` by default; change it under **Listen address on the server** if the client that needs it cannot reach the server's loopback (a container, for instance). A stock `sshd` only honours a non-loopback address when `GatewayPorts clientspecified` is set, and `permitlisten` must name the same address and port. The proxy has no password of its own: never publish it on an address the internet can reach.

### What a compromised server could do

Reach the allowed domains from your home IP address. It cannot open a shell on your Umbrel, reach other devices on your network, or browse anything not on the list.

## Support

If you find an issue with an app packaged in this store, please [open an issue](https://github.com/gbere/gbere-umbrel-app-store/issues) in this repository. Home Egress is maintained here. For issues with NUT itself, see the [NUT support page](https://networkupstools.org/support.html).
