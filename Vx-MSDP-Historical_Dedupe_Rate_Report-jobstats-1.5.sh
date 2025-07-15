#!/bin/bash
# 
# Veritas - MSDP - Historical Dedupe Rate Report - v1.5
#
# 2024-11-14 - v1.5 - Bobby Hamilton
# 2024-10-17 - v1.4 - Bobby Hamilton
# 2024-09-18 - v1.3 - Bobby Hamilton
# 2024-03-19 - v1.2 - Bobby Hamilton
# 2023-03-03 - v1.1 - Bobby Hamilton
# 2022-12-16 - v1.0 - Bobby Hamilton
#

# Variables
p0=$(printf '=%.0s' {0..130}); p1=$(printf '=%.0s' {0..100}); p2=$(printf '=%.0s' {0..76}); p3=$(printf '=%.0s' {0..46}); p4=$(printf '=%.0s' {0..28}); p5=$(printf '=%.0s' {0..22});
filePrefix=$(date +%F)
outDir=$(pwd)

# Check
if [ -z ${1} ]; then
    echo -e "Error: Path to 'jobstats' not provided. Usage: ${0} /path/to/jobstats"
else
    jobstatsPath=${1}
fi

# Processing
var=1
msdpDedupeReport() {
    if [[ $var -eq 1 ]]; then
        echo -e "\n\n\n${p1}\nLHC - Processing - Report: MSDP - Historical Dedupe Rate Report\n${p1}"
        if [[ ! -d ${jobstatsPath} ]]; then
            echo -e "Error: The 'jobstats' directory does not exist at the specified path: ${jobstatsPath}"
        else
            # Initialization
            dedupeDir=${outDir}/${filePrefix}-MSDP-Storage-Historical_Dedupe_Rates-$(date +%s)
            dedupeFile=${dedupeDir}/MSDP
            mkdir ${dedupeDir}
            # Note: Common Code
            jobstatsFilesAll=$(timeout -s 9 10 ls -1tr ${jobstatsPath}/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
            # if [[ -n ${msdpHost} && ${msdpHost} -eq 1 ]]; then
                # MSDP - History - jobstats - collect
                # echo -e "${p2}\nCollect Files\n${p2}"
                # echo -e "Collecting Files... Timeout: 2 minutes"
                # timeout -s 9 120 tar czf ${dedupeDir}/${filePrefix}-MSDP-Dedupe_Rates-jobstats_files.tgz ${jobstatsFilesAll} 2>/dev/null
                # echo -e "Collecting Files... Done."
            # fi
            # MSDP - History - jobstats - combine
            echo -e "${p2}\nCombine Files\n${p2}"
            jobstatsCombined=${dedupeFile}-Dedupe_Rates-Combined
            for jobstatsFile in ${jobstatsFilesAll}; do
                fileType=$(timeout -s 9 10 file ${jobstatsFile} | awk '{print $2}')
                fileName=$(echo -e "${jobstatsFile}" | awk -F'/' '{print $NF}')
                echo -e "Processing: ${jobstatsFile}"
                if [[ -n ${fileType} && ${fileType} == "ASCII" || -n ${fileType} && ${fileType} == "CSV" ]]; then
                    jobstatsFiles+="${jobstatsFile} "
                    grep "policy=" ${jobstatsFile} 1>>${jobstatsCombined}
                else
                    echo -e "Error: Empty or not ASCII file: ${jobstatsFile}. Skipping." 1>>${dedupeDir}/${filePrefix}-MSDP-Dedupe_Rates-jobstats_files-error.txt
                fi
            done
            # MSDP - History - jobstats - parse
            echo -e "\n${p2}\nProcess Data - Dedupe Report\n${p2}"
            if [ -z "${jobstatsFiles}" ]; then
                echo -e "Error: No records present in 'jobstats' data files." | tee -a ${dedupeDir}/${filePrefix}-MSDP-Dedupe_Rates-jobstats_files-error.txt
            else
                # Processing
                echo -e "${p3}\nProcessing\n${p3}"
                echo -e "Processing: Normalization"
                grep "policy=UNKNOWN\|policy=UNKN" ${jobstatsCombined} 1>${jobstatsCombined}-addendum
                sed -i '/policy=UNKNOWN/d;/policy=UNKN/d' ${jobstatsCombined}
                sed -i 's/ new transferred data encrypted,//g;s/ new transferred data unencrypted,//g' ${jobstatsCombined}
                echo -e "Processing: Convert CTIME"
                awk -F"," -v OFS="," '{ $1=strftime("%Y-%m-%d,%H:%M:%S", $1); $2=""; print }' ${jobstatsCombined} 1>${jobstatsCombined}-date_convert
                echo -e "Processing: Update data fields"
                sed 's/\(image_name=\|dedup=\|compression_space_saving=\|dedupe_space_saving=\|backup_ksize=\|dsid=\|client=\|policy=\)//g;s/,,/,/g;s/ //g' ${jobstatsCombined}-date_convert 1>${jobstatsCombined}-csv
                echo -e "Processing: Calculate data written"
                awk -F',' '{OFS=","; OFMT="%.2f"; written=($7 * ((100 - $4) * .01)); if (written == int(written)) {written = written ".0";} print $0, $7, written, $7 / 1024000, written / 1024000}' ${jobstatsCombined}-csv 1>${jobstatsCombined}-csv-written
                echo -e "Processing: Sort by start time"
                echo -e "Date,Time,BackupID,Dedupe_Rate,Compression_Savings,Dedupe_Saings,Size,DSID,Client,Policy,Size_KB,Written_KB,Size_GB,Written_GB" 1>${jobstatsCombined}-Report
                cat ${jobstatsCombined}-csv-written 1>>${jobstatsCombined}-Report
                column -t ${jobstatsCombined}-Report 1>${jobstatsCombined}-Report-Sort_by_date.txt
                echo -e "Processing: Sort by data written"
                sort -nrk14 -t, ${jobstatsCombined}-csv-written 1>${jobstatsCombined}-csv-written-sort
                echo -e "Processing: Sort by data written - Column headers"
                echo -e "Date,Time,BackupID,Dedupe_Rate,Compression_Savings,Dedupe_Saings,Size,DSID,Client,Policy,Size_KB,Written_KB,Size_GB,Written_GB" 1>${jobstatsCombined}-Report
                cat ${jobstatsCombined}-csv-written-sort 1>>${jobstatsCombined}-Report
                column -t ${jobstatsCombined}-Report -s "," 1>${jobstatsCombined}-Report-Sort_by_size.txt
                # MSDP - History - jobstats - detail summary - processing
                mkdir ${dedupeDir}/client ${dedupeDir}/policy ${dedupeDir}/client_policy
                reportName=${jobstatsCombined}-Report-Sort_by_date.txt
                echo -e "Processing: Policy Names"
                awk -F',' '{print $10}' ${reportName} | sed '1d;s/[[:space:]]//g' | sort -u > ${dedupeDir}/policy_names
                echo -e "Processing: Client Names"
                awk -F',' '{print $9}' ${reportName} | sed '1d;s/[[:space:]]//g' | sort -u > ${dedupeDir}/client_names
                echo -e "Processing: Client+Policy Names"
                awk -F',' '{print $9, $10}' ${reportName} | sed '1d;s/ \+/ /g;s/^ //g' | sort -u > ${dedupeDir}/client_policy_names
                # Summaries
                echo -e "\n${p3}\nSummaries\n${p3}"
                # Policy Report
                echo -e "Processing: Policy Summary"
                while read policyName; do
                    awk -F',' -v policyName="${policyName}" '$10 == policyName' ${reportName} > ${dedupeDir}/policy/${policyName}
                    imageCount=$(awk '!/^[[:space:]]*$/ {c++} END {print c+0}' ${dedupeDir}/policy/${policyName})
                    awk -F',' -v CONVFMT='%2.2f' -v OFMT='%2.2f' -v imageCount=${imageCount} -v policyName=${policyName} '{
                        OFS=",";
                        sumSize+=$(NF-1);
                        sumWritten+=$NF;
                    }
                    END {
                        if (sumSize != 0) {
                            print policyName, imageCount, sumSize, sumWritten, 100 - sumWritten / sumSize * 100 "%\n";
                        } else {
                            print policyName, imageCount, 0, 0, 0"%\n";
                        }
                    }' ${dedupeDir}/policy/${policyName} >> ${dedupeFile}-Data_Written-Policy.csv
                done < ${dedupeDir}/policy_names
                sort -t "," -nrk3 ${dedupeFile}-Data_Written-Policy.csv > ${dedupeFile}-Data_Written-Policy-Sort.csv
                sed -i '1s/^/Policy,Total_Images,Total_GB,Written_GB,Dedupe\n/' ${dedupeFile}-Data_Written-Policy.csv
                sed -i '1s/^/Policy,Total_Images,Total_GB,Written_GB,Dedupe\n/' ${dedupeFile}-Data_Written-Policy-Sort.csv
                column -t ${dedupeFile}-Data_Written-Policy.csv -s "," > ${dedupeFile}-Data_Written-Policy.txt
                column -t ${dedupeFile}-Data_Written-Policy-Sort.csv -s "," > ${dedupeFile}-Data_Written-Policy-Sort.txt
                # Process Client
                echo -e "Processing: Client Summary"
                while read clientName; do
                    awk -F',' -v clientName="${clientName}" '$9 == clientName' ${reportName} > ${dedupeDir}/client/${clientName}
                    imageCount=$(awk '{c++} END {print (c ? c : 0)}' ${dedupeDir}/client/${clientName})
                    awk -F',' -v CONVFMT='%2.2f' -v OFMT='%2.2f' -v imageCount=${imageCount} -v clientName=${clientName} '{
                        OFS=",";
                        sumSize+=$(NF-1);
                        sumWritten+=$NF
                    }
                    END {
                        if (sumSize != 0) {
                            print clientName, imageCount, sumSize, sumWritten, 100 - sumWritten / sumSize * 100 "%\n";
                        } else {
                            print clientName, imageCount, 0, 0, 0"%\n";
                        }
                    }' ${dedupeDir}/client/${clientName} >> ${dedupeFile}-Data_Written-Client.csv
                done < ${dedupeDir}/client_names 
                sort -t "," -nrk3 ${dedupeFile}-Data_Written-Client.csv > ${dedupeFile}-Data_Written-Client-Sort.csv
                sed -i '1s/^/Client,Total_Images,Total_GB,Written_GB,Dedupe\n/' ${dedupeFile}-Data_Written-Client.csv
                sed -i '1s/^/Client,Total_Images,Total_GB,Written_GB,Dedupe\n/' ${dedupeFile}-Data_Written-Client-Sort.csv
                column -t ${dedupeFile}-Data_Written-Client.csv -s "," > ${dedupeFile}-Data_Written-Client.txt
                column -t ${dedupeFile}-Data_Written-Client-Sort.csv -s "," > ${dedupeFile}-Data_Written-Client-Sort.txt
                # Process Client/Policy
                echo -e "Processing: Client+Policy Summary"
                while read clientName policyName; do
                    awk -F',' -v clientName="${clientName}" -v policyName="${policyName}" '$9 == clientName && $10 == policyName' ${reportName} > ${dedupeDir}/client_policy/${policyName}_${clientName}
                    imageCount=$(awk '!/^[[:space:]]*$/ {c++} END {print c+0}' ${dedupeDir}/client_policy/${policyName}_${clientName})
                    awk -F',' -v CONVFMT='%2.2f' -v OFMT='%2.2f' -v imageCount=${imageCount} -v clientName=${clientName} -v policyName=${policyName} '{
                        OFS=",";
                        sumSize+=$(NF-1);
                        sumWritten+=$NF
                    }
                    END {
                        if (sumSize != 0) {
                            print clientName, policyName, imageCount, sumSize, sumWritten, 100 - sumWritten / sumSize * 100 "%\n";
                        } else {
                            print clientName, policyName, imageCount, 0, 0, 0"%\n";
                        }
                    }' ${dedupeDir}/client_policy/${policyName}_${clientName} >> ${dedupeFile}-Data_Written-Client_Policy.csv
                done < ${dedupeDir}/client_policy_names
                sort -t "," -nrk4 ${dedupeFile}-Data_Written-Client_Policy.csv > ${dedupeFile}-Data_Written-Client_Policy-Sort.csv
                sed -i '1s/^/Client,Policy,Total_Images,Total_GB,Written_GB,Dedupe\n/' ${dedupeFile}-Data_Written-Client_Policy.csv
                sed -i '1s/^/Client,Policy,Total_Images,Total_GB,Written_GB,Dedupe\n/' ${dedupeFile}-Data_Written-Client_Policy-Sort.csv
                column -t ${dedupeFile}-Data_Written-Client_Policy.csv -s "," > ${dedupeFile}-Data_Written-Client_Policy.txt
                column -t ${dedupeFile}-Data_Written-Client_Policy-Sort.csv -s "," > ${dedupeFile}-Data_Written-Client_Policy-Sort.txt
                # MSDP - History - jobstats - workload summary - processing
                echo -e "Processing: Summary - Jobs per policy"
                awk -F',' '{print $NF}' ${jobstatsCombined}-csv | sort | uniq -c | sort -nr 1>${jobstatsCombined}-Summary-Jobs_per_policy.txt
                echo -e "Processing: Summary - Jobs per client"
                awk -F',' '{print $(NF-1)}' ${jobstatsCombined}-csv | sort | uniq -c | sort -nr 1>${jobstatsCombined}-Summary-Jobs_per_client.txt
                echo -e "Processing: Summary - Jobs per client-policy"
                awk -F',' '{print $9, $10}' ${jobstatsCombined}-csv | sort | uniq -c | sort -nr | column -t 1>${jobstatsCombined}-Summary-Jobs_per_client-policy.txt
                # MSDP - History - jobstats - cleanup
                # cleanupFiles="${jobstatsCombined} ${jobstatsCombined}-date_convert ${jobstatsCombined}-csv ${jobstatsCombined}-csv-written ${jobstatsCombined}-Report"
                # for fileName in ${cleanupFiles}; do
                #     if [ -f ${fileName} ]; then
                #         rm ${fileName}
                #     fi
                # done
                echo -e "\n${p2}\nProcess Data - Image Size Distribution\n${p2}"
                echo -e "${p3}\nFETB - Front-End Terabytes\n${p3}"
                isdReport=${dedupeFile}-Image_Size_Distribution
                for jobstatsFile in ${jobstatsFiles}; do
                    echo -e "Processing: ${jobstatsFile}"
                    fileName=$(echo ${jobstatsFile} | awk -F'/' '{print $NF}')
                    total=$(awk 'NF{c++} END {print c+0}' ${jobstatsFile})
                    optDup=$(awk '/client=OPT-DUP/{c++} END {print c+0}' ${jobstatsFile})
                    optRep=$(awk '/PDVFS/ && !/UNKNOWN/{c++} END {print c+0}' ${jobstatsFile})
                    awk -F',' -v OFS=',' '{
                        gsub("backup_ksize=", "", $8);
                        ksize = $8 + 0;
                        if (ksize >= 0 && ksize <= 128) { range1++ }
                        else if (ksize > 128 && ksize <= 1024) { range2++ }
                        else if (ksize > 1024 && ksize <= 10240) { range3++ }
                        else if (ksize > 10240 && ksize <= 102400) { range4++ }
                        else if (ksize > 102400 && ksize <= 1024000) { range5++ }
                        else if (ksize > 1024000 && ksize <= 10240000) { range6++ }
                        else if (ksize > 10240000 && ksize <= 102400000) { range7++ }
                        else if (ksize > 102400000 && ksize <= 1024000000) { range8++ }
                        else if (ksize > 1024000000 && ksize <= 10240000000) { range9++ }
                        else if (ksize > 10240000000 && ksize <= 102400000000) { range10++ }
                    }
                    END {
                        print "'${fileName}'", "'${total}'", "'${optDup}'", "'${optRep}'", range1+0, range2+0, range3+0, range4+0, range5+0, range6+0, range7+0, range8+0, range9+0, range10+0
                    }' ${jobstatsFile} 1>>${isdReport}.csv
                done
                awk -F',' '{for (i=2; i<=NF; i++) sum[i] += $i} END {printf "Total"; for (i=2; i<=NF; i++) printf ",%d", sum[i]; print ""}' ${isdReport}.csv 1>>${isdReport}.csv
                sed -i '1s/^/Date,Total,OptDupe,OptRep,<128_kb,<1_mb,<10_mb,<100_mb,<1_gb,<10_gb,<100_gb,<1_tb,<10_tb,<100_tb\n/' ${isdReport}.csv
                column -t -s, ${isdReport}.csv 1>${isdReport}.txt
                # MSDP - History - jobstats - workload summary - report
                if [ -f ${jobstatsCombined}-Report-Sort_by_size.txt ]; then
                    echo -e "\n\n${p2}\nMSDP - Historical Dedupe Rate Report - Summary\n${p2}"
                    #echo -e "${p3}\nGlobal Dedupe Rate\n${p3}"
                    #echo -e "Key: Value\n"
                    # Jobs per Policy
                    echo -e "${p3}\nPolicy Summary - Top 30\n${p3}"
                    head -n 30 ${dedupeFile}-Data_Written-Policy-Sort.txt
                    # Jobs per Client
                    echo -e "\n${p3}\nClient Summary - Top 30\n${p3}"
                    head -n 30 ${dedupeFile}-Data_Written-Client-Sort.txt
                    # Jobs per Client / Policy
                    echo -e "\n${p3}\nClient+Policy Summary - Top 30\n${p3}"
                    head -n 30 ${dedupeFile}-Data_Written-Client_Policy-Sort.txt
                    # Storage Utilization
                    echo -e "\n${p3}\nStorage Utilization - Top 100\n${p3}"
                    jobstatsReport=$(echo -e "${jobstatsCombined}-Report-Sort_by_size.txt" | awk -F'/' '{print $NF}')
                    recordCount=$(awk '/./{c++} END {print c+0}' ${jobstatsCombined}-csv-written-sort)
                    echo -e "File: ${jobstatsReport}\nRecords: ${recordCount}\n${p3}"
                    head -n 100 ${jobstatsCombined}-Report-Sort_by_size.txt
                fi | tee ${jobstatsCombined}-Report-Summary.txt
                # MSDP - History - jobstats - image size distribution
                if [ -f ${isdReport}.txt ]; then
                    echo -e "\n${p1}\nMSDP - Image Size Distribution\n${p1}"
                    echo -e "${p3}\nFETB - Front-End Terabytes\n${p3}"
                    cat ${isdReport}.txt
                    echo -e "\n\n"
                fi
            fi
        fi
    fi
}
msdpDedupeReport