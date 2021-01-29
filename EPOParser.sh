#!/bin/bash

: '
EPOParser -  a script that extracts statistical information from Espacenet CSV files.

    Copyright (C) 2021  Pablo Cañamares

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
'


function version
{
printf "\nEPO Parser 1.0.1\nA script to parse statistical information from Espacenet files."
printf "\nEPOParser.sh  Copyright (C) 2021  Pablo Cañamares"
printf "\n\nThis program comes with ABSOLUTELY NO WARRANTY"
printf "\n\nSoftware under GNU GPL v3.0 License."
printf "\nThis is free software, and you are welcome to redistribute it under certain conditions;\nFor details please consult <https://www.gnu.org/licenses/>\n\n"
}


# XXXX
# Constants
# XXXX
# Because this is for the use of the CUT built-in, the first element isn't 0, it's 1.
#
# This is the order of the fields, taken from Espacenet CSV files
#"No";"Title";"Inventors";"applicant";"Publication number";"Earliest priority";"IPC";"CPC";"Publication date";"Earliest publication";"Family number";
declare -ir TITLENUM=2
declare -ir INVENTORNUM=3
declare -ir APPLICANTNUM=4
declare -ir PRIORITYNUM=6
declare -ir IPCNUM=7
declare -ir CPCNUM=8
declare -ir PUBLIDATENUM=9
declare -ir EARLYPUBNUM=10


# XXXX
# Usage function
# XXXX

function usage
{

bold=$(tput bold)
normal=$(tput sgr0)

printf "\nEPOParser will extract information from all of the Espacenet CSV files that are present in the same directory."
printf "\n${bold}Usage:${normal} EPOParser -aCdeiIptu (minimum disaggregation) ||  -axCxdyeyixIxpytxu (maximum disaggregation)"
printf "\n\n${bold}Text options:${normal}"
printf "\n\n\t-t\tCount the times specific title appears."
printf "\n\t-i\t      Count the times each inventor or group of inventors appears."
printf "\n\t-a\t      Count the times an applicant or group of applicants appears."
printf "\n\t-I\t      Count the times a specific grouping of IPC numbers appears."
printf "\n\t-C\t      Count the times a specific grouping of CPC numbers appears."
printf "\n\n\tThe dissagregation modifier \"x\" after each of the above options tries to split the entries. -Ix, for instance, it will count the number of times each IPC number appears, instead of the groupings of IPC numbers in a specific patent. -tx it will count individual words in titles, and not the appeareance of each full title."
printf "\n\n\t${bold}Exceptions: ${normal}"
printf "\n\n\tThe \"x\" option does not work with the -a option, and is unreliable with the -i options. The reason is that there is no consistent pattern to dissagreggate inventor and applicant names."
printf "\n\n\t${bold}Date options:${normal}"
printf "\n\n\t-d\tCount how many patents were published each month of each year."
printf "\n\t-p\tCount the priority dates."
printf "\n\t-e\tCount the earliest publication dates."
printf "\n\tThe modifier \"y\" after a date option eliminates the month and counts patents per year."
printf "\n\t${bold}Exceptions:${normal} Some fields of priority or earliest publication dates contain more than one date, which may muddy the results."
printf "\n\n\t${bold}Special options:${normal}"
printf "\n\n\t-u\tProvides a copy of the original, DOS-formatted Espacenet files that is UNIX-formatted, for easier CSV parsing."
printf "\n\t--help\tDisplays this help text and exits."
printf "\n\t--version\tDisplays version information and exits."
printf "\n"

}


# Function to make error messages more legible in the code
function echoerr { printf "$@\n" 1>&2; }

#Function to check whether there are Espacenet files to process, and places them in a temporary file for easier access later.
function initFileCount
{

    for fileName in *.csv
    do
            if [[ $(head -n 1  "$fileName" | grep ﻿'"Espacenet";"";"";"";"";"";"";"";"";') ]]
            then
                echo "$fileName" >> EPOfileList.temp

            fi
    done

    # This check succeeds if EPOfileList.temp is empty at this point. Note the inversion.
    if [[ ! -s EPOfileList.temp ]]
    then
            rm EPOfileList.temp
    	    echoerr "\n\nNo Espacenet CSV files present."
	        exit 127
    fi
}

