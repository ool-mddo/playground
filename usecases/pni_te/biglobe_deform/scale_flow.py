import csv
import argparse
import sys

def modify_csv_rate(input_csv, rate):
    reader = csv.DictReader(input_csv)
    writer = csv.DictWriter(sys.stdout, fieldnames=reader.fieldnames)

    # CSVのヘッダーを出力
    writer.writeheader()

    # CSVの各行を処理して、rate列を更新
    for row in reader:
        if 'rate' in row:
            row['rate'] = float(row['rate']) * rate
        writer.writerow(row)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Modify rate column in CSV by a specified rate.')
    parser.add_argument('csvfile', type=argparse.FileType('r'), help='Input CSV file')
    parser.add_argument('-r', '--rate', type=float, required=True, help='Multiplier for the rate column')

    args = parser.parse_args()

    # CSVを読み込み、rate列を変更
    modify_csv_rate(args.csvfile, args.rate)

