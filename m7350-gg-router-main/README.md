# m7350-gg-router`r`n`r`nGet Rid off TP-Links Softwarelimits.`r`n`r`n## TP-Link M7350 V9 Modding Toolkit

Dieses Workspace-Toolkit arbeitet lokal mit Kopien deiner Dateien. Es ueberschreibt weder die Desktop-Originale noch Dateien auf dem MiFi.

## Dateien

- `tools/oled_res_tool.ps1` - inspect/export/patch fuer `/etc/oled_res`
- `scripts/start_vpn_hardened` - robustere Init-Variante fuer OpenVPN mit `/usrdata/vpn/current.ovpn`
- `scripts/vpn_hardened.sh` - CGI-Control mit optionalem Token
- `scripts/block_tplink_cloud.sh` - optionale `/etc/hosts` Blockliste fuer TP-Link Cloud-Domains
- `scripts/unblock_tplink_cloud.sh` - entfernt diese Blockliste wieder

## OLED/LCD Ressourcen analysieren

Das M7350 V9 Display wird trotz Dateinamen wie `oled_res` als 128x128 RGB565 LCD/TFT behandelt.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\oled_res_tool.ps1 `
  -Command inspect `
  -InputPath C:\Users\fabia\Desktop\oled_res
```

## Bilder exportieren

Nur die 128x128 Vollbildressourcen exportieren:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\oled_res_tool.ps1 `
  -Command export `
  -InputPath C:\Users\fabia\Desktop\oled_res `
  -OutDir .\export_fullscreen `
  -FullScreenOnly
```

Boot-Spinner-Frames 200-211 exportieren:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\oled_res_tool.ps1 `
  -Command export `
  -InputPath C:\Users\fabia\Desktop\oled_res `
  -OutDir .\export_boot_spinner
```

Alle Ressourcen exportieren:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\oled_res_tool.ps1 `
  -Command export `
  -InputPath C:\Users\fabia\Desktop\oled_res `
  -OutDir .\export_all `
  -All
```

## 128x128 Logo in eine Ressource patchen

`gg_logo.raw` passt nur direkt in 128x128 Ressourcen, nicht in die 30x29 Boot-Spinner-Frames.
In der aktuell gezogenen Datei sind alle gefundenen 128x128 Ressourcen komplett schwarz. Sie koennen trotzdem als
vollflaechige Platzhalter/State-Screens von `oledd` verwendet werden.

Beispiel: Ressource `4000` in eine neue Datei patchen:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\oled_res_tool.ps1 `
  -Command patch `
  -InputPath C:\Users\fabia\Desktop\oled_res `
  -RawPath C:\Users\fabia\Desktop\gg_logo.raw `
  -OutputPath .\oled_res_patched_4000 `
  -Ids 4000
```

Experimentelle Variante: alle 128x128 Slots in eine neue Datei patchen:

```powershell
powershell -ExecutionPolicy Bypass -Command "& .\tools\oled_res_tool.ps1 `
  -Command patch `
  -InputPath C:\Users\fabia\Desktop\oled_res `
  -RawPath C:\Users\fabia\Desktop\gg_logo.raw `
  -OutputPath .\oled_res_patched_all_fullscreen `
  -Ids @(3801,3902,3903,3900,3901,4004,4003,4000,4005)"
```

Danach erst pruefen und dann manuell aufs Geraet kopieren:

```powershell
adb push .\oled_res_patched_4000 /tmp/oled_res_patched
adb shell "cp /etc/oled_res /usrdata/vpn/oled_res.backup"
adb shell "cp /tmp/oled_res_patched /etc/oled_res"
adb shell "killall oledd; oledd &"
```

## VPN Web Token

`scripts/vpn_hardened.sh` prueft optional `/usrdata/vpn/web_token`. Wenn die Datei existiert, muessen Requests so aussehen:

```text
/cgi-bin/vpn.sh?action=status&token=DEIN_TOKEN
```

Token auf dem Geraet setzen:

```powershell
adb shell "echo 'DEIN_TOKEN' > /usrdata/vpn/web_token"
```

## VPN Profilstruktur

Die gehärteten Skripte erwarten:

```text
/usrdata/vpn/openvpn
/usrdata/vpn/current.ovpn
/usrdata/vpn/auth.txt
```

Damit kannst du Anbieter oder Server wechseln, indem du nur eine neue `.ovpn` nach `current.ovpn` kopierst.
Lokale Surfshark-Profile liegen absichtlich in `local_vpn_profiles/` und sind per `.gitignore` vom Repo ausgeschlossen.

Surfshark deployen:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy_surfshark.ps1 -Profile udp
```

Oder TCP:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy_surfshark.ps1 -Profile tcp
```

Mit Neustart des VPN-Dienstes:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy_surfshark.ps1 -Profile udp -Restart
```

## Datenschutz-Blockliste

Die Blockliste schreibt nur einen markierten Bereich in `/etc/hosts`:

```powershell
adb push .\scripts\block_tplink_cloud.sh /usrdata/vpn/block_tplink_cloud.sh
adb shell "chmod +x /usrdata/vpn/block_tplink_cloud.sh"
adb shell "/usrdata/vpn/block_tplink_cloud.sh"
```

Rueckgaengig:

```powershell
adb push .\scripts\unblock_tplink_cloud.sh /usrdata/vpn/unblock_tplink_cloud.sh
adb shell "chmod +x /usrdata/vpn/unblock_tplink_cloud.sh"
adb shell "/usrdata/vpn/unblock_tplink_cloud.sh"
```

## Eigenes Webinterface

Die erste Version liegt unter:

- `web/gg/index.html`
- `web/gg/style.css`
- `web/gg/app.js`
- `web/cgi-bin/gg_status.sh`
- `web/cgi-bin/gg_vpn.sh`
- `web/cgi-bin/gg_privacy.sh`

Deploy per ADB:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy_gg_web.ps1
```

Mit Web-Token:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy_gg_web.ps1 -SetToken -Token "DEIN_TOKEN"
```

Danach:

```text
http://192.168.0.1/gg/
```
