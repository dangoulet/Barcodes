## Pipeline for Barcode Processing on Luria Compute Cluster ##
Dan Goulet Hemann Lab MIT 2021

This readme file outlines the basic steps for the processing and quantitation of the barcode libraries using for single-cell tracking in the Hemann lab.

Basic workflow:
1) Find a consensus sequence from 150-cycle 75 bp paired-end sequencing run using Pear
2) Extract sequence from Pear output
3) Filter reads containing universal linker, which selects only reads containing barcodes
4) Delete linker and stitch barcode sequences to create single 44 bp barcode
5) Quantify barcodes using bartender to reduce sequencing error

## Find Consensus Sequence from Paired-End Reads ##
pear -f $fwd_read -r $rev_read -v 65 -j 8 -y 64G -o ./pear/${pear_outfile} identifies the duplex from paired end reads and creates a consensus sequence
-v 65 requires a minimum length of 65 bp in the paired-end duplex
-j 8 requires 8 cores
-y 64G requires 64GB of memory

## Extract Sequence from Pear Output ##
awk '(NR%4==2)' outputs the second line containing the DNA sequence from the fastq file output by Pear

## Filter Reads Containing Universal Linker ##
egrep 'TGCTCAGGTAGCCTCACCTCC' selects only reads containing the universal linker sequence and outputs to a new files

## Filter Reads Containing Universal Linker ##
sed "s/TGCTCAGGTAGCCTCACCTCC//g" $filtered_seq deletes the linker sequence and stitches barcode to create single 44 bp barcode
awk -F "," 'BEGIN { OFS = "," } ; {print $1 OFS NR}' reformats the output to csv for input into bartender

## Record Metrics of Sample Processing ##
printf command generates a textfile with the indicated headers
bc command calculates the percent reads from the read counts of input files

## Quantify Barcode Abundance and Eliminate Sequencing Error ##
bartender_single_com -c 10 -t 8 -f $barcodes -o $counts uses the bartender package to quantify barcode abundance and cluster spurious barcodes with their likely parents
-c 10 requires a minimum of 10 counts in any barcode cluster
-t 8 requires 8 cores 