# Function to transform the EPO files into a format that's easier to parse as a CSV
function win2unix # Don't call it dos2unix, that's a linux utility that already exists.
{
    while read fileName
    do

        outPutName="${fileName%.csv}_unix.csv" # This adds "_unix.csv" at the end of the filename

        perl -pe 's/\r\n//g' "$fileName" > "$outPutName" #This eliminates DOS style newlines
        sed -i '/^[[:space:]]*$/d' "$outPutName" # This eliminates whitespace
        sed -i 's_\"__g' "$outPutName" # This erases double quotes. In a CSV they make a value text and not numbers, but they make parsing difficult. Reinstated later.
        sed -i "s_'__g" "$outPutName" # associative arrays cannot deal with single tildes, so they have to go.
        sed -i '1 i\"File unixed with EPOParser.sh BASH script.\";;;;;;' "$outPutName" # With this line, unixed files wont be modified by subsequent script runs
        echo "$outPutName" >> unixedList.temp # This list will allow us to delete the temporary files at the end if they aren't wanted.

    done < EPOfileList.temp

    rm EPOfileList.temp # No reason to keep this in memory
}

# Arguments parser. Written with GETOPT
argParser()
{
# For this function to work it needs to be fed "$@"

# This instruction returns our arguments in a getopt-friendly way, so it's fed back to it later, after the -- .
parsed_args=$(getopt -n EPOParser -o -aCdeiIptuxy --long version,help -- "$@")
valid_args=$?

if [ "$valid_args" != "0" ]
then
    usage
    exit 1
fi

# The arrays below have to be declared to avoid problems with the display, in the display function.
# -A makes them associative (hash tables), -g makes them global and -i marks that they contain integers.

declare -igA titleCount
declare -igA inventorCount
declare -igA applicantCount
declare -igA publiDateCount
declare -igA priorityCount
declare -igA earliestPubCount
declare -igA IPCcount
declare -igA CPCcount

eval set -- "$parsed_args" # This sets parsed_args as if they had been given as arguments to the script itself
while : # Now the while reads from the script's argument list. This makes it so that arguments are in $n+1 and not $OPTARGS
do
    case "$1" in

    -u)

        if [[ $parsed_args == '-u' ]]
        then
            win2unix # If only a file conversion is desired the rest of the program is skipped.
        exit 0
        fi

        leaveUnixedFiles=0 # With this switch, the temporary files that we created for the program will not be deleted
        shift
        ;;


    -t)
        titleParser='eval fieldParser titleCount TITLENUM'  # If -t is selected, the title parser string will not be empty and thus will be executed.
                                                            # All entries follow the same schematic
        if [[ $2 == '-x' || $2 == '-X' ]]
        then
            titleDisaggregate=0  #With this, the strong that contains the title dissagregation will be expanded. Same for all of the entries below.
            shift # With this being here and the shift at the end, if there's an X we jump straight to the next entry.

        fi

        shift
        ;;

    -i)
        inventorParser='eval fieldParser inventorCount INVENTORNUM'

        if [[ $2 == '-x' || $2 == '-X' ]]
        then
            inventorDisaggregate=0
            shift
        fi

        shift
        ;;

    -a)
        applicantParser='eval fieldParser applicantCount APPLICANTNUM'

        if [[ $2 == '-x' || $2 == '-X' ]]
        then
            applicantDisaggregate=0
            shift
        fi

        shift
        ;;

    -d)
        dateParser='eval fieldParser publiDateCount PUBLIDATENUM'

        if [[ $2 == '-y' || $2 == '-Y' ]]
        then
            publicationMonth=0  # If this is not null, the month will be excised from the date before recounting
            shift
        fi

        shift
        ;;

    -p)
        priorityParser='eval fieldParser priorityCount PRIORITYNUM'

        if [[ $2 == '-y' || $2 == '-Y' ]]
        then
            priorityMonth=0
            shift
        fi

        shift
        ;;

    -e)
        earliestPubParser='eval fieldParser earliestPubCount EARLYPUBNUM'

        if [[ $2 == '-y' || $2 == '-Y' ]]
        then
            earliestPubMonth=0
            shift
        fi

        shift
        ;;

    -I)
        IPCparser='eval fieldParser IPCcount IPCNUM'

        if [[ $2 == '-x' || $2 == '-X' ]]
        then
            IPCdissagregate=0
            shift
        fi

        shift
        ;;

    -C)
        CPCparser='eval fieldParser CPCcount CPCNUM'

        if [[ $2 == '-x' || $2 == '-X' ]]
        then
            CPCdissagregate=0
            shift
        fi

        shift
        ;;

    -x | -X | -y | -Y)

        echo "An $1 option has been read from the arguments. This should not happen. Please take a screenshot of what you were doing and send it to the developer."
        shift
        ;;

    --help)

        usage
        exit 0
        ;;

    --version)

        version
        exit 0
        ;;


    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;

    *) echo "Unexpected option: $1 - this should not happen. Throw away!"
       exit 2

    esac
