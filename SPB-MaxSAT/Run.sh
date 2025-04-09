#!/bin/bash

# 为每个数据集定义不同的跳过文件列表
skip_files_list=(
    
)


# 处理子目录函数
process_directory() {
    local dataset_path="$1"
    local files_to_process=()

    # 处理目录
    for file in "$dataset_path"/*; do
        if [ -d "$file" ]; then
            # 递归调用处理子目录
            files_to_process+=($(process_directory "$file"))
        else
            files_to_process+=("$file")
        fi
    done

    # 返回收集的文件列表
    echo "${files_to_process[@]}"
}


# 获取当前脚本的目录（例如SPB-MaxSAT目录）
SCRIPT_DIR="$(dirname "$0")"

# 定义测试函数
test() {
    local dataset_path="$1"
    local skip_files=("${!2}")  # 获取跳过的文件列表
    local max_jobs=50  # 设置最大并发任务数
    local current_jobs=0  # 当前运行的后台进程数

    # 调用 process_directory 获取文件列表
    files_to_process=($(process_directory "$dataset_path"))

    # 处理文件
    for file in "${files_to_process[@]}"; do
        (
            # 检查文件是否在跳过列表中
            local relative_path="${file#$INIT_PATH/}"  # 去掉开头的 ../Benchmarks/
            if [[ " ${skip_files[@]} " == *" ${relative_path} "* ]]; then
                echo "Skipping $relative_path"
                return  # 使用 return 来退出当前进程
            fi

            # 获取第一级目录名（例如 WPMS_2020）
            first_level_dir=$(echo "$relative_path" | cut -d'/' -f1)

            # 直接加上 '_SPB-MaxSAT' 后缀
            output_dir="$SCRIPT_DIR/Detail_Results/${first_level_dir}_SPB-MaxSAT"

            # 在当前脚本目录下创建目录（如果不存在）
            mkdir -p "$output_dir"

            # 为每个文件生成唯一的输出文件名，基于文件的相对路径
            output_origin="${relative_path//\//_}.txt"

            # 创建一个以输出文件名（去掉扩展名）为名的目录
            file_dir="$output_dir/${output_origin%.txt}"
            mkdir -p "$file_dir"  # 创建文件夹（如果文件夹不存在）


            # 处理文件，输出到相应的目录
            wl=300
            ./runsolver --timestamp -d 15 -o "$file_dir/output.out" -v "$file_dir/output.var" -w "$file_dir/output.wat" -C $wl ./SPB-MaxSAT "$file"
            # 将 output.out 内容追加到 output_origin 文件
            cat "$file_dir/output.out" >> "$output_dir/$output_origin"

            # 删除文件夹中的临时文件
            rm -f "$file_dir/output.out"
            rm -f "$file_dir/output.var"
            rm -f "$file_dir/output.wat"

            # 删除创建的目录
            rmdir "$file_dir"  # 删除空目录
        ) &  # 使用 & 启动并行任务

        # 管理并发任务数
        ((current_jobs++))
        if ((current_jobs >= max_jobs)); then
            # 等待前面启动的某个任务完成
            wait
            ((current_jobs=0))
        fi
    done

    # 等待所有子进程完成
    wait
}

# 初始化路径和数据集数组
INIT_PATH="../Benchmarks"
# datasets=("PMS_2020" "PMS_2021" "PMS_2022" "PMS_2023" "PMS_2024")
# datasets=("WPMS_2020" "WPMS_2021" "WPMS_2022" "WPMS_2023" "WPMS_2024")
datasets=("PMS_2020" "PMS_2021" "PMS_2022" "PMS_2023" "PMS_2024" "WPMS_2020" "WPMS_2021" "WPMS_2022" "WPMS_2023" "WPMS_2024")

# 并行运行每个数据集的测试
for i in "${!datasets[@]}"; do
    (
        dataset_name="${datasets[i]}"
        skip_files=(${skip_files_list[@]})
        
        test "$INIT_PATH/$dataset_name" skip_files[@]
    )
done


