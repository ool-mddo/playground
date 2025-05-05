#!/us/bin/env gnuplot

reset

# 引数チェック
print "check args, ARGC:" . ARGC . ", arg1:" . ARG1
if (ARGC != 1) {
    print "Usage: gnuplot mem_usage.gp <date_dir>"
    exit
}
DATA_DIR = ARG1
DATA_FILE = DATA_DIR . "/" . "region_data_list.csv"

# use csv
set datafile separator ","

set title "Deploy Duration and Memory Usage by Region"
set xrange [0:20] # 40 region failed
set xlabel "Region"

set yrange [0:]
set ylabel "Memory Used (GB)"
set y2range [0:]
set y2label "Deploy Duration (s)"
set y2tics
set ytics nomirror
set y2tics
set grid
set key right outside

plot \
    DATA_FILE using 2:($4/1000) with linespoints title "Mem used avg" axis x1y1 noenhanced, \
    "" using 2:3 with linespoints title "Deploy duration" axis x1y2 noenhanced