reset
data_dir = ARG1
print("# data directory = %s", data_dir)
data_file = sprintf("%s/multi_region_summary.dat", data_dir)

set term pngcairo size 1200, 400
set output sprintf("%s/multi_region_summary.png", data_dir)

set title font "Monospace Regular,14"
set tics font "Monospace Regular,12"
set xlabel font "Monospace Regular,12"
set ylabel font "Monospace Regular,12"
set key font "Monospace Regular,14"

set key noenhanced

set multiplot layout 1, 2

set xrange [0:]
set yrange [0:]
set xlabel 'Regions'

set ylabel 'Elapsed-Time [sec]'
plot \
  data_file using 2:5 with linespoints title 'total', \
  data_file using 2:6 with linespoints title 'generate_topology'

set ylabel 'Batfish max mem usage [B]'
plot data_file using 2:4 with linespoints title 'max mem usage'

unset multiplot
