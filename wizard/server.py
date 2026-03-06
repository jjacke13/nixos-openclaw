#!/usr/bin/env python3
"""
OpenClaw Setup Wizard - Web-based configuration for non-technical users.

Serves a form to configure models, agents, and channels (Telegram).
Writes to user-config.json and restarts the openclaw gateway service.

Usage:
    python server.py [--port 8080] [--config /var/lib/openclaw/user-config.json]

Environment variables (override CLI args):
    WIZARD_PORT         - Port to listen on (default: 8080)
    WIZARD_CONFIG_PATH  - Path to user-config.json
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request
import urllib.error
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

CONFIG_PATH = os.environ.get(
    "WIZARD_CONFIG_PATH",
    "/var/lib/openclaw/user-config.json",
)
HOST = os.environ.get("WIZARD_HOST", "0.0.0.0")
PORT = int(os.environ.get("WIZARD_PORT", "8080"))
WIZARD_DIR = Path(__file__).parent
INDEX_PATH = WIZARD_DIR / "index.html"
PPQ_CREDIT_PATH = os.environ.get(
    "WIZARD_PPQ_CREDIT_PATH",
    "/var/lib/openclaw/ppq-credit.json",
)
PPQ_API_URL = "https://api.ppq.ai"

# Keys whose values should be redacted in GET /api/config
REDACT_KEYS = {"apiKey", "api_key", "botToken", "token"}


def redact_secrets(obj):
    """Recursively redact sensitive fields in config for GET responses."""
    if isinstance(obj, dict):
        result = {}
        for key, value in obj.items():
            if key in REDACT_KEYS and isinstance(value, str) and len(value) > 6:
                result[key] = value[:3] + "****" + value[-3:]
            elif key in REDACT_KEYS and isinstance(value, str) and value:
                result[key] = "****"
            elif isinstance(value, (dict, list)):
                result[key] = redact_secrets(value)
            else:
                result[key] = value
        return result
    elif isinstance(obj, list):
        return [redact_secrets(item) for item in obj]
    return obj


def read_config():
    """Read current user-config.json, return dict."""
    try:
        with open(CONFIG_PATH, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def write_config(data):
    """Write config to user-config.json atomically."""
    config_dir = os.path.dirname(CONFIG_PATH)
    if config_dir:
        os.makedirs(config_dir, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=config_dir or ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
        os.rename(tmp_path, CONFIG_PATH)
    except BaseException:
        try:
            os.unlink(tmp_path)
        except FileNotFoundError:
            pass
        raise


# ---------------------------------------------------------------------------
# Validation: whitelist keys, check types, validate values
# ---------------------------------------------------------------------------
ALLOWED_PROVIDERS = {"ppq", "openrouter", "openai", "anthropic", "custom"}
ALLOWED_API_FORMATS = {"openai-completions", "anthropic"}
ALLOWED_DM_POLICIES = {"pairing", "open", "allowlist", "disabled"}
ALLOWED_GROUP_POLICIES = {"allowlist", "open", "disabled"}
ALLOWED_REPLY_MODES = {"off", "first", "all"}
ALLOWED_STREAM_MODES = {"off", "partial", "block"}
ALLOWED_HEARTBEAT = {"1h", "2h", "4h", "8h", "off"}
ALLOWED_MAX_CONCURRENT = {2, 4, 8}
ALLOWED_HISTORY_LIMITS = {25, 50, 100}

# Telegram bot token: digits:alphanumeric
BOT_TOKEN_RE = re.compile(r"^\d{8,10}:[A-Za-z0-9_-]{30,50}$")
# Telegram user ID: 5-13 digits
USER_ID_RE = re.compile(r"^\d{5,13}$")
# URL pattern (basic)
URL_RE = re.compile(r"^https?://\S+$")


def validate_config(data):
    """Validate incoming config data. Returns (ok, errors) tuple."""
    errors = []

    if not isinstance(data, dict):
        return False, ["Config must be a JSON object."]

    # Only allow known top-level keys
    allowed_top = {"meta", "models", "agents", "channels", "plugins", "auth",
                   "bindings", "messages", "commands", "skills"}
    unknown = set(data.keys()) - allowed_top
    if unknown:
        errors.append(f"Unknown top-level keys: {', '.join(unknown)}")

    # --- Models ---
    models = data.get("models")
    if models is not None:
        if not isinstance(models, dict):
            errors.append("'models' must be an object.")
        else:
            providers = models.get("providers", {})
            if not isinstance(providers, dict):
                errors.append("'models.providers' must be an object.")
            else:
                for name, prov in providers.items():
                    if not isinstance(name, str) or not name:
                        errors.append("Provider name must be a non-empty string.")
                        continue
                    if not isinstance(prov, dict):
                        errors.append(f"Provider '{name}' must be an object.")
                        continue
                    # Validate baseUrl
                    base_url = prov.get("baseUrl", "")
                    if base_url and not URL_RE.match(base_url):
                        errors.append(f"Provider '{name}': invalid baseUrl.")
                    # Validate apiKey is a string
                    api_key = prov.get("apiKey", "")
                    if not isinstance(api_key, str):
                        errors.append(f"Provider '{name}': apiKey must be a string.")
                    # Validate api format
                    api_fmt = prov.get("api", "")
                    if api_fmt and api_fmt not in ALLOWED_API_FORMATS:
                        errors.append(f"Provider '{name}': invalid api format '{api_fmt}'.")
                    # Validate models list
                    model_list = prov.get("models", [])
                    if not isinstance(model_list, list):
                        errors.append(f"Provider '{name}': models must be a list.")
                    else:
                        for m in model_list:
                            if not isinstance(m, dict):
                                errors.append(f"Provider '{name}': each model must be an object.")
                            elif not isinstance(m.get("id", ""), str) or not m.get("id"):
                                errors.append(f"Provider '{name}': model must have a string 'id'.")

    # --- Agents ---
    agents = data.get("agents")
    if agents is not None:
        if not isinstance(agents, dict):
            errors.append("'agents' must be an object.")
        else:
            defaults = agents.get("defaults", {})
            if not isinstance(defaults, dict):
                errors.append("'agents.defaults' must be an object.")
            else:
                hb = defaults.get("heartbeat", {})
                if isinstance(hb, dict):
                    every = hb.get("every", "")
                    if every and every not in ALLOWED_HEARTBEAT:
                        errors.append(f"Invalid heartbeat interval: '{every}'.")
                mc = defaults.get("maxConcurrent")
                if mc is not None and mc not in ALLOWED_MAX_CONCURRENT:
                    errors.append(f"Invalid maxConcurrent value: {mc}.")

    # --- Channels (Telegram) ---
    channels = data.get("channels")
    if channels is not None:
        if not isinstance(channels, dict):
            errors.append("'channels' must be an object.")
        else:
            tg = channels.get("telegram", {})
            if not isinstance(tg, dict):
                errors.append("'channels.telegram' must be an object.")
            else:
                if tg.get("enabled") is True:
                    # Bot token is required when enabled
                    token = tg.get("botToken", "")
                    if not token:
                        errors.append("Telegram bot token is required when enabled.")
                    elif not BOT_TOKEN_RE.match(token):
                        errors.append("Invalid Telegram bot token format.")
                    # User ID in allowFrom
                    allow_from = tg.get("allowFrom", [])
                    if not isinstance(allow_from, list):
                        errors.append("'allowFrom' must be a list.")
                    else:
                        for uid in allow_from:
                            if uid and not USER_ID_RE.match(str(uid)):
                                errors.append(f"Invalid Telegram user ID: '{uid}'. Must be 5-13 digits.")
                # DM policy
                dm = tg.get("dmPolicy", "")
                if dm and dm not in ALLOWED_DM_POLICIES:
                    errors.append(f"Invalid dmPolicy: '{dm}'.")
                # Group policy
                gp = tg.get("groupPolicy", "")
                if gp and gp not in ALLOWED_GROUP_POLICIES:
                    errors.append(f"Invalid groupPolicy: '{gp}'.")
                # History limit
                hl = tg.get("historyLimit")
                if hl is not None and hl not in ALLOWED_HISTORY_LIMITS:
                    errors.append(f"Invalid historyLimit: {hl}.")
                # Reply-to mode
                rtm = tg.get("replyToMode", "")
                if rtm and rtm not in ALLOWED_REPLY_MODES:
                    errors.append(f"Invalid replyToMode: '{rtm}'.")
                # Stream mode
                sm = tg.get("streamMode", "")
                if sm and sm not in ALLOWED_STREAM_MODES:
                    errors.append(f"Invalid streamMode: '{sm}'.")
                # Link preview
                lp = tg.get("linkPreview")
                if lp is not None and not isinstance(lp, bool):
                    errors.append("'linkPreview' must be a boolean.")
                # Groups
                groups = tg.get("groups")
                if groups is not None:
                    if not isinstance(groups, dict):
                        errors.append("'channels.telegram.groups' must be an object.")
                    else:
                        for gkey, gval in groups.items():
                            if not isinstance(gval, dict):
                                errors.append(f"Group '{gkey}' must be an object.")

    return len(errors) == 0, errors


def restart_openclaw():
    """Restart the openclaw gateway service."""
    try:
        subprocess.run(
            ["/run/wrappers/bin/sudo", "/run/current-system/sw/bin/systemctl", "restart", "openclaw.service"],
            check=True,
            capture_output=True,
            timeout=30,
        )
        return True, "Service restarted successfully."
    except subprocess.CalledProcessError as e:
        return False, f"Failed to restart: {e.stderr.decode()}"
    except FileNotFoundError:
        return False, "sudo or systemctl not found. Are you running on NixOS?"


class WizardHandler(BaseHTTPRequestHandler):
    """HTTP request handler for the setup wizard."""

    def do_GET(self):
        if self.path == "/":
            self._serve_index()
        elif self.path == "/api/config":
            self._handle_get_config()
        elif self.path == "/api/ppq/balance":
            self._handle_ppq_balance()
        elif self.path == "/api/ppq/credit":
            self._handle_ppq_credit()
        elif self.path.startswith("/api/models"):
            self._handle_models()
        elif self.path == "/style.css":
            self._serve_file("style.css", "text/css; charset=utf-8")
        elif self.path.startswith("/schemas/") and self.path.endswith(".js"):
            self._serve_static("schemas")
        elif self.path.startswith("/i18n/") and self.path.endswith(".js"):
            self._serve_static("i18n")
        elif self.path == "/ppq.png":
            self._serve_file("ppq.png", "image/png")
        else:
            self._send_json(404, {"error": "Not found"})

    def do_POST(self):
        if self.path == "/api/config":
            self._handle_save()
        elif self.path == "/api/ppq/register":
            self._handle_ppq_register()
        else:
            self._send_json(404, {"error": "Not found"})

    def _serve_index(self):
        try:
            content = INDEX_PATH.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except FileNotFoundError:
            self._send_json(500, {"error": "index.html not found"})

    def _serve_file(self, filename, content_type):
        filepath = WIZARD_DIR / filename
        if not filepath.is_file():
            self._send_json(404, {"error": "Not found"})
            return
        content = filepath.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def _serve_static(self, subdir):
        # Only allow simple filenames — no path traversal
        filename = self.path.split("/")[-1]
        if not filename.endswith(".js") or "/" in filename or "\\" in filename:
            self._send_json(404, {"error": "Not found"})
            return
        filepath = WIZARD_DIR / subdir / filename
        if not filepath.is_file():
            self._send_json(404, {"error": "Not found"})
            return
        try:
            content = filepath.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/javascript; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except FileNotFoundError:
            self._send_json(404, {"error": "Not found"})

    MAX_BODY = 65536  # 64 KB

    def _handle_get_config(self):
        """Return config with secrets redacted."""
        config = read_config()
        redacted = redact_secrets(config)
        self._send_json(200, redacted)

    def _handle_save(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            if length > self.MAX_BODY:
                self._send_json(413, {"error": "Request too large"})
                return
            body = self.rfile.read(length)
            data = json.loads(body)
        except (json.JSONDecodeError, ValueError):
            self._send_json(400, {"error": "Invalid JSON"})
            return

        # For PPQ provider: inject the API key from ppq-credit.json
        # when the key is missing or redacted (contains ****)
        providers = data.get("models", {}).get("providers", {})
        for prov_name, prov in providers.items():
            api_key = prov.get("apiKey", "")
            if not api_key or "****" in api_key:
                try:
                    with open(PPQ_CREDIT_PATH, "r") as f:
                        credit = json.load(f)
                    ppq_key = credit.get("api_key", "")
                    if ppq_key:
                        prov["apiKey"] = ppq_key
                except (FileNotFoundError, json.JSONDecodeError):
                    pass

        # Merge with existing config to preserve fields not in the form
        existing = read_config()
        merged = deep_merge(existing, data)

        # Validate the merged result
        valid, errors = validate_config(merged)
        if not valid:
            self._send_json(400, {"success": False, "errors": errors})
            return

        write_config(merged)

        ok, msg = restart_openclaw()
        status = 200 if ok else 500
        self._send_json(status, {"success": ok, "message": msg})

    def _handle_models(self):
        """Proxy model listing from provider API."""
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        base_url = params.get("baseUrl", [""])[0]
        api_key = params.get("apiKey", [""])[0]

        if not base_url or not URL_RE.match(base_url):
            self._send_json(400, {"error": "Invalid base URL"})
            return

        url = base_url.rstrip("/")
        if url.endswith("/v1"):
            url += "/models"
        else:
            url += "/v1/models"

        headers = {"Accept": "application/json"}
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"

        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode())
            models = []
            for m in data.get("data", []):
                if isinstance(m, dict) and m.get("id"):
                    models.append({"id": m["id"]})
            models.sort(key=lambda x: x["id"])
            self._send_json(200, {"models": models})
        except Exception as e:
            self._send_json(502, {"error": str(e)})

    def _handle_ppq_register(self):
        """Create a new PPQ account and return the API key."""
        # Check if we already have a credit stored
        try:
            with open(PPQ_CREDIT_PATH, "r") as f:
                existing = json.load(f)
            if existing.get("api_key"):
                self._send_json(200, {
                    "api_key": existing["api_key"],
                    "credit_id": existing.get("credit_id", ""),
                    "existing": True,
                })
                return
        except (FileNotFoundError, json.JSONDecodeError):
            pass

        # Call PPQ account creation API (no body, no Content-Type)
        req = urllib.request.Request(
            f"{PPQ_API_URL}/accounts/create",
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode())
        except Exception as e:
            self._send_json(502, {"error": f"PPQ registration failed: {e}"})
            return

        api_key = data.get("api_key", "")
        credit_id = data.get("credit_id", "")
        if not api_key:
            self._send_json(502, {"error": "PPQ returned no API key."})
            return

        # Save credit info to file
        credit_dir = os.path.dirname(PPQ_CREDIT_PATH)
        if credit_dir:
            os.makedirs(credit_dir, exist_ok=True)
        fd, tmp_path = tempfile.mkstemp(dir=credit_dir or ".", suffix=".tmp")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump({"credit_id": credit_id, "api_key": api_key}, f, indent=2)
            os.rename(tmp_path, PPQ_CREDIT_PATH)
        except BaseException:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass
            raise

        self._send_json(200, {
            "api_key": api_key,
            "credit_id": credit_id,
            "existing": False,
        })

    def _handle_ppq_balance(self):
        """Return the PPQ credit balance using credit_id from ppq-credit.json."""
        try:
            with open(PPQ_CREDIT_PATH, "r") as f:
                credit_data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            self._send_json(404, {"error": "No PPQ credit file found."})
            return

        credit_id = credit_data.get("credit_id", "")
        if not credit_id:
            self._send_json(404, {"error": "No credit_id in PPQ credit file."})
            return

        payload = json.dumps({"credit_id": credit_id}).encode()
        req = urllib.request.Request(
            f"{PPQ_API_URL}/credits/balance",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode())
            self._send_json(200, data)
        except Exception as e:
            self._send_json(502, {"error": f"Failed to fetch balance: {e}"})

    def _handle_ppq_credit(self):
        """Return the PPQ credit_id."""
        try:
            with open(PPQ_CREDIT_PATH, "r") as f:
                credit_data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            credit_data = {}
        self._send_json(200, {
            "credit_id": credit_data.get("credit_id", ""),
        })

    def _send_json(self, status, data):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print(f"[wizard] {format % args}")


def deep_merge(base, override):
    """Recursively merge override into base. Override wins on conflicts."""
    result = base.copy()
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def main():
    global CONFIG_PATH

    # CLI argument parsing (minimal, no argparse needed)
    port = PORT

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--port" and i + 1 < len(args):
            port = int(args[i + 1])
            i += 2
        elif args[i] == "--config" and i + 1 < len(args):
            CONFIG_PATH = args[i + 1]
            i += 2
        else:
            i += 1

    server = HTTPServer((HOST, port), WizardHandler)
    print(f"[wizard] OpenClaw Setup Wizard running on http://{HOST}:{port}")
    print(f"[wizard] Config path: {CONFIG_PATH}")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[wizard] Shutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
