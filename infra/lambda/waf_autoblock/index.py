"""
WAF auto-block.

Triggered by a CloudWatch Logs subscription on the WAF log group.
For every BLOCK action, the source IP is added to a WAF IPSet.
Once an IP is in the set, the WAF blocks it at the edge for everything.

Tunables (env):
  IPSET_NAME       — name of the WAF v2 IP set to update
  IPSET_ID         — id   of the WAF v2 IP set to update
  WAF_SCOPE        — REGIONAL or CLOUDFRONT (REGIONAL for ALB)
  ALLOWLIST        — comma-separated CIDRs that are NEVER added
"""

import base64
import gzip
import ipaddress
import json
import os

import boto3

wafv2 = boto3.client("wafv2")

IPSET_NAME = os.environ["IPSET_NAME"]
IPSET_ID = os.environ["IPSET_ID"]
WAF_SCOPE = os.environ.get("WAF_SCOPE", "REGIONAL")
ALLOWLIST = [c.strip() for c in os.environ.get("ALLOWLIST", "").split(",") if c.strip()]


def _is_allowlisted(ip):
    try:
        addr = ipaddress.ip_address(ip)
    except ValueError:
        return True
    for cidr in ALLOWLIST:
        try:
            if addr in ipaddress.ip_network(cidr, strict=False):
                return True
        except ValueError:
            pass
    return False


def _offenders(log_events):
    seen = set()
    for ev in log_events:
        try:
            rec = json.loads(ev["message"])
        except (KeyError, ValueError):
            continue
        if rec.get("action") != "BLOCK":
            continue
        ip = rec.get("httpRequest", {}).get("clientIp")
        if not ip or _is_allowlisted(ip):
            continue
        seen.add(ip)
    return seen


def _add_ips_to_set(new_ips):
    current = wafv2.get_ip_set(Name=IPSET_NAME, Scope=WAF_SCOPE, Id=IPSET_ID)
    existing = set(current["IPSet"]["Addresses"])
    additions = {f"{ip}/32" for ip in new_ips} - existing
    if not additions:
        return existing, additions
    updated = sorted(existing | additions)
    wafv2.update_ip_set(
        Name=IPSET_NAME,
        Scope=WAF_SCOPE,
        Id=IPSET_ID,
        Addresses=updated,
        LockToken=current["LockToken"],
    )
    return updated, additions


def handler(event, _ctx):
    payload = json.loads(gzip.decompress(base64.b64decode(event["awslogs"]["data"])))
    offenders = _offenders(payload.get("logEvents", []))
    if not offenders:
        return {"added": 0}
    _, additions = _add_ips_to_set(offenders)
    if additions:
        print(f"Added to blocklist: {sorted(additions)}")
    return {"added": len(additions), "ips": sorted(additions)}
