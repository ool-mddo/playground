import json
import csv
import argparse
import sys
import math


def json_to_csv(param_json_file, diff_json_file):
    with open(param_json_file, "r", encoding="utf-8") as f:
        param_data = json.load(f)
    with open(diff_json_file, "r", encoding="utf-8") as f:
        diff_data = json.load(f)

    # interfaces to check
    target_interfaces = param_data["expected_traffic"]["original_targets"]

    # Process each node and interface
    rows = []
    for node, interfaces in diff_data["diff"].items():
        for interface, metrics in interfaces.items():
            row = {
                # "network": diff_data["network"],
                "src_ss": diff_data["source_snapshot"],
                "dst_ss": diff_data["destination_snapshot"],
                "node": node,
            }
            row["interface"] = interface
            for metric, values in metrics.items():
                row[f"{metric}-cnt"] = (
                    math.ceil(values["counter"] * 100) / 100
                )  # decimal places: 2
                if values["ratio"] is None:
                    row[f"{metric}-%"] = None
                else:
                    row[f"{metric}-%"] = (
                        math.ceil(values["ratio"] * 1000) / 10
                    )  # decimal places: 1 [%]

            # filter: append rows only if the row matched a target interface
            if next(
                (
                    t
                    for t in target_interfaces
                    if t["node"] == row["node"] and t["interface"] == row["interface"]
                ),
                None,
            ):
                rows.append(row)

    # CSV writer (outputs to stdout)
    writer = csv.writer(sys.stdout)
    # Write CSV
    column_keys = list(rows[0].keys())
    writer.writerow(column_keys)  # header
    for row in rows:
        values = [row[k] for k in column_keys]
        writer.writerow(values)


def main():
    parser = argparse.ArgumentParser(description="Convert JSON to CSV.")
    parser.add_argument(
        "-p", "--param", required=True, help="Path to usecase PARAM json"
    )
    parser.add_argument("-d", "--diff", required=True, help="Path to state DIFF json.")
    args = parser.parse_args()

    json_to_csv(args.param, args.diff)


if __name__ == "__main__":
    main()