done
}

# Function to parse fields
function fieldParser
{   #First argument: the array for this piece of data, without $. Second: The associated field number

    declare -n arrayPointer="$1" # -n declares a reference, ie. a sort of pointer
    local -ir FIELDNUM=$2
    local checkString # The entire field we are concerned with.
    local word # Parts of that field, if disaggregated.
    local indexEntry="$(sed -n 9p < "$CSVfileName" | cut -f$FIELDNUM --delimiter=\;)" # This helps eliminate the explanatory line in each file. Unset at the end.

    # Some fields require specific instructions, same for disaggregation, this CASE structure assigns them to a variable that is expanded (or not) at runtime.

    case $FIELDNUM in
        $TITLENUM)
            # For proper comparisons, caps have to be removed from the titles. Plus the title ends with a period sometimes
            indexEntry="${indexEntry,,}"
            local fieldSpecificInstruction='eval checkString=$(tr -d [:punct:] <<< "${checkString,,}")' #punctuation and caps elimination

            if [[ -n $titleDisaggregate ]]
            then
                local disaggregationInstruction='eval checkString=($checkString)'
            fi


            ;;

        $INVENTORNUM)

            local fieldSpecificInstruction='eval tr -d [:punct:] <<< "$checkString" 1> /dev/null' # Output is redirected to the void.

            # to get the name and country later on of the inventors we place a semicolon after the [country code]. This won't be perfect, since some names aren't separated like that, or at all, but it's the best I can come up with.

            if [[ -n $inventorDisaggregate ]]
            then
                local disaggregationInstruction='eval checkString="$(sed -e "s_\(\[..\]\) _\1:_g" <<< "$checkString" )" ;readarray -d : -t checkString <<< "$checkString" 1> /dev/null'
