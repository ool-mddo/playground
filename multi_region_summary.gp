reset

data_file='multi_region_summary.dat'

set term pngcairo size 1200, 400
set output "multi_region_summary.png"

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
  data_file using 2:8 with linespoints title 'snapshot_to_model', \
  data_file using 2:10 with linespoints title 'netoviz_model', \
  data_file using 2:12 with linespoints title 'netomox_diff'

set ylabel 'Batfish max mem usage [B]'
plot data_file using 2:4 with linespoints title 'max mem usage'

unset multiplot
