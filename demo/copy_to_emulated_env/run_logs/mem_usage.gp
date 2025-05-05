#!/usr/bin/env gnuplot

reset

# 引数チェック
print "check args, ARGC:" . ARGC . ", arg1:" . ARG1

if (ARGC != 1) {
    print "Usage: gnuplot mem_usage.gp <date_dir/branch>"
    exit
}

# 引数からターゲットディレクトリを取得
TARGET_DIR = ARG1
TARGET_PATH = system("pwd") . "/" . TARGET_DIR

# ディレクトリの存在確認
print "Check directory: " . TARGET_PATH
system("test -d '" . TARGET_PATH . "'")
if (GPVAL_SYSTEM_ERRNO != 0) {
    print "Error: Directory " . TARGET_PATH . " not found"
    exit
}

# function
file_name(script_name) = TARGET_PATH . "/" . script_name . "_resources.csv"

# scripts
array scripts = ["demo_step1-1", "demo_step1-2", "demo_step2-1", "demo_step2-2", "demo_wait", "demo_task"]
scripts_num = words(join(scripts, ' '))

# グラフ設定
set title "Memory Usage Over Time - " . TARGET_DIR
# epoch time -> human readable string
# set xdata time
# set timefmt "%s"
# set format x "%H:%M:%S"
# set xlabel "Time"

# use relative time (elapsed time)
set xrange [0:]
set xlabel "Elapsed Time [s]"
set yrange [0:]
set ylabel "Memory Usage (%)"
set grid
set key left top

# 最初の時刻（epoch）を取得（例：最初のCSVファイルの2行目のtimestamp）
start_epoch = system("awk -F',' 'NR==2 {print $1}' " . file_name(scripts[1]))

# スクリプト切り替え点に縦線とラベルを追加
do for [i=1:scripts_num] {
    file = file_name(scripts[i])
    print "target data file: " . file
    first_epoch = system("awk -F',' 'NR==2 {print $1}' " . file) - start_epoch
    step_name = scripts[i]
    set arrow from first_epoch, graph 0 to first_epoch, graph 1 nohead lc rgb "gray" lw 1 dt 2
    # set label step_name at first_epoch, graph 1 offset 0,1
}

# グラフ描画
plot for [i=1:scripts_num] file_name(scripts[i]) using ($1 - start_epoch):($4/$3*100) with lines title scripts[i] noenhanced
# plot file_name(scripts[1]) using 1:($4/$3*100) with lines title scripts[1] noenhanced

