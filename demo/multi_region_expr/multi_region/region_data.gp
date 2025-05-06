#!/us/bin/env gnuplot

reset

DATA_FILE = "multi_region_summary.dat"

# use csv
set datafile separator ","

set title "Elapsed time and Memory Usage by Region"
set xrange [0:40]
set xlabel "Region"

set yrange [0:]
set ylabel "Maximum Memory Used [MB]"
set y2range [0:]
set y2label "Elapsed time [s]"
set y2tics
set ytics nomirror
set y2tics
set grid xtics, ytics, y2tics
set key right bottom

# fitting (time)
set fit logfile "fitting_time.log"
f(x) = a*x**2 + b*x + c
fit [:][:] f(x) DATA_FILE using 2:5 via a,b,c

# fitting (mem)
set fit logfile "fitting_mem.log"
g(x) = p*x + q
fit [:][:] g(x) DATA_FILE using 2:4 via p,q

# plot data
plot \
    DATA_FILE using 2:($4/10**6) with points ls 1 linewidth 4 title "Max Mem used" axis x1y1, \
    g(x)/10**6 with lines ls 1 linewidth 2 title "Fit: mem used" axis x1y1, \
    DATA_FILE using 2:5 with points ls 2 linewidth 4 title "Elapsed time" axis x1y2, \
    f(x) with lines ls 2 linewidth 2 title "Fit: elapsed time" axis x1y2
