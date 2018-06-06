#!/bin/bash

_VM=false
lscpu | awk '/Virtualization type/ {print $3}'|grep -q full
if [[ "$?" == "0" ]]; then
	_VM=true
fi

_DURATION="2m"
cyclictest \
	--duration=${_DURATION} \
	--mlockall \
	--priority=99 \
	--nanosleep \
	--interval=200 \
	--histogram=5000 \
	--histfile=./output \
	--threads \
	--numa \
	--notrace

# --duration=TIME 	Specify a length for the test run
# --mlockall 		Lock current and future memory allocations
# --priority=PRIO	Set the priority of the first thread
# --nanosleep		Use clock_nanosleep instead of posix interval timers
# --interval=INTV	Set the base interval of the thread(s) in microseconds
# --histogram=US	Dump latency histogram to stdout after the run
# --histfile=<path>	Dump the latency histogram to <path> instead of stdout
# --threads=[=NUM]	Set the number of test threads 
# --numa		Standard NUMA testing
# --notrace		suppress tracing

# http://www.osadl.org/Create-a-latency-plot-from-cyclictest-hi.bash-script-for-latency-plot.0.html

_MAX=$(grep "Max Latencies" output | sed "s/# Max Latencies: //g" | tr " " "\n" | sort -n | tail -1 | sed s/^0*//)
if ! ${_VM}; then
	_MAXNOSYS=$(grep "# Max Latencies:" output | sed "s/# Max Latencies: //g" | awk '{print $2, $3, $4, $5, $6, $7, $8 ,$9, $10, $12, $13, $14, $15, $16, $17, $18 ,$19, $20, $22, $23, $24, $25, $26, $27, $28 ,$29, $30, $32, $33, $34, $35, $36, $37, $38 ,$39, $40}' | tr " " "\n"| sort -n | tail -1 | sed s/^0*//)
	_CORES=40
	_EXCLUDE="0|10|20|30"
else
	_MAXNOSYS=$(grep "# Max Latencies:" output | sed "s/# Max Latencies: //g" | awk '{print $2, $3, $4, $5, $6, $7, $8}' | tr " " "\n"| sort -n | tail -1 | sed s/^0*//)
	_CORES=8
	_EXCLUDE="0"
fi

grep -v -e "^#" -e "^$" output | tr " " "\t" > histogram

for ((_CPU=0;_CPU<${_CORES};_CPU++))
do
	_COLUMN=$((_CPU+2))
	cut -f1,${_COLUMN} histogram > histogram${_CPU}
done

cat > plotcmdsys << EOF
set title "Latency plot"
set terminal png
set xlabel "Latency (μs), max ${_MAX} us"
set logscale y
set xrange [0:$((_MAX+5))]
set yrange [0.8:*]
set ylabel "Number of latency samples"
set output "plot_sys.png"
EOF

cat > plotcmdnosys << EOF
set title "Latency plot"
set terminal png
set xlabel "Latency (μs), max ${_MAXNOSYS} us"
set logscale y
set xrange [0:$((_MAXNOSYS+5))]
set yrange [0.8:*]
set ylabel "Number of latency samples"
set output "plot_nosys.png"
EOF

echo -n "plot " >> plotcmdsys
echo -n "plot " >> plotcmdnosys

for ((_CPU=0;_CPU<${_CORES};_CPU++))
do
	if (( ${_CPU} < 10 )); then
		_TITLE=" CPU${_CPU}"
	else
		_TITLE="CPU${_CPU}"
	fi

	if (( ${_CPU} != $((_CORES-1)) )); then
		echo -n "\"histogram${_CPU}\" using 1:2 title \"${_TITLE}\" with histeps, " >> plotcmdsys
		echo ${_CPU}|grep -E -q "${_EXCLUDE}"
		if [[ "$?" != "0" ]]; then
			echo -n "\"histogram${_CPU}\" using 1:2 title \"${_TITLE}\" with histeps, " >> plotcmdnosys
		fi
	else
		echo -n "\"histogram${_CPU}\" using 1:2 title \"${_TITLE}\" with histeps" >> plotcmdsys
		echo -n "\"histogram${_CPU}\" using 1:2 title \"${_TITLE}\" with histeps" >> plotcmdnosys
	fi
done
gnuplot -persist < plotcmdsys
gnuplot -persist < plotcmdnosys
rm -f histogram* plotcmd*
