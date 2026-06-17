(function () {
  "use strict";

  // --- Token-Handling ---
  var queryToken = "";
  try {
    queryToken = new URLSearchParams(window.location.search).get("token") || "";
  } catch (err) {
    queryToken = "";
  }

  var storedToken = "";
  try { storedToken = localStorage.getItem("gg_token") || ""; } catch(e) {}
  var token = queryToken || storedToken;
  if (queryToken) {
    try { localStorage.setItem("gg_token", queryToken); } catch(e) {}
    try {
      var cleanUrl = new URL(window.location.href);
      cleanUrl.searchParams.delete("token");
      window.history.replaceState(null, document.title, cleanUrl.pathname + cleanUrl.search + cleanUrl.hash);
    } catch(e) {}
  }

  function showTokenOverlay(wrongToken) {
    var ov = document.getElementById("tokenOverlay");
    if (!ov) return;
    ov.style.display = "flex";
    if (wrongToken) {
      var hint = document.getElementById("tokenHint");
      if (hint) { hint.textContent = "Token ungueltig. Bitte erneut eingeben."; hint.style.color = "#ff6b6b"; }
    }
  }

  function hideTokenOverlay() {
    var ov = document.getElementById("tokenOverlay");
    if (ov) ov.style.display = "none";
    var hint = document.getElementById("tokenHint");
    if (hint) { hint.textContent = ""; }
  }

  function submitToken() {
    var inp = document.getElementById("tokenInput");
    if (!inp) return;
    var val = inp.value.trim();
    if (!val) return;
    token = val;
    try { localStorage.setItem("gg_token", val); } catch(e) {}
    hideTokenOverlay();
    refreshStatus();
    refreshLog();
  }

  document.addEventListener("DOMContentLoaded", function() {
    var btn = document.getElementById("tokenSubmit");
    if (btn) btn.addEventListener("click", submitToken);
    var inp = document.getElementById("tokenInput");
    if (inp) inp.addEventListener("keydown", function(e) {
      if (e.key === "Enter") submitToken();
    });
    if (!token) showTokenOverlay();
  });

  // --- Helpers ---
  function qs(id) { return document.getElementById(id); }

  function api(script, params) {
    params = params || {};
    if (token) params.token = token;
    var query = Object.keys(params)
      .map(function(key) { return encodeURIComponent(key) + "=" + encodeURIComponent(params[key]); })
      .join("&");
    return fetch("/cgi-bin/" + script + "?" + query, { cache: "no-store" })
      .then(function(res) {
        if (res.status === 403) {
          // Token falsch oder abgelaufen -> Overlay zeigen, keine Verarbeitung
          token = "";
          try { localStorage.removeItem("gg_token"); } catch(e) {}
          showTokenOverlay(true);
          return Promise.reject(new Error("FORBIDDEN"));
        }
        return res.text();
      });
  }

  function setText(id, value) {
    var el = qs(id);
    if (!el) return;
    var text = value || "--";
    el.textContent = text;
    el.title = text;
  }

  function setBadge(id, tone) {
    var el = qs(id);
    if (!el) return;
    el.className = tone ? "value-badge " + tone : "";
  }

  function portTone(value) {
    if (value === "closed" || value === "off" || value === "0") return "good";
    if (value === "open" || value === "on" || value === "1") return "bad";
    return "";
  }

  function onOff(value) {
    if (value === "1" || value === "on" || value === "open") return "on";
    if (value === "0" || value === "off" || value === "closed") return "off";
    return value || "--";
  }

  function secureState(data) {
    var ok = data.privacy === "on" &&
      data.wps_feature === "0" &&
      data.show_passphrase === "0" &&
      data.ap_isolate === "1" &&
      data.telnet_port === "closed" &&
      data.upnp_port === "closed" &&
      data.wps_port === "closed" &&
      data.atfwd_block === "on";
    return ok ? "hardened" : "review";
  }

  function parseStatus(text) {
    var data = {};
    text.split(/\r?\n/).forEach(function(line) {
      var idx = line.indexOf("=");
      if (idx > 0) data[line.slice(0, idx)] = line.slice(idx + 1);
    });
    return data;
  }

  function renderClients(value) {
    var box = qs("clientList");
    if (!box) return;
    box.innerHTML = "";
    if (!value || value === "--") { box.textContent = "--"; return; }
    value.split("|").forEach(function(row) {
      var parts = row.split(",");
      var div = document.createElement("div");
      div.className = "client-row";
      div.innerHTML = "<strong></strong><span></span><span></span>";
      div.children[0].textContent = parts[0] || "--";
      div.children[1].textContent = parts[1] || "--";
      div.children[2].textContent = parts[2] || "--";
      box.appendChild(div);
    });
  }

  function renderStatus(data) {
    var connected = data.vpn === "CONNECTED";
    var sec = secureState(data);

    setText("vpnState", connected ? "Verbunden" : "Getrennt");
    setText("vpnStateVpn", connected ? "Verbunden" : "Getrennt");
    setText("vpnBig", connected ? "ON" : "OFF");
    setText("vpnPill", connected ? "VPN ON" : "VPN OFF");
    qs("vpnMeter").className = "vpn-meter " + (connected ? "on" : "off");
    qs("vpnPill").className = "status-pill " + (connected ? "on" : "off");

    setText("profile", data.profile);
    setText("profileVpn", data.profile);
    setText("tunIp", data.tun_ip);
    setText("tunIpVpn", data.tun_ip);
    setText("wanIp", data.wan_ip);
    setText("wanIpVpn", data.wan_ip);
    setText("gateway", data.gateway);
    setText("clients", data.clients);
    setText("clientCountLine", (data.clients || "--") + " aktiv");
    setText("uptime", data.uptime);
    setText("netMode", data.net_mode);
    setText("battery", data.battery);
    setText("batterySystem", data.battery);
    setText("batteryDetail", data.battery);
    setText("storageUsr", data.storage_usr);
    setText("storageRoot", data.storage_root);
    setText("storageState", data.storage_usr);
    setText("openvpnProc", data.openvpn);
    setText("openvpnProcLine", data.openvpn);
    setText("adbState", data.adb);
    setText("adbStateDetail", data.adb);
    setText("privacyState", data.privacy);
    setText("privacyLine", data.privacy);
    setText("privacyStateDetail", data.privacy);
    setText("tokenState", data.token);
    setText("deviceLine", data.device || "M7350 Admin Panel");

    setText("securityState", sec === "hardened" ? "OK" : "Pruefen");
    setText("securityStateDetail", sec === "hardened" ? "OK" : "Pruefen");
    setText("wpsLine", onOff(data.wps_feature));
    setText("telnetLine", data.telnet_port);
    setText("isolationLine", onOff(data.ap_isolate));
    setText("telnetPort", data.telnet_port);
    setText("upnpPort", data.upnp_port);
    setText("wpsPort", data.wps_port);
    setText("atfwdBlock", data.atfwd_block);
    setText("displayPass", onOff(data.show_passphrase));
    setText("apIsolation", onOff(data.ap_isolate));

    setText("ssid", data.ssid);
    setText("ssidState", data.ssid);
    setText("hiddenSsid", onOff(data.hidden_ssid));
    setText("encryptType", data.encrypt_type === "11" ? "WPA2" : data.encrypt_type);
    setText("maxClients", data.max_assoc_sta);
    renderClients(data.client_list);

    // SD-Karte im Dashboard
    var sdMounted = data.sd_mounted === "yes";
    setText("sdMountedDash", sdMounted ? "eingehaengt" : "nicht eingehaengt");
    setBadge("sdMountedDash", sdMounted ? "good" : "warn");
    setText("sdFreeDash", data.sd_free || "--");
    setText("sdBackupDash", data.sd_backup_last || "--");

    setBadge("vpnState", connected ? "good" : "bad");
    setBadge("vpnStateVpn", connected ? "good" : "bad");
    setBadge("profile", data.profile && data.profile !== "unknown" ? "good" : "warn");
    setBadge("profileVpn", data.profile && data.profile !== "unknown" ? "good" : "warn");
    setBadge("securityState", sec === "hardened" ? "good" : "warn");
    setBadge("securityStateDetail", sec === "hardened" ? "good" : "warn");
    setBadge("privacyLine", data.privacy === "on" ? "good" : "warn");
    setBadge("privacyState", data.privacy === "on" ? "good" : "warn");
    setBadge("privacyStateDetail", data.privacy === "on" ? "good" : "warn");
    setBadge("wpsLine", data.wps_feature === "0" ? "good" : "bad");
    setBadge("isolationLine", data.ap_isolate === "1" ? "good" : "warn");
    setBadge("telnetLine", portTone(data.telnet_port));
    setBadge("telnetPort", portTone(data.telnet_port));
    setBadge("upnpPort", portTone(data.upnp_port));
    setBadge("wpsPort", portTone(data.wps_port));
    setBadge("atfwdBlock", data.atfwd_block === "on" ? "good" : "warn");
    setBadge("displayPass", data.show_passphrase === "0" ? "good" : "warn");
    setBadge("apIsolation", data.ap_isolate === "1" ? "good" : "warn");
    setBadge("openvpnProc", data.openvpn === "running" ? "good" : "bad");
    setBadge("openvpnProcLine", data.openvpn === "running" ? "good" : "bad");
    setBadge("adbState", data.adb === "on" ? "warn" : "good");
    setBadge("adbStateDetail", data.adb === "on" ? "warn" : "good");
    setBadge("tokenState", data.token === "on" || data.token === "set" ? "good" : "warn");
    setText("tokenStateSec", data.token === "on" ? "aktiv" : "nicht gesetzt");
    setText("tokenStateLine", data.token === "on" ? "gesetzt" : "fehlt");
    setBadge("tokenStateSec", data.token === "on" ? "good" : "bad");
    setBadge("tokenStateLine", data.token === "on" ? "good" : "bad");

    Array.prototype.forEach.call(document.querySelectorAll("[data-profile]"), function(button) {
      button.className = button.getAttribute("data-profile") === data.profile ? "active" : "";
    });
  }

  function refreshStatus() {
    return api("gg_status.sh", {})
      .then(parseStatus)
      .then(renderStatus)
      .catch(function(err) {
        if (err && err.message === "FORBIDDEN") return;
        setText("vpnState", "Status error");
        qs("vpnPill").className = "status-pill off";
        setText("vpnPill", "ERROR");
      });
  }

  function refreshLog() {
    return api("gg_vpn.sh", { action: "log" })
      .then(function(text) {
        qs("logOutput").textContent = text || "No log output.";
      })
      .catch(function(err) {
        if (err && err.message === "FORBIDDEN") return;
        qs("logOutput").textContent = "Could not load log.";
      });
  }

  // --- SD-Tab ---
  function refreshSdStatus() {
    var el = qs("sdOutput");
    if (el) el.textContent = "Lade...";
    return api("gg_sd.sh", { action: "status" })
      .then(parseStatus)
      .then(function(data) {
        var mounted = data.sd_mounted === "yes";
        setText("sdMountState", mounted ? "eingehaengt" : "nicht eingehaengt");
        setBadge("sdMountState", mounted ? "good" : "warn");
        setText("sdMountedDetail", mounted ? "ja" : "nein");
        setBadge("sdMountedDetail", mounted ? "good" : "warn");
        setText("sdFreeDetail", data.sd_free || "--");
        setText("sdTotalDetail", data.sd_total || "--");
        setText("sdFsDetail", data.sd_fs || "--");
        setText("sdBackupLastDetail", data.sd_backup_last || "--");
        setText("sdFilesDetail", data.sd_files || "--");

        var mountBtn = qs("sdMount");
        if (mountBtn) mountBtn.style.display = mounted ? "none" : "";
        var umountBtn = qs("sdUmount");
        if (umountBtn) umountBtn.style.display = mounted ? "" : "none";
        var backupBtn = qs("sdBackup");
        if (backupBtn) backupBtn.disabled = !mounted;

        if (el) el.textContent = mounted ? "SD-Karte eingehaengt.\nFrei: " + (data.sd_free || "--") + " / " + (data.sd_total || "--") + "\nLetztes Backup: " + (data.sd_backup_last || "--") : "SD-Karte nicht eingehaengt.";
      })
      .catch(function(err) {
        if (err && err.message === "FORBIDDEN") return;
        if (el) el.textContent = "Fehler beim Laden.";
      });
  }

  // --- Tab-Navigation ---
  Array.prototype.forEach.call(document.querySelectorAll("[data-tab]"), function(button) {
    button.addEventListener("click", function() {
      var tab = button.getAttribute("data-tab");
      Array.prototype.forEach.call(document.querySelectorAll("[data-tab]"), function(item) {
        item.className = item === button ? "active" : "";
      });
      Array.prototype.forEach.call(document.querySelectorAll(".tab-panel"), function(panel) {
        panel.className = panel.id === "tab-" + tab ? "tab-panel active" : "tab-panel";
      });
      if (tab === "logs") refreshLog();
      if (tab === "sd") refreshSdStatus();
    });
  });

  // --- VPN-Buttons ---
  Array.prototype.forEach.call(document.querySelectorAll("[data-action]"), function(button) {
    button.addEventListener("click", function() {
      button.disabled = true;
      api("gg_vpn.sh", { action: button.getAttribute("data-action") })
        .then(function(text) {
          qs("logOutput").textContent = text;
          setTimeout(refreshStatus, 1200);
        })
        .catch(function() {})
        .finally(function() { button.disabled = false; });
    });
  });

  // --- Privacy-Buttons ---
  Array.prototype.forEach.call(document.querySelectorAll("[data-privacy]"), function(button) {
    button.addEventListener("click", function() {
      button.disabled = true;
      api("gg_privacy.sh", { action: button.getAttribute("data-privacy") })
        .then(function(text) {
          qs("logOutput").textContent = text;
          setTimeout(refreshStatus, 800);
        })
        .catch(function() {})
        .finally(function() { button.disabled = false; });
    });
  });

  // --- Profil-Switch ---
  Array.prototype.forEach.call(document.querySelectorAll("[data-profile]"), function(button) {
    button.addEventListener("click", function() {
      button.disabled = true;
      api("gg_vpn.sh", { action: "switch", profile: button.getAttribute("data-profile") })
        .then(function(text) {
          qs("logOutput").textContent = text;
          setTimeout(function() { refreshStatus(); refreshLog(); }, 2500);
        })
        .catch(function() {})
        .finally(function() { button.disabled = false; });
    });
  });

  // --- IP-Check ---
  qs("checkIp").addEventListener("click", function() {
    var button = qs("checkIp");
    button.disabled = true;
    setText("publicIp", "checking...");
    setText("publicIpVpn", "checking...");
    api("gg_vpn.sh", { action: "ipcheck" })
      .then(function(text) {
        var ip = text.trim();
        setText("publicIp", ip);
        setText("publicIpVpn", ip);
      })
      .catch(function() {})
      .finally(function() { button.disabled = false; });
  });

  // --- Hardening ---
  qs("applyHardening").addEventListener("click", function() {
    var button = qs("applyHardening");
    button.disabled = true;
    api("gg_security.sh", { action: "harden" })
      .then(function(text) {
        qs("logOutput").textContent = text;
        setTimeout(refreshStatus, 800);
      })
      .catch(function() {})
      .finally(function() { button.disabled = false; });
  });

  // --- Token rotieren ---
  qs("rotateToken").addEventListener("click", function() {
    if (!window.confirm("Neuen zufaelligen Token generieren? Der aktuelle Token wird ungueling.")) return;
    var button = qs("rotateToken");
    button.disabled = true;
    api("gg_security.sh", { action: "gentoken" })
      .then(function(text) {
        var match = text.match(/new_token=([a-f0-9]+)/);
        if (match) {
          var newTok = match[1];
          token = newTok;
          try { localStorage.setItem("gg_token", newTok); } catch(e) {}
          var box = qs("newTokenBox");
          box.style.display = "block";
          box.innerHTML = "<strong style='color:var(--green)'>Neuer Token (kopieren!):</strong><br>" + newTok;
        } else {
          qs("logOutput").textContent = text;
        }
      })
      .catch(function() {})
      .finally(function() { button.disabled = false; });
  });

  // --- Backup (verschluesselt, System-Tab) ---
  qs("createBackup").addEventListener("click", function() {
    var button = qs("createBackup");
    button.disabled = true;
    setText("backupState", "...");
    api("gg_security.sh", { action: "backup" })
      .then(function(text) {
        var box = qs("backupOutput");
        box.style.display = "block";
        box.textContent = text;
        var match = text.match(/backup=(.+)/);
        if (match) {
          setText("lastBackup", match[1].split("/").pop());
          setText("backupState", "OK");
        } else {
          setText("backupState", "Fehler");
        }
      })
      .catch(function() {})
      .finally(function() { button.disabled = false; });
  });

  qs("listBackups").addEventListener("click", function() {
    var button = qs("listBackups");
    button.disabled = true;
    api("gg_security.sh", { action: "backup_list" })
      .then(function(text) {
        var box = qs("backupOutput");
        box.style.display = "block";
        box.textContent = text || "Keine Backups vorhanden.";
      })
      .catch(function() {})
      .finally(function() { button.disabled = false; });
  });

  // --- SD-Karte Tab-Buttons ---
  var sdMount = qs("sdMount");
  if (sdMount) sdMount.addEventListener("click", function() {
    sdMount.disabled = true;
    api("gg_sd.sh", { action: "mount" })
      .then(function(text) {
        var el = qs("sdOutput");
        if (el) el.textContent = text;
        setTimeout(refreshSdStatus, 500);
      })
      .catch(function() {})
      .finally(function() { sdMount.disabled = false; });
  });

  var sdUmount = qs("sdUmount");
  if (sdUmount) sdUmount.addEventListener("click", function() {
    if (!window.confirm("SD-Karte aushängen?")) return;
    sdUmount.disabled = true;
    api("gg_sd.sh", { action: "umount" })
      .then(function(text) {
        var el = qs("sdOutput");
        if (el) el.textContent = text;
        setTimeout(refreshSdStatus, 500);
      })
      .catch(function() {})
      .finally(function() { sdUmount.disabled = false; });
  });

  var sdBackup = qs("sdBackup");
  if (sdBackup) sdBackup.addEventListener("click", function() {
    sdBackup.disabled = true;
    var el = qs("sdOutput");
    if (el) el.textContent = "Backup laeuft...";
    api("gg_sd.sh", { action: "backup" })
      .then(function(text) {
        if (el) el.textContent = text;
        setTimeout(refreshSdStatus, 800);
      })
      .catch(function() {})
      .finally(function() { sdBackup.disabled = false; });
  });

  var sdListFiles = qs("sdListFiles");
  if (sdListFiles) sdListFiles.addEventListener("click", function() {
    sdListFiles.disabled = true;
    api("gg_sd.sh", { action: "list" })
      .then(function(text) {
        var el = qs("sdOutput");
        if (el) el.textContent = text || "Keine Dateien gefunden.";
      })
      .catch(function() {})
      .finally(function() { sdListFiles.disabled = false; });
  });

  // --- Log-Buttons ---
  qs("refreshLog").addEventListener("click", refreshLog);
  qs("clearLog").addEventListener("click", function() {
    api("gg_vpn.sh", { action: "clearlog" })
      .then(function(text) { qs("logOutput").textContent = text; })
      .catch(function() {});
  });
  qs("refreshAll").addEventListener("click", function() {
    refreshStatus();
    refreshLog();
  });

  // --- Init ---
  refreshStatus();
  refreshLog();
  window.setInterval(refreshStatus, 5000);
}());
