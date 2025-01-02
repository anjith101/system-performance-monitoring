#!/bin/bash

# File for JSON output
jsonFile="system_report.json"
# File for text output
textFile="system_report.txt"
# Function to check CPU usage
checkCpuUsage() {
    local cpuUsage=$(top -bn1 | awk '/%Cpu/ {print $2}')
    local threshold=80
    if [ "$format" == "text" ]; then
        echo "CPU usage: $cpuUsage%" >>"$textFile"
        if [ $(echo "$cpuUsage > $threshold" | bc) -eq 1 ]; then
            echo "Warning! CPU usage has exceeded $threshold%" >>"$textFile"
            echo "Warning! CPU usage has exceeded $threshold%"
        fi
        echo $cpuUsage
    else
        if [ $(echo "$cpuUsage > $threshold" | bc) -eq 1 ]; then
            echo "Warning! CPU usage has exceeded $threshold%"
        fi
        echo $(jq -n --arg usage "$cpuUsage" --argjson exceeded "$(echo "$cpuUsage > $threshold" | bc -l)" \
            '{cpu_usage: {usage: $usage, threshold_exceeded: $exceeded}}')
    fi
}

# Function to check memory usage
checkMemoryUsage() {
    local memoryData=($(free -m | awk '/Mem/ {print $2, $3, $4}'))
    local total=${memoryData[0]}
    local used=${memoryData[1]}
    local free=${memoryData[2]}
    local usedPercentage=$((used * 100 / total))
    local threshold=75
    if [ "$format" == "text" ]; then
        echo "Total Memory: $total MB" >>"$textFile"
        echo "Used Memory: $used MB" >>"$textFile"
        echo "Free Memory: $free MB" >>"$textFile"
        echo "Used Memory Percentage: $usedPercentage%" >>"$textFile"
        if [ $usedPercentage -gt $threshold ]; then
            echo "Warning! Used Memory Percentage has exceeded $threshold%" >>"$textFile"
            echo "Warning! Used Memory Percentage has exceeded $threshold%"
        fi
        echo $usedPercentage
    else
        if [ $(echo "$cpuUsage > $threshold" | bc) -eq 1 ]; then
            echo "Warning! Used Memory Percentage has exceeded $threshold%"
        fi
        echo $(jq -n --arg total "$total" --arg used "$used" --arg free "$free" \
            --argjson used_percentage "$usedPercentage" --argjson exceeded "$((usedPercentage > threshold))" \
            '{memory_usage: {total: $total, used: $used, free: $free, used_percentage: $used_percentage, threshold_exceeded: $exceeded}}')
    fi
}

# Function to check disk usage
checkDiskUsage() {
    local diskUsage=$(df -h / | awk 'NR>1 {print $5}' | tr -d '%')
    local threshold=90
    if [ "$format" == "text" ]; then
        echo "Disk usage Percentage: $diskUsage%" >>"$textFile"
        if [ $diskUsage -gt $threshold ]; then
            echo "Warning! Disk usage has exceeded $threshold%" >>"$textFile"
            echo "Warning! Disk usage has exceeded $threshold%"
        fi
        echo $diskUsage
    else
        if [ $(echo "$cpuUsage > $threshold" | bc) -eq 1 ]; then
            echo "Warning! Disk usage has exceeded $threshold%"
        fi
        echo $(jq -n --arg usage "$diskUsage" --argjson exceeded "$((diskUsage > threshold))" \
            '{disk_usage: {usage: $usage, threshold_exceeded: $exceeded}}')
    fi
}
getAvailableDisk() {
    printf "Disk usage for each file system: \n\n" >>"$textFile"
    df -h | awk 'NR>1 {printf "Filesystem: %-12s | Total: %6s | Used: %6s | Available: %6s | Mount: %s\n", $1, $2, $3, $4, $6}' | while read -r line; do
        echo "$line" >>"$textFile"
    done
}
# Function to get top five CPU-consuming processes
getTopFiveProcesses() {
    if [ "$format" == "text" ]; then
        echo "Top five CPU consuming processes:" >>"$textFile"
        top -bn1 | head -n 12 | tail -n 5 | while read -r line; do
            echo "$line" >>"$textFile"
        done
    else
        local topProcesses=$(top -bn1 | head -n 12 | tail -n 5 | awk '{printf "{\"pid\": \"%s\", \"user\": \"%s\", \"cpu\": \"%s\", \"command\": \"%s\"},", $1, $2, $9, $12}')
        topProcesses="[${topProcesses%,}]"
        echo $(jq -n --argjson processes "$topProcesses" '{top_processes: $processes}')
    fi
}

