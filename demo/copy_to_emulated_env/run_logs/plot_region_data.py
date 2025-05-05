import argparse
import csv
import json
import os
import re
import sys


def mem_used_avg(data_dir, branch_dir):
    csv_path = os.path.join(data_dir, branch_dir, "demo_wait_resources.csv")
    mem_used_values = []

    try:
        with open(csv_path, newline='') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                try:
                    mem_used = float(row["mem_used"])
                    mem_used_values.append(mem_used)
                except (ValueError, KeyError):
                    continue  # 数値変換エラーやカラム欠損時はスキップ

        if not mem_used_values:
            print("mem_used のデータが見つかりませんでした。")
            return None

        avg = sum(mem_used_values) / len(mem_used_values)
        return avg

    except FileNotFoundError:
        print(f"ファイルが見つかりません: {csv_path}")
    except Exception as e:
        print(f"エラーが発生しました: {e}")

    return None


def deploy_duration(data_dir, branch_dir):
    log_path = os.path.join(data_dir, branch_dir, "demo_step2-2.log")

    try:
        with open(log_path, 'r') as file:
            for line in file:
                if "deploy containerlab" in line:
                    match = re.search(r'deploy containerlab .*? ([\d.]+)s', line)
                    if match:
                        return float(match.group(1))
        print(f"'deploy containerlab' を含む行が見つかりませんでした: {log_path}")
    except FileNotFoundError:
        print(f"ファイルが見つかりません: {log_path}")
    except Exception as e:
        print(f"エラーが発生しました: {e}")

    return None

def region_number(branch_dir):
    match = re.match(r'^(\d+)', branch_dir)
    if match:
        return int(match.group(1))
    return None

def region_data(data_dir, branch_dir):
    return {
        "branch": branch_dir,
        "region": region_number(branch_dir),
        "deploy_duration": deploy_duration(data_dir, branch_dir),
        "mem_used_avg": mem_used_avg(data_dir, branch_dir)
    }

def list_directories(path):
    try:
        # 指定されたパス内のディレクトリ名のみを取得
        directories = [name for name in os.listdir(path) if os.path.isdir(os.path.join(path, name))]
        return directories
    except Exception as e:
        print(f"エラーが発生しました: {e}")
        return []

def print_region_data_csv(data_dir, region_data_list):
    output_path = os.path.join(data_dir, "region_data_list.csv")
    fieldnames = ["branch", "region", "deploy_duration", "mem_used_avg"]

    try:
        with open(output_path, mode="w", newline="") as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for row in region_data_list:
                writer.writerow(row)
        print(f"CSVファイルを出力しました: {output_path}")
    except Exception as e:
        print(f"CSV出力中にエラーが発生しました: {e}")


def main():
    parser = argparse.ArgumentParser(description="plot region data")
    parser.add_argument("-d", "--directory", required=True, help="対象のディレクトリパス")
    args = parser.parse_args()

    data_dir = args.directory
    branch_dirs = list_directories(data_dir)
    region_data_list = [region_data(data_dir, branch_dir) for branch_dir in branch_dirs]
    region_data_list.sort(key=lambda x: x["region"])
    print(json.dumps(region_data_list, indent=2), file=sys.stderr)
    print_region_data_csv(data_dir, region_data_list)


if __name__ == "__main__":
    main()