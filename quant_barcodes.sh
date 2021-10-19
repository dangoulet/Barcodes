#!/bin/bash
#SBATCH -N 1
#SBATCH -n 8
#SBATCH -t 72:00:00
#SBATCH --mem=64g
#SBATCH --mail-type=end
#SBATCH --mail-user=kerberos@mit.edu

module load pear
module load bartender

## Record Date of Processing ##
date=$(date +%y%m%d)

## Change Directory to Filepath of Parent Directory Containing Fastq Files ##
cd /home/dgoulet/data/Barcodes/210917Hem_Validation/

echo -e "### Move Fastq Files to Data Folder ###\n" > barcode_pipeline_${date}.log
## Move Fastq Files to Data Folder ##
mkdir ./data
for fastq in $(find ./ -type f -name "*sequence.fastq")
do
mv $fastq ./data
echo "mv $fastq ./data" >> barcode_pipeline_${date}.log
done

echo -e "\n\n### Run Pear to Resolve Sequencing Errors in Paired-End Reads ###\n" >> barcode_pipeline_${date}.log
## Run Pear to Resolve Sequencing Errors in Paired-End Reads ##
mkdir ./pear
for fwd_read in ./data/*_1_sequence.fastq
do
rev_read=$(echo $fwd_read | sed "s/_1_sequence.fastq/_2_sequence.fastq/")
pear_outfile=$(echo $fwd_read | sed "s/.\/data\///" | sed "s/_1_sequence.fastq//")
pear -f $fwd_read -r $rev_read -v 65 -j 8 -y 64G -o ./pear/${pear_outfile}
echo "pear -f $fwd_read -r $rev_read -v 65 -j 8 -y 64G -o ./pear/${pear_outfile}" >> barcode_pipeline_${date}.log
done

cd ./pear
echo -e "\n\n### Extract Sequence from Pear Output Fastq ###\n" >> ../barcode_pipeline_${date}.log
## Extract Sequence from Pear Output Fastq ##
for pear_outfile in *.assembled.fastq
do
pear_seq=$(echo $pear_outfile | sed "s/.assembled.fastq/_seq.txt/")
awk '(NR%4==2)' $pear_outfile > $pear_seq
echo "awk '(NR%4==2)' $pear_outfile > $pear_seq" >> ../barcode_pipeline_${date}.log
done

echo -e "\n\n### Filter Reads With Ends Matching Universal Priming Sequences ###\n" >> ../barcode_pipeline_${date}.log
## Filter Reads With Ends Matching Universal Priming Sequences ##
for pear_seq in *_seq.txt
do
filtered_seq=$(echo $pear_seq | sed "s/_seq.txt/_filt_seq.txt/")
egrep 'TGCTCAGGTAGCCTCACCTCC' $pear_seq > $filtered_seq
echo "egrep 'TGCTCAGGTAGCCTCACCTCC' $pear_seq > $filtered_seq" >> ../barcode_pipeline_${date}.log
done

echo -e "\n\n### Extract Barcode Sequences and Reformat ###\n" >> ../barcode_pipeline_${date}.log
## Filter Reads With Ends Matching Universal Priming Sequences ##
for filtered_seq in *_filt_seq.txt
do
barcode=$(echo $filtered_seq | sed "s/_filt_seq.txt//")
sed "s/TGCTCAGGTAGCCTCACCTCC//g" $filtered_seq | awk -F "," 'BEGIN { OFS = "," } ; {print $1 OFS NR}' > ${barcode}.csv
echo "sed "s/TGCTCAGGTAGCCTCACCTCC//g" $filtered_seq |\
 awk -F "," 'BEGIN { OFS = "," } ; {print $1 OFS NR}' > ${barcode}.csv" >> ../barcode_pipeline_${date}.log
done

mkdir ../counts
cd ../counts
## Calculate Processing Metrics and Write to File ##
printf "Sequencing_ID\tInput_Reads\tPear_Output_Reads\tFiltered_Reads\tPercent_Pear_Output\tPercent_Filtered_Output\n" > ./metrics.txt
for filtered_seq in ../pear/*_filt_seq.txt
do
infile=$(echo $filtered_seq | sed "s/_filt_seq.txt/_1_sequence.fastq/" | sed "s/pear/data/")
pear_outfile=$(echo $filtered_seq | sed "s/_filt_seq.txt/.assembled.fastq/")
pear_seq=$(echo $filtered_seq | sed "s/_filt_seq.txt/_seq.txt/")
sample=$(echo $filtered_seq | sed "s/_filt_seq.txt//" | sed "s/..\/pear\///")
in_count=$(echo "$(cat $infile | wc -l) / 4" | bc)
pear_outcount=$(echo "$(cat $pear_outfile | wc -l) / 4" | bc)
filt_count=$(echo "$(cat $pear_seq | wc -l)")
percent_pearout=$(printf "%.2f\n" $(echo "scale=12; $pear_outcount / $in_count * 100" | bc))
percent_filtout=$(printf "%.2f\n" $(echo "scale=12; $filt_count / $in_count * 100" | bc))
echo -e "$sample\t$in_count\t$pear_outcount\t$filt_count\t$percent_pearout\t$percent_filtout" >> ./metrics.txt
done

for barcodes in ../pear/*.csv
do
counts=$(echo $barcodes | sed "s/pear/counts/")
bartender_single_com -c 10 -t 8 -f $barcodes -o $counts
echo -e "bartender_single_com -c 10 -t 8 -f $barcodes -o $counts" >> ../barcode_pipeline_${date}.log
done