# -e "s/$/ :/"   What was this part of the sed for? What was I thinking?
            fi

            ;;

        $APPLICANTNUM)

            local fieldSpecificInstruction='eval tr -d [:punct:] <<< "$checkString" 1>/dev/null '

            if [[ -n $applicantDisaggregate ]] # The : gives us a reference to later split the names more easily.
            then
                local disaggregationInstruction='eval checkString="$(sed -e "s_\(\[..\]\) _\1:_g" <<< "$checkString" )" ;readarray -d : -t checkString <<< "$checkString" '
            fi

            ;;


        $PRIORITYNUM)

            local fieldSpecificInstruction='eval checkString=$(sed "s_\([[:digit:]]\{4\}-[[:digit:]]\{2\}\)-.._\1_g" <<< $checkString)'
            # The above sed eliminates the day from the string, leaving only month and year
            # The one below eliminates the month.
            if [[ -n $priorityMonth ]]
            then
                local disaggregationInstruction='eval checkString=$(sed "s_\([[:digit:]]\{4\}\)-.._\1_g" <<< $checkString)'
            fi

            ;;

        $IPCNUM)

            if [[ -n $IPCdissagregate ]]
            then
                local disaggregationInstruction='eval checkString=($checkString)'
            fi

            ;;

        $CPCNUM)

            # no field specific instruction

            if [[ -n $CPCdissagregate ]]
            then
            # This instruction is similar to the one in the inventor section, it introduces a semicolon
                local disaggregationInstruction='eval checkString="$(sed -e "s_\()\)_\1:_g" -e "s_: _:_g" <<< "$checkString" )" ;readarray -d : -t checkString <<< "$checkString"'
            fi

            ;;

        $PUBLIDATENUM)

            local fieldSpecificInstruction='eval checkString=$(sed "s_\([[:digit:]]\{4\}-[[:digit:]]\{2\}\)-.._\1_g" <<< $checkString)'
            # The above sed eliminates the day from the string, leaving only month and year
            # The one below eliminates the month.

            if [[ -n $publicationMonth ]]
            then
                local disaggregationInstruction='eval checkString=$(sed "s_\([[:digit:]]\{4\}\)-.._\1_g" <<< $checkString)'
            fi

            ;;

        $EARLYPUBNUM)

            local fieldSpecificInstruction='eval checkString=$(sed "s_\([[:digit:]]\{4\}-[[:digit:]]\{2\}\)-.._\1_g" <<< $checkString)'
            # The above sed eliminates the day from the string, leaving only month and year
            # The one below eliminates the month.

            if [[ -n $earliestPubMonth ]]
            then
                local disaggregationInstruction='eval checkString=$(sed "s_\([[:digit:]]\{4\}\)-.._\1_g" <<< $checkString)'
            fi

            ;;

        *)
            echoerr "\n\nCritical error in the field specific instruction selector $1. Aborting.\nHow did that even happen?\nWarn the developer.\n"
            exit 126

            esac
                                                    # XXXXXXXXXXXXXXXXX
                                                    # Parsing starts here
                                                    # XXXXXXXXXXXXXXXXX
    while read 'entry'
        do
            # Entry is an entire line from the input file, that is, an entire patent's information.
            checkString=$(cut -f$FIELDNUM --delimiter=\; <<< "$entry") # This extracts the CSV field

            ${fieldSpecificInstruction[@]} # This expands depending on the field. Check the CASE structure above.

            ${disaggregationInstruction[@]} # This expands if disaggregation has been requested.
            #This makes the string into an array, so it can be dissaggregated. Expand if dissagreggated.
            #The FOR below will treat the string as one single element if this is not expanded, and as an array if it is.

            for word in "${checkString[@]}"
            do

                if [[ -z $word ]] #Empty entries are useless so we don't consider them
                then
        	        continue

                elif [[ -z ${arrayPointer[$word]} ]]
                then
                    (( arrayPointer[$word]=1 )) # If a term hasn't appeared yet, it's added to the hash table and keyed to one.

                else

                   (( arrayPointer[$word]++ )) # The entry is incremented (or =1 if it was null). Careful with the ${}! It's necessary for the array name to expand
                fi

            done

        done < "$CSVfileName" # This is specificied in the WHILE loop around this function.

        unset ${arrayPointer/word/indexEntry} # This eliminates the line 8 entry, which contains the field name of each csv.
        # The above doesn't work in all disaggregated cases! Will have to be improved.
}

