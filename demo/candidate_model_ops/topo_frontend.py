#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import json
import re
import sys
from typing import Dict, Tuple
from urllib import request, error

NODE_TP_PATTERN = re.compile(r'^(?P<node>[^\[\]]+)\[(?P<tp>[^\[\]]+)\]$')


def parse_node_tp(value: str) -> Tuple[str, str]:
    """
    Parse "node[tp]" into (node, tp).
    """
    m = NODE_TP_PATTERN.match(value)
    if not m:
        raise argparse.ArgumentTypeError(
            f'invalid format "{value}". Expected "node[tp]" (e.g., edge01[ge-0/0/0.0])'
        )
    return m.group("node").strip(), m.group("tp").strip()


def build_payload(cmd: str, src: Tuple[str, str], dst: Tuple[str, str]) -> Dict:
    """
    Build the JSON payload according to the required schema.
    """
    (src_node, src_tp) = src
    (dst_node, dst_tp) = dst
    return {
        "command": cmd,
        "args": {
            "link": {
                "source": {"node": src_node, "tp": src_tp},
                "destination": {"node": dst_node, "tp": dst_tp},
            }
        },
    }


def post_json(url: str, payload: Dict, timeout: int = 30) -> Dict:
    """
    POST JSON and return parsed JSON response.
    """
    data = json.dumps(payload).encode("utf-8")
    req = request.Request(
        url=url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            resp_body = resp.read().decode("utf-8")
            return json.loads(resp_body)
    except error.HTTPError as he:
        body = he.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTPError {he.code} {he.reason}\n{body[:1000]}")
    except error.URLError as ue:
        raise RuntimeError(f"URLError: {ue.reason}")
    except json.JSONDecodeError as je:
        raise RuntimeError(f"Invalid JSON response: {je}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Frontend CLI for topology operations REST API."
    )
    parser.add_argument(
        "-d", "--dry-run",
        action="store_true",
        help="Set dry_run=true in request payload (default: false).",
    )
    parser.add_argument(
        "--cmd",
        default="connect_link",
        choices=["connect_link"],
        help='Command to execute (default: "connect_link").',
    )
    parser.add_argument(
        "--src",
        required=True,
        type=parse_node_tp,
        help='Source endpoint in "node[tp]" format.',
    )
    parser.add_argument(
        "--dst",
        required=True,
        type=parse_node_tp,
        help='Destination endpoint in "node[tp]" format.',
    )
    parser.add_argument(
        "--nw",
        required=True,
        help="Network name.",
    )
    parser.add_argument(
        "--ss",
        default="original_asis",
        help="Snapshot name (default: original_asis).",
    )
    parser.add_argument(
        "--api",
        default="localhost:15000",
        help='API host:port (default: "localhost:15000").',
    )

    args = parser.parse_args()

    # REST API URL 組み立て
    api_url = f"http://{args.api}/conduct/{args.nw}/{args.ss}/topology_ops"

    payload = build_payload(args.cmd, args.dry_run, args.src, args.dst)

    try:
        response = post_json(api_url, payload)
    except Exception as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        return 1

    print(json.dumps(response, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
