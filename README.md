# system-performance-monitoring
*bash script to monitor system performance*
## PreRequisites
- jq (for json formatting)
- bc (for basic calculations)'
*use apt, yum or snap to install these two packages*
## Features
- Continuously monitor and system metrics and give proper warnings
- Record logs either in json or text file
- Option to pass interval and format using --interval or --format flags
- Error handling for invalid flags or invalid arguments
## Execution
- Change file permission using chmod +x monitor_systems.sh or directly use bash to run
- Run the script using bash monitor_systems.sh
- by default interval is 10 seconds and report is text
- You can change it using bash monitor_systems.sh --interval 3 --format json