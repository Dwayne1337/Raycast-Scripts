#!/bin/bash

# @raycast.title Router IP Change
# @raycast.mode fullOutput
# @raycast.packageName Netzwerk
# @raycast.schemaVersion 1
# @raycast.description Reconnect WAN (UPnP/IGD or TR-064) to fetch a new external IP.

set -euo pipefail

die() {
  echo "Error: $*" >&2
  exit 1
}

read_keychain_password() {
  local service="$1"
  local account="$2"

  /usr/bin/security find-generic-password -s "$service" -a "$account" -w 2>/dev/null || true
}

soap_envelope() {
  local service_type="$1"
  local action="$2"

  cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:${action} xmlns:u="${service_type}"></u:${action}>
  </s:Body>
</s:Envelope>
EOF
}

curl_soap() {
  local base_url="$1"
  local control_path="$2"
  local service_type="$3"
  local action="$4"

  local url="${base_url}${control_path}"
  local envelope
  envelope="$(soap_envelope "$service_type" "$action")"

  local -a curl_args=(
    --silent
    --show-error
    --fail
    --header "Content-Type: text/xml; charset=\"utf-8\""
    --header "SoapAction: ${service_type}#${action}"
    --data "$envelope"
    --connect-timeout 3
    --max-time 10
  )

  if [[ -n "${FRITZ_USER:-}" && -n "${FRITZ_PASS:-}" ]]; then
    curl_args+=(--anyauth --user "$FRITZ_USER:$FRITZ_PASS")
  fi

  if [[ "$base_url" == https://* ]]; then
    curl_args+=(--insecure)
  fi

  /usr/bin/curl "${curl_args[@]}" "$url"
}

extract_external_ip() {
  local xml="$1"

  if command -v /usr/bin/xmllint >/dev/null 2>&1; then
    echo "$xml" | /usr/bin/xmllint --xpath 'string(//*[local-name()="NewExternalIPAddress"])' - 2>/dev/null || true
    return 0
  fi

  echo "$xml" | /usr/bin/tr -d '\n' | /usr/bin/sed -n 's/.*<NewExternalIPAddress>\([^<]*\)<\/NewExternalIPAddress>.*/\1/p'
}

: "${FRITZ_HOST:=fritz.box}"
: "${FRITZ_KEYCHAIN_SERVICE:=raycast-fritzbox}"

: "${FRITZ_USER:=${FRITZ_USERNAME:-}}"

: "${FRITZ_PASS:=${FRITZ_PASSWORD:-}}"
if [[ -n "${FRITZ_USER:-}" && -z "${FRITZ_PASS:-}" ]]; then
  FRITZ_PASS="$(read_keychain_password "$FRITZ_KEYCHAIN_SERVICE" "$FRITZ_USER")"
fi

if [[ -n "${FRITZ_PASS:-}" && -z "${FRITZ_USER:-}" ]]; then
  die "FRITZ_PASS gesetzt, aber FRITZ_USER fehlt."
fi

if [[ -n "${FRITZ_USER:-}" && -z "${FRITZ_PASS:-}" ]]; then
  die "Kein Passwort gefunden. Setze FRITZ_PASS oder lege es in den macOS Keychain ab (Service: ${FRITZ_KEYCHAIN_SERVICE}, Account: ${FRITZ_USER})."
fi

declare -a base_urls=()
if [[ -n "${FRITZ_URL:-}" ]]; then
  base_urls+=("$FRITZ_URL")
else
  base_urls+=("https://${FRITZ_HOST}:49443" "http://${FRITZ_HOST}:49000")
fi

declare -a targets=(
  "urn:schemas-upnp-org:service:WANIPConnection:1|/igdupnp/control/WANIPConn1"
  "urn:schemas-upnp-org:service:WANIPConnection:1|/upnp/control/wanipconnection1"
  "urn:schemas-upnp-org:service:WANPPPConnection:1|/igdupnp/control/WANPPPConn1"
  "urn:schemas-upnp-org:service:WANPPPConnection:1|/upnp/control/wanpppconnection1"
)

echo "FRITZ!Box WAN-Reconnect…"
echo "Host: ${FRITZ_HOST}"
if [[ -z "${FRITZ_USER:-}" ]]; then
  echo "Modus: ohne Login (UPnP/IGD, falls erlaubt)"
else
  echo "Modus: mit Login (${FRITZ_USER})"
fi
echo

success_base=""
success_service=""
success_control=""
old_ip=""

for base_url in "${base_urls[@]}"; do
  for target in "${targets[@]}"; do
    service_type="${target%%|*}"
    control_path="${target#*|}"

    echo "Teste: ${base_url}${control_path} (${service_type})"

    ip_xml="$(curl_soap "$base_url" "$control_path" "$service_type" "GetExternalIPAddress" 2>/dev/null || true)"
    ip_val="$(extract_external_ip "${ip_xml:-}")"
    if [[ -n "${ip_val:-}" ]]; then
      old_ip="$ip_val"
      echo "Aktuelle externe IP: ${old_ip}"
    fi

    if curl_soap "$base_url" "$control_path" "$service_type" "ForceTermination" >/dev/null 2>&1; then
      echo "ForceTermination: OK"
      curl_soap "$base_url" "$control_path" "$service_type" "RequestConnection" >/dev/null 2>&1 || true
      echo "RequestConnection: gesendet"

      success_base="$base_url"
      success_service="$service_type"
      success_control="$control_path"
      echo
      break 2
    fi

    echo "Nicht kompatibel oder kein Zugriff."
    echo
  done
done

if [[ -z "$success_base" ]]; then
  if [[ -z "${FRITZ_USER:-}" ]]; then
    die "Konnte keinen unauth UPnP/IGD Endpoint nutzen. Aktiviere UPnP/IGD in der FRITZ!Box oder setze FRITZ_USER (und Passwort/Keychain) für TR-064."
  fi
  die "Konnte keinen TR-064/IGD Endpoint erreichen. Prüfe FRITZ_USER/Passwort und ob 'Zugriff für Anwendungen' (TR-064) in der FRITZ!Box aktiviert ist."
fi

if [[ -n "${old_ip:-}" ]]; then
  echo "Warte auf neue externe IP…"
  for _ in {1..15}; do
    sleep 2
    ip_xml="$(curl_soap "$success_base" "$success_control" "$success_service" "GetExternalIPAddress" 2>/dev/null || true)"
    ip_val="$(extract_external_ip "${ip_xml:-}")"
    if [[ -n "${ip_val:-}" && "$ip_val" != "$old_ip" ]]; then
      echo "Neue externe IP: ${ip_val}"
      exit 0
    fi
  done
  echo "Reconnect ausgelöst. Externe IP hat sich (noch) nicht geändert oder konnte nicht gelesen werden."
else
  echo "Reconnect ausgelöst."
fi
