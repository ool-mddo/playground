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
set ylabel "Memory Used [MB]"
set y2range [0:]
set y2label "Deploy required time [s]"
set y2tics
set ytics nomirror
set y2tics
set grid xtics, ytics, y2tics
set key right bottom

# fitting (mem)
set fit logfile "fitting_mem.log"
f(x) = a*x + b
fit [0:20][:] f(x) DATA_FILE using 2:4 via a,b

# fitting (time)
set fit logfile "fitting_time.log"
g(x) = c*x + d
fit [0:20][:] g(x) DATA_FILE using 2:3 via c,d

plot \
    DATA_FILE using 2:4 with points ls 1 linewidth 4 title "Mem used avg" axis x1y1 noenhanced, \
    f(x) with lines ls 1 linewidth 2 title "Fit: Mem used avg" axis x1y1, \
    DATA_FILE using 2:3 with points ls 2 linewidth 4 title "Deploy required time" axis x1y2 noenhanced, \
    g(x) with lines ls 2 linewidth 2 title "Fit: Deploy required time" axis x1y2
