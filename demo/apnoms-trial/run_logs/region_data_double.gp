#!/us/bin/env gnuplot

reset

# 引数チェック
print "check args, ARGC:" . ARGC . ", arg1:" . ARG1
if (ARGC != 1) {
    print "Usage: gnuplot region_data_double.gp <date_dir>"
    exit
}
DATA_DIR = ARG1
DATA_FILE = DATA_DIR . "/" . "region_data_list.csv"

# use csv
set datafile separator ","

# output (x11)
# set terminal x11 size 1050,350
# output (eps)
set term postscript enhanced eps color font ",20" size 9, 3 # size=inch
set output "region_data_double_" . DATA_DIR . ".eps"

set multiplot layout 1,2

# common
set xrange [0:20] # 40 region failed
set xlabel "Region"
set key right bottom
set grid

###############
# graph 1 (mem)

set title "Memory usage (average)"
set yrange [0:]
set ylabel "Memory used [MB]"

# fitting (mem)
set fit logfile "fitting_mem.log"
f(x) = a*x + b
fit [0:20][:] f(x) DATA_FILE using 2:4 via a,b

plot DATA_FILE using 2:4 with points linetype 1 linewidth 4 pointsize 3 pointtype 2 title "Mem used avg", \
    [2:20] f(x) with lines linetype 1 linewidth 2 title "Fit: Mem used avg"

###############
# graph 2 (deploy time)

set title "Time required for deployment"
set yrange [0:]
set ylabel "Time [s]"

# fitting (time)
set fit logfile "fitting_time.log"
g(x) = c*x + d
fit [0:20][:] g(x) DATA_FILE using 2:3 via c,d

plot DATA_FILE using 2:3 with points linetype 2 linewidth 4 pointsize 3 pointtype 2 title "Time required for deployment", \
    [2:20] g(x) with lines linetype 2 linewidth 2 title "Fit: Time required for deployment"

unset multiplot
