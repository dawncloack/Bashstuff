#!/bin/bash
: '
patentCounter.sh
Programmed by Pablo Cañamares <lispandfashion@gmail.com>
29-10-2020 (European format)

This script calculates the raw number of patents published, per year. The starting point are the .csv files
produced by Espacenet, the European Patent Office. The result is the file "results.cvs" file with two fields,
year and number of patents.

All .csv files in the same directory will be analyzed. Other .csv files will provide meaningless results.

XXXXXXXXX COPYRIGHT NOTICE XXXXXXXXXX

Copyright 2020 Pablo Cañamares

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

'

function UsageMSG
{
printf "Usage:\n\n"
printf "patentCounter.sh\n"
printf "patentCounter.sh [initial year]\n\n"
printf "This script extracts the number of patents that were filed every year, and creates a CSV table from the initial year to the current year. The default initial year is 1900.\nIt is designed to work only with the .csv files of the European Patent office. The result, when used with other .csv files will be nonsensical.\n\n"
printf "The script will process every single patent in the current working directory. It is up to you to give it EPO .csv files that make sense to analyze together.\n\n"
printf "The first line contains the time and date, then the searches of each CSV file fed, then the years and Nº of patents. \n\n"
printf "Bad input aborts.\n\n"
printf "If parameters are absent, final year is the current year, according to the computer clock, and initial year, 1900.\n\n"
printf "Coded by Pablo Cañamares, lispandfashion@gmail.com, October 2020\n"
}


function echoerr { printf "$@\n" 1>&2; } #The only point of this function is to make error messages more legible in the code.

declare -i fileCount=$(ls -1 *.csv 2>/dev/null | wc -l) # First we count the number of CSV files, to make sure there are some.

if (( fileCount < 1 ))
    then
	UsageMSG
    echoerr "\n\nNo CSV files present."
	unset fileCount #This might seem unnecessary, but garbage collection is a good programming practice.
	exit 1
fi

declare -ir finalYear=$(date +"%Y")


if [[ -n $(echo $1 | grep -oE '[[:alpha:]]') ]] # If $1 is anything but numbers
	then
	UsageMSG
	echoerr "\n\nBad input in initial year!"
	exit 1
else
	declare -ir initialYear=${1:-1900} #if the input input is correct, it is assigned, otherwise it defaults
fi

if (( $initialYear >= $finalYear )) # If the final year is smaller than the initial one, they are swapped
	then
	UsageMSG
	echoerr "\n\nInvalid starting year."
	exit 1
fi


declare -ar yearSpace=($(seq --separator=' ' $initialYear $finalYear)) # This declaration makes a read only array with the list of years. This declaration creates an array for the values in each member of the array. Each year and values per year share the same array index
declare -a valueSpace # This array will contain the hits per year
declare -a headerSpace # This array will contain some headers with the hits per search, to be inserted at the beginning

fileCount=0

for nextFile in *.csv
do

headerSpace[fileCount]=$(cat $nextFile | sed -n '3p' | cut -f1 --delimiter=\;)
# The third line of each CSV, containing the number of hits per search and the name of the search, is copied.

    	for nextHit in $(egrep -o '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}";"[[:digit:]]{4}' $nextFile | \
	cut -f1 --delimiter=\; | \
	cut -f1 --delimiter=- | \
	awk -v AWKvar="$initialYear" '$1 >= AWKvar {print $1}')
#This grep-cut-cut-awk command extracts the year of publication from an Espacenet CSV. It is based on the observation that the publication year is the only date followed immediately by another date (that of the first priority). Only years above the initial one are provided.
    	do
    	debugVal=$((nextHit - initialYear))
    	printf "(%s - %s = %s)\n" $nextHit $initialYear $debugVal
        (( valueSpace[((nextHit - initialYear))]++ )) #using the initial year as offset lets us avoid costly searches through the array for each hit.

    	done

(( fileCount++ ))

done <<< "$nextFile"

resultsFilename="results$$.csv" #The output file will be named results + the PID of the creating process.

touch "$resultsFilename"

{ # this entire block of code redirects output to results.csv.
printf "\"\";\"\";\"%s\"\n" "$(date)" # First, the date and time.

for element in "${headerSpace[@]}" # Second, the header from the csv are copied. They contain the names of searches and the hits per search.
do
	printf "\"\";\"\";%s\n" "$element"
done

printf "\"\";\"\";\"%s\"\n" "(total results, unfiltered by year)"

echo "\"Year\";\"Number of patents\";\"\"" #This is the header of the .csv file

readonly writerMax=$(( $(date +"%Y") - $initialYear ))
writerCount=0

while (( $writerCount <= $writerMax ))
do
    echo "${yearSpace[$writerCount]};${valueSpace[writerCount]:-0}" #The .csv is populated with two columns, year, and number of patents.
    (( writerCount++ ))

done
} >> "$resultsFilename"

unset fileCount
unset valueSpace
unset headerSpace
unset finalyear
unset writerCount
unset resultsFilename

exit 0 #Successful termination
