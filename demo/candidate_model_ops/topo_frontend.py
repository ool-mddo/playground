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


def build_link_payload(src: Tuple[str, str], dst: Tuple[str, str]) -> Dict:
    """
    Build the JSON payload according to the required schema. (for connect-link operation)
    """
    (src_node, src_tp) = src
    (dst_node, dst_tp) = dst
    return {
        "command": "connect_link",
        "args": {
            "link": {
                "source": {"node": src_node, "tp": src_tp},
                "destination": {"node": dst_node, "tp": dst_tp},
            }
        },
    }


def build_shut_payload(target: Tuple[str, str]) -> Dict:
    """
    Build the JSON payload according to the required schema. (for shutdown-interface operation)
    """
    (node, tp) = target
    return {
        "command": "shutdown_intf",
        "args": {
            "interface": {"node": node, "tp": tp},
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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Topology Ops CLI (subcommands: link, shut)"
    )

    # ---- 共通オプション ----
    parser.add_argument(
        "-d", "--dry-run",
        action="store_true",
        help="dry-run 指定（送信ペイロードには含めない・レスポンス処理で使用予定）",
    )
    parser.add_argument("--nw", required=True, help="Network name")
    parser.add_argument("--ss", default="original_asis",
                        help='Snapshot name (default: "original_asis")')
    parser.add_argument("--api", default="localhost:15000",
                        help='API host:port (default: "localhost:15000")')

    # ---- サブコマンド ----
    subparsers = parser.add_subparsers(
        dest="cmd",
        metavar="{link,shut}",
        required=True,  # Python 3.7+ で有効
        help="操作を選択（サブコマンド）",
    )

    # cmd=link
    p_link = subparsers.add_parser(
        "link",
        help="TP 間を接続（connect_link の短縮）",
        description="Connect two termination points: link --src node1[tp1] --dst node2[tp2]",
    )
    p_link.add_argument("--src", required=True, type=parse_node_tp,
                        help='Source endpoint "node[tp]"')
    p_link.add_argument("--dst", required=True, type=parse_node_tp,
                        help='Destination endpoint "node[tp]"')

    # cmd=shut
    p_shut = subparsers.add_parser(
        "shut",
        help="TP を shutdown 対象として指定",
        description="Shutdown target termination point: shut --target node[tp]",
    )
    p_shut.add_argument("--target", required=True, type=parse_node_tp,
                        help='Target endpoint "node[tp]"')

    return parser


def build_payload(args) -> Dict:
    """
    payload of corresponding command
    """
    if args.cmd == "link":
        return build_link_payload(args.src, args.dst)
    if args.cmd == "shut":
        return build_shut_payload(args.target)
    return {}


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    # 正規化した結果（このまま送信処理に渡せます）
    api_url = f"http://{args.api}/conduct/{args.nw}/{args.ss}/topology_ops"

    payload = build_payload(args)

    try:
        response = post_json(api_url, payload)
    except Exception as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        return 1

    print(json.dumps(response, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