# Append data to JSON file
appendJson() {
    local timestamp=$(date)
    local cpuData=$(checkCpuUsage)
    local memoryData=$(checkMemoryUsage)
    local diskData=$(checkDiskUsage)
    local topProcesses=$(getTopFiveProcesses)

    # Combine all data into a single object
    local combinedData=$(jq -n --arg date "$timestamp" \
        --argjson cpu "$cpuData" \
        --argjson memory "$memoryData" \
        --argjson disk "$diskData" \
        --argjson processes "$topProcesses" \
        '{date: $date, data: {cpu_usage: $cpu.cpu_usage, memory_usage: $memory.memory_usage, disk_usage: $disk.disk_usage, top_processes: $processes.top_processes}}')

    # Check if file exists and is non-empty, append new data
    if [ ! -f "$jsonFile" ] || [ ! -s "$jsonFile" ]; then
        echo "[$combinedData]" >"$jsonFile"
    else
        local tempFile=$(mktemp)
        jq ". += [$combinedData]" "$jsonFile" >"$tempFile" && mv "$tempFile" "$jsonFile"
    fi
}
# Draw graphical output in terminal
drawGraph() {
    local usage=$1
    local label=$2
    echo "$label USAGE IS: $usage%"
    local graphWidth=50
    local numHashes=$(echo "$usage * $graphWidth / 100" | bc | awk '{printf "%.0f", $1}')
    local graph=$(printf "%-${graphWidth}s" "#" | sed "s/ /-/g")
    if [ "$numHashes" -gt 0 ]; then
        graph=$(echo "$graph" | sed "s/-/#/g" | cut -c1-$numHashes)
    fi
    printf "[%-${graphWidth}s]\n\n" "$graph" | sed "s/ /-/g"
}
# Monitoring loop
runMonitoring() {
    while true; do
        if [ "$format" == "text" ]; then
            # Text format output
            echo -e "\n##################################################\n" >>"$textFile"
            date >>"$textFile"
            echo -e "\n##################################################\n" >>"$textFile"
            local cpuUsage=$(checkCpuUsage)
            drawGraph "$cpuUsage" "CPU"
            echo -e "\n--------------------------------------------------\n" >>"$textFile"
            local memoryUsage=$(checkMemoryUsage)
            drawGraph "$memoryUsage" "MEMORY"
            echo -e "\n--------------------------------------------------\n" >>"$textFile"
            local diskUsage=$(checkDiskUsage)
            drawGraph "$diskUsage" "DISK"
            echo -e "\n--------------------------------------------------\n" >>"$textFile"
            getAvailableDisk
            echo -e "\n--------------------------------------------------\n" >>"$textFile"
            getTopFiveProcesses
            echo -e "\n--------------------------------------------------\n" >>"$textFile"
        else
            # JSON format output
            appendJson
        fi

        sleep "$interval"
    done
}

# Validation for input arguments
isInteger() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Default values
interval=10
format="text"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --interval)
        interval=$2
        if ! isInteger "$interval"; then
            echo "Invalid interval. Enter a valid integer."
            exit 1
        fi
        shift 2
        ;;
    --format)
        format=$2
        if [[ "$format" != "text" && "$format" != "json" ]]; then
            echo "Invalid format. Enter a valid format (text or json)."
            exit 1
        fi
        shift 2
        ;;
    *)
        echo "Invalid argument. Possible option: --interval --format"
        exit 1
        ;;
    esac
done

# Start monitoring
runMonitoring
