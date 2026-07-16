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

## Support

If you find an issue with an app packaged in this store, please [open an issue](https://github.com/gbere/gbere-umbrel-app-store/issues) in this repository. For issues with NUT itself, see the [NUT support page](https://networkupstools.org/support.html).
