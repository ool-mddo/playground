#!/usr/bin/env gnuplot

reset

# 引数チェック
print "check args, ARGC:" . ARGC . ", arg1:" . ARG1
if (ARGC != 1) {
    print "Usage: gnuplot mem_usage.gp <date_dir>"
    exit
}
DATA_DIR = ARG1

# function
dir_full_path(branch_name) = system("pwd") . "/" . DATA_DIR . "/" . branch_name
file_full_path(branch_name, script_name) = dir_full_path(branch_name) . "/" . script_name . "_resources.csv"
arr_len(list) = words(join(list, " "))
# 最初の時刻（epoch）を取得（例：CSVファイルの2行目のtimestamp）
head_epoch_in_file(file_path) = system("awk -F',' 'NR==2 {print $1}' " . file_path)
# 最後の時刻（epoch）を取得（例：CSVファイルの最後のtimestamp）
tail_epoch_in_file(file_path) = system("awk -F',' 'END {print $1}' " . file_path)

# targets
array branches = split(system(sprintf("ls %s | grep -v csv | sort -n", DATA_DIR)))
branches_len = arr_len(branches)
array scripts = ["demo_step1-1", "demo_step1-2", "demo_step2-1", "demo_step2-2", "demo_wait", "demo_task"]
scripts_len = arr_len(scripts)

# multiplot
eval(sprintf("set multiplot layout %d,1", branches_len))

# 最大経過時間をもとに横軸を合わせる
last_branch_name = branches[branches_len]
last_branch_start = head_epoch_in_file(file_full_path(last_branch_name, scripts[1]))
last_branch_end = tail_epoch_in_file(file_full_path(last_branch_name, scripts[scripts_len]))
max_xrange = last_branch_end - last_branch_start

# use csv
set datafile separator ","

do for [b=1:branches_len] {
    # 引数からターゲットディレクトリを取得
    branch_name = branches[b]

    # ディレクトリの存在確認
    print "Check directory: " . branch_name
    system("test -d '" . dir_full_path(branch_name) . "'")
    if (GPVAL_SYSTEM_ERRNO != 0) {
        print "Error: Directory " . dir_full_path(branch_name) . " not found"
        exit
    }

    # グラフ設定
    set title "Memory Usage Over Time - " . branch_name
    # epoch time -> human readable string
    # set xdata time
    # set timefmt "%s"
    # set format x "%H:%M:%S"
    # set xlabel "Time"

    # use relative time (elapsed time)
    set xrange [0:max_xrange]
    set xlabel "Elapsed Time [s]"
    set yrange [0:100]
    set ylabel "Memory Usage (%)"
    set grid
    set key right outside

    start_epoch = head_epoch_in_file(file_full_path(branch_name, scripts[1]))

    # スクリプト切り替え点に縦線とラベルを追加
    unset arrow
    do for [i=1:scripts_len] {
        print "target data file: " . scripts[i]
        first_epoch = head_epoch_in_file(file_full_path(branch_name, scripts[i])) - start_epoch
        step_name = scripts[i]
        set arrow from first_epoch, graph 0 to first_epoch, graph 1 nohead lc rgb "gray" lw 1 dt 2
        # set label step_name at first_epoch, graph 1 offset 0,1
    }

    # グラフ描画
    plot for [i=1:scripts_len] file_full_path(branch_name, scripts[i]) \
      using ($1 - start_epoch):($4/$3*100) \
      with lines linewidth 3 \
      title scripts[i] noenhanced
}

# end multiplot
unset multiplot
