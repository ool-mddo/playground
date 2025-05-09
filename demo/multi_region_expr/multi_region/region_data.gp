#!/us/bin/env gnuplot

reset

DATA_FILE = "multi_region_summary.dat"

# use csv
set datafile separator ","

# output (x11)
# set terminal x11 size 1050,350
# output (eps)
set term postscript enhanced eps color font ",20" size 9, 3 # size=inch
set output "region_data.eps"

set multiplot layout 1,2

# common
set xrange [0:40]
set xlabel "Region"
set key right bottom
set grid

###############
# graph 1 (mem)

set title "Memory Usage (Maximum)"
set yrange [0:]
set ylabel "Maximum Memory Used [MB]"

# fitting (mem)
set fit logfile "fitting_mem.log"
g(x) = p*x + q
fit [0:40][:] g(x) DATA_FILE using 2:4 via p,q

plot DATA_FILE using 2:($4/10**6) with points linetype 1 linewidth 4 pointsize 3 pointtype 2 title "Max Mem used", \
    [2:40] g(x)/10**6 with lines linetype 1 linewidth 2 title "Fit: Mem used"

###############
# graph 2 (deploy time)

set title "Elapsed time and Memory Usage"
set yrange [0:]
set ylabel "Elapsed time [s]"

# fitting (time)
set fit logfile "fitting_time.log"
f(x) = a*x**2 + b*x + c
fit [0:40][:] f(x) DATA_FILE using 2:5 via a,b,c

plot DATA_FILE using 2:5 with points linetype 2 linewidth 4 pointsize 3 pointtype 2 title "Elapsed time", \
    [2:40] f(x) with lines linetype 2 linewidth 2 title "Fit: Elapsed time"

unset multiplot
