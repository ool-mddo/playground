import json
import csv
import argparse
import sys
import math

def json_to_csv(json_file):
    with open(json_file, 'r') as f:
        data = json.load(f)

    # Process each node and interface
    rows = []
    for node, interfaces in data['diff'].items():
        row = {
            # "network": data["network"],
            "src_ss": data["source_snapshot"],
            "dst_ss": data["destination_snapshot"],
            "node": node
        }
        for interface, metrics in interfaces.items():
            row["interface"] = interface
            for metric, values in metrics.items():
                row[f"{metric}-cnt"] = math.ceil(values["counter"] * 100) / 100  # decimal places: 2
                row[f"{metric}-%"] = math.ceil(values["ratio"] * 1000) / 10  # decimal places: 1 [%]
    rows.append(row)

    # CSV writer (outputs to stdout)
    writer = csv.writer(sys.stdout)
    # Write CSV
    column_keys = [k for k in rows[0].keys()]
    writer.writerow(column_keys)  # header
    for row in rows:
        values = [row[k] for k in column_keys]
        writer.writerow(values)

def main():
    parser = argparse.ArgumentParser(description="Convert JSON to CSV.")
    parser.add_argument('-j', '--json', required=True, help='Path to the JSON file.')
    args = parser.parse_args()

    json_to_csv(args.json)

if __name__ == '__main__':
    main()
