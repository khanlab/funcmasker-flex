#!/bin/bash

# apply masks to EPI data

path=/Volumes/Drobo/Emily-Data/FIND_Nifti

cd ${path}/derivatives/funcmasker-flex/results

for sub in sub*
do
cd ${path}/derivatives/funcmasker-flex/results/${sub}

for ses in 1 2
do

# check if that session exists for this subject
if [ ! -d ses-${ses}/ ];
then
    echo ses-${ses}" not found!" && continue
fi

for task in rest singing
do

for run in 01 02 03
do

# check if that run exists for this subject
if [ ! -f ses-${ses}/func/${sub}_ses-${ses}_task-${task}_run-${run}_desc-brain_mask.nii* ];
then
    echo ${sub}_ses-${ses}_task-${task}_run-${run}_desc-brain_mask.nii" not found!" && continue
fi

if [ -f ses-${ses}/func/${sub}_ses-${ses}_task-${task}_run-${run}_desc-masked_bold.nii.gz ];
then
    echo ${sub}_ses-${ses}_task-${task}_run-${run}_bold.nii" already masked!" && continue
fi

echo ses-${ses}/func/${sub}_ses-${ses}_task-${task}_run-${run}_bold.nii" exists!"

### use the mask to segment the brain in each EPI volume
# first split the 4D mask into individual volumes
cd ses-${ses}/func/
fslsplit ${sub}_ses-${ses}_task-${task}_run-${run}_desc-brain_mask.nii* ./mask_vol

# then split the EPI into individual volumes
fslsplit ${path}/${sub}/ses-${ses}/func/${sub}_ses-${ses}_task-${task}_run-${run}_bold.nii* ./vol

# apply each mask volume to the corresponding EPI volume
for file in vol*
do
3dcalc -a ${file} -b mask_${file} -expr 'a*bool(b)' -prefix masked_${file}
done


# put the EPI volumes back into a single 4D file
fslmerge -t ${sub}_ses-${ses}_task-${task}_run-${run}_desc-masked_bold.nii.gz masked_vol*

# remove the individual volume files
rm vol*
rm mask_vol*
rm masked_vol*


cd ../..

done
done
done
done