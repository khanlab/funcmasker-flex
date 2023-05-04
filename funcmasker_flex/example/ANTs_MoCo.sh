#!/bin/bash
# SLURM submission script for multiple serial jobs on Graham
#
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --time=12:00:00
#SBATCH --job-name=ANTs_MoCo
#SBATCH --account=def-eduerden
module load gcc/9.3.0
module load StdEnv/2020
module load vtk/9.0.1
module load ants/2.3.5

method_sufix=ANTsMoCo
directory_path=$SCRATCH/FIND_Nifti/
pattern="*masked_bold.nii.gz"

cd ${directory_path}

for sbj in $(find . -name $pattern)
do 
		subjid=`echo $sbj | cut -d '/' -f2`
		subj=`echo $subjid | cut -d '_' -f1`
		scan=`echo $sbj | cut -d '_' -f2`
		task=`echo $sbj | cut -d '_' -f3`
		run=`echo $sbj | cut -d '_' -f4`

if [ -f $directory_path/${subjid}/${scan}/${subjid}_${scan}_${task}_desc-ANTSMoCo.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ ${subjid} ${scan} ${task} ${run} already registered! ++++++++++++++++++++++++++++++++++++++++++" && continue
fi

# create an average of the first 10 volumes
		echo Performing motion correction on ${subjid}_${scan}_${run}  
		out=$directory_path/${subjid}/${scan}/${subjid}_${scan}_${task}_${run}_desc-ANTSMoCo
		antsMotionCorr -d 3 -a ${sbj} -o ${out}_avg.nii.gz
		
# apply transformation matrix to the atlas mask
		antsMotionCorr  -d 3 -o [${out},${out}.nii.gz,${out}_avg.nii.gz] -m gc[ ${out}_avg.nii.gz , ${sbj} , 1 , 1 , Random, 0.05  ] -t Affine[ 0.005 ] -i 20 -u 1 -e 1 -s 0 -f 1  -m CC[  ${out}_avg.nii.gz , ${sbj} , 1 , 2 ] -t GaussianDisplacementField[0.15,3,0.5] -i 20 -u 1 -e 1 -s 0 -f 1 -n 10


done