function longestArray
{
    # This function finds the length of the longest array. It might also be the most inelegant code I have ever written.
    if [[ -n ${titleKeys} && (( ${#titleKeys[@]} > $maxLength )) ]]
    then
        maxLength=${#titleKeys[@]}
    fi

    if [[ -n ${inventorKeys} && (( ${#inventorKeys[@]} > $maxLength )) ]]
    then
        maxLength=${#inventorKeys[@]}
    fi

    if [[ -n ${applicantKeys} && (( ${#applicantKeys[@]} > $maxLength )) ]]
    then
        maxLength=${#applicantKeys[@]}
    fi

    if [[ -n ${dateKeys} && (( ${#dateKeys[@]} > $maxLength )) ]]
    then
        maxLength=${#dateKeys[@]}
    fi

    if [[ -n ${priorityKeys} && (( ${#priorityKeys[@]} > $maxLength )) ]]
    then
        maxLength=${#priorityKeys[@]}
    fi

    if [[ -n ${earliestPubKeys} && (( ${#earliestPubKeys[@]} > $maxLength )) ]]
    then
        maxLength=${#earliestPubKeys[@]}
    fi

    if [[ -n ${IPCkeys} && (( ${#IPCkeys[@]} > $maxLength )) ]]
    then
        maxLength=${#IPCkeys[@]}
    fi

    if [[ -n ${CPCkeys} && (( ${#CPCkeys[@]} > $maxLength )) ]]
    then
        maxLength=${#CPCkeys[@]}
    fi
}


function resultsFileWriter
{
    declare -ar titleKeys=("${!titleCount[@]}") # Thanks to these we get indexed arrays of the keys of the *existing* associative arrays
    declare -ar inventorKeys=("${!inventorCount[@]}")
    declare -ar applicantKeys=("${!applicantCount[@]}")
    declare -ar dateKeys=("${!publiDateCount[@]}")
    declare -ar priorityKeys=("${!priorityCount[@]}")
    declare -ar earliestPubKeys=("${!earliestPubCount[@]}")
    declare -ar IPCkeys=("${!IPCcount[@]}")
    declare -ar CPCkeys=("${!CPCcount[@]}")

    declare -i maxLength=0
    longestArray # Finds the length of the longest array.

    resultsFile="ParsedEPOresults$$.csv" # The name contains the process number. For randomization.
    touch  "$resultsFile"

    {   # This entire block of code has output redirected to the results file XXXXXXXX

        printf "\"Results file created on\";\"%s\";;;;\n" "$(date)" # The first line is the date

        for header in "${headerSpace[@]}" # First we put up the headers in the results file
        do
            printf "\"%s\";;;;;;\n" "$header"
        done

        printf ";;;;;;;;;;;\n" # An empty space for clarity

        # This prints the field headers
        local outPutString='"Titles";"Title count";"Inventors";"Inventor count";"Applicants";"Applicant count";"Publication date";"dates";"First priority";"dates";"Earliest Publication";"dates";"IPC numbers";"IPC count";"CPC numbers";"CPC count";'

        printf "%s\n;;;\n" "$outPutString"  # Space between searches and results


        for (( writeCounter=0 ; writeCounter < maxLength ; writeCounter++ ))
        do
            # If the counter reaches an empty key, it returns an impossible value. That returns an empty array.
            # The reason is that you can ask to print an empty index (it's just empty) but you cannot feed an empty string to an index (between the square brackets).
            printf "\"%s\";%s;" "${titleKeys[$writeCounter]}"       ${titleCount[${titleKeys[$writeCounter]:-'impossible_key^^^'}]}
            printf "\"%s\";%s;" "${inventorKeys[$writeCounter]}"    ${inventorCount[${inventorKeys[$writeCounter]:-'impossible_key-_-'}]}
            printf "\"%s\";%s;" "${applicantKeys[$writeCounter]}"   ${applicantCount[${applicantKeys[$writeCounter]:-'impossible_key^^^'}]}
            printf "\"%s\";%s;" "${dateKeys[$writeCounter]}"        ${publiDateCount[${dateKeys[$writeCounter]:-'impossible_key^^^'}]}
            printf "\"%s\";%s;" "${priorityKeys[$writeCounter]}"    ${priorityCount[${priorityKeys[$writeCounter]:-'impossible_key^^^'}]}
            printf "\"%s\";%s;" "${earliestPubKeys[$writeCounter]}" ${earliestPubCount[${earliestPubKeys[$writeCounter]:-'impossible_key^^^'}]}
            printf "\"%s\";%s;" "${IPCkeys[$writeCounter]}"         ${IPCcount[${IPCkeys[$writeCounter]:-'impossible_key^^^'}]}
            printf "\"%s\";%s;" "${CPCkeys[$writeCounter]}"         ${CPCcount[${CPCkeys[$writeCounter]:-'impossible_key^^^'}]}
            printf "\n"

        done
    } >> "$resultsFile" # resultsFile block of code ends here XXXXXXXXXXX
}

function cleanup
{

    if [[ -z $leaveUnixedFiles ]]
    then
        while read 'fileName'
        do
            rm "$fileName"
        done < unixedList.temp
    fi

    rm unixedList.temp
}



# XXXX Main XXXX

initFileCount # We check that there are Espacenet files

win2unix # We transform them to the easy-to-parse format

argParser "$@" # We parse the script arguments. It uses the script's arguments, but they need to be passed on explicitely

trap cleanup EXIT SIGHUP # Only after this step does the cleanup function become relevant. Before, the unixed files haven't been created. This activates at EXIT and SIGnal Hung UP

declare -a headerSpace # Array of the file headers
declare -i fileCount=0

while read "CSVfileName"
do

    headerSpace[$fileCount]=$(sed -n '4p' "$CSVfileName") # This records what searches were executed to get to the files that were parsed.
    headerSpace[$fileCount]=$(tr -d \; <<< "${headerSpace[$fileCount]}") # This takes the many semicolons out of the headers

    # Any option that isn't activated will simply expand to nothing
    ${titleParser[@]}
    ${inventorParser[@]}
    ${applicantParser[@]}
    ${dateParser[@]}
    ${priorityParser[@]}
    ${earliestPubParser[@]}
    ${IPCparser[@]}
    ${CPCparser[@]}

    (( fileCount++ ))

done < unixedList.temp

resultsFileWriter

exit 0
