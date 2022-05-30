# call "docker_stats.gp" <data_dir>

reset
data_dir = ARG1
print("# data directory = %s", data_dir)

set term pngcairo size 2500, 1000
set output sprintf("%s/%s", data_dir, "graph.png")

set title font "Monospace Regular,14"
set tics font "Monospace Regular,12"
set xlabel font "Monospace Regular,12"
set ylabel font "Monospace Regular,12"
set key font "Monospace Regular,14"

set xrange [0:]
set yrange [0:]
set xlabel 'Elapsed-Time [sec]'

set multiplot layout 2, 4 title data_dir font "Monospace Regular,14" noenhanced

data_files = system(sprintf("ls %s/*.dat", data_dir))
do for [data_file in data_files] {
  if (data_file eq sprintf("%s/cpu_percent.dat", data_dir) || data_file eq sprintf("%s/mem_percent.dat", data_dir)) {
    set ylabel "Percent [%]"
  } else {
    set ylabel "Byte [B]"
  }

  title_str = sprintf("%s", system("basename ".data_file))
  set title title_str noenhanced
  plot \
    data_file using 1:2 with linespoints title 'netomox-exp', \
    data_file using 1:3 with linespoints title 'batfish-wrapper', \
    data_file using 1:4 with linespoints title 'batfish'
}

unset multiplot
