reset
data_dir = ARG1
print("# data directory = %s", data_dir)
data_file = sprintf("%s/unit_query_summary.log", data_dir)

set term pngcairo size 800, 600
set output sprintf("%s/unit_query_summary.png", data_dir)

set title font "Monospace Regular,14"
set tics font "Monospace Regular,12"
set xlabel font "Monospace Regular,12"
set ylabel font "Monospace Regular,12"
set key font "Monospace Regular,14"

set key noenhanced

set xrange [0:]
set yrange [0:]
set xlabel 'Regions'
set ylabel 'Time (real) [sec]'

plot \
  data_file using 2:3 with linespoints title 'load_snapshot', \
  data_file using 2:4 with linespoints title 'check_loaded_snapshot', \
  data_file using 2:5 with linespoints title 'single_snapshot_queries', \
  data_file using 2:6 with linespoints title 'tracert_neighbor_region', \
  data_file using 2:7 with linespoints title 'tracert_facing_region'
