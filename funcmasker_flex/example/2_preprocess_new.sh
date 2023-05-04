#!/bin/bash

######### Before running this, use 3drotate to put both the anatomical and the EPI in cardinal orientation. Add "desc-rotate" to the end of the func filename
###### Also before running this, run it through ANTs moco
##### Super important: make sure L/R is correct in both anat and functional!!
##### Also super important: make sure both anat and first volume of functional have correct orientation labels!!

# To run, you should have a file called ${subjid}_${scan}_${task}_desc-ANTSMoCo.nii.gz in $directory_path/ANTs_moco/${subjid}/${scan}/func/ and a file called ${sub}_${scan}_T2w.nii.gz in ${scan}/anat/

pattern="*_desc-ANTSMoCo.nii.gz"
directory_path=/Volumes/Drobo/Emily-Data/FIND_Nifti/derivatives
mkdir ${directory_path}/preprocessed

cd ${directory_path}/ANTS_moco2

for sub in $(find . -name $pattern)
do 
		subjid=`echo $sub | cut -d '/' -f2`
		scan=`echo $sub | cut -d '_' -f2`
		task=`echo $sub | cut -d '_' -f3`
		run=`echo $sub | cut -d '_' -f4`

cd ${directory_path}/ANTS_moco2

if [ -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-percent.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ ${sub} already preprocessed! ++++++++++++++++++++++++++++++++++++++++++" && continue
fi

if [ ! -f /Volumes/Drobo/Emily-Data/FIND_Nifti/${subjid}/${scan}/anat/${subjid}_${scan}_T2w.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ No anatomical for ${sub}! ++++++++++++++++++++++++++++++++++++++++++" && continue
fi

echo "++++++++++++++++++++++++++++++++++++++++++ Preprocessing ${sub} ++++++++++++++++++++++++++++++++++++++++++"

mkdir ${directory_path}/preprocessed/${subjid}/
mkdir ${directory_path}/preprocessed/${subjid}/${scan}/
mkdir ${directory_path}/preprocessed/${subjid}/${scan}/func/
mkdir ${directory_path}/preprocessed/${subjid}/${scan}/anat/

### delete the first two volumes
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-delvols.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ deleting first two volumes ++++++++++++++++++++++++++++++++++++++++++"
	fslsplit ${sub}
	rm vol0000.nii.gz
	rm vol0001.nii.gz
	fslmerge -t $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-delvols.nii.gz vol*
	rm vol*
fi


### put EPI in standard view
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-std.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ orienting EPI to standard view ++++++++++++++++++++++++++++++++++++++++++"
	fslreorient2std $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-delvols.nii.gz $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-std.nii.gz
fi

### de-oblique the EPI scan and anat
#if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_desc-do.nii.gz ];
#then
#	echo "++++++++++++++++++++++++++++++++++++++++++ De-obliquing EPI and anat ++++++++++++++++++++++++++++++++++++++++++"
#	3dWarp -deoblique -prefix $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-do.nii.gz $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-std.nii.gz
#fi

#if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-do.nii.gz ];
#then
#    3dWarp -deoblique -prefix $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-do.nii.gz /Volumes/Drobo/Emily-Data/FIND_Nifti/${subjid}/${scan}/anat/${subjid}_${scan}_T2w.nii*
#fi

### slice-timing correction
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_desc-stc.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ Performing slice-timing correction ++++++++++++++++++++++++++++++++++++++++++"
	3dTshift -prefix $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-stc.nii.gz $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-std.nii.gz
fi

# run de-spiking
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-despiked.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ De-spiking EPI ++++++++++++++++++++++++++++++++++++++++++"
	3dDespike -prefix $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-despiked.nii.gz $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-stc.nii.gz
fi

### volume registration (motion correction)

# register each EPI volume to volume 0
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-vr.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ registering EPI volumes to volume 0 ++++++++++++++++++++++++++++++++++++++++++"
	3dvolreg -prefix $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-vr.nii.gz -base 0 -dfile $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-vr.out $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-despiked.nii.gz
fi

### Register anat to EPI 
# zero-pad the anat
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-zp.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ zero-padding the anatomical ++++++++++++++++++++++++++++++++++++++++++"
	3dZeropad -R 15 -L 15 -A 15 -P 15 -I 15 -S 15 -prefix $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-zp.nii.gz $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-do.nii.gz
fi

# then align the center of the anat to the EPI
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-aligned.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ aligning centers of EPI and anat ++++++++++++++++++++++++++++++++++++++++++"
	@Align_Centers -base $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-zp.nii.gz -dset $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-vr.nii.gz -prefix ${subjid}_${scan}_${task}_${run}_desc-aligned.nii.gz
fi

# resample the EPI to the anat
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-resampled.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ resampling EPI to anat ++++++++++++++++++++++++++++++++++++++++++"
	3dresample -master $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-zp.nii.gz -prefix $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-resampled.nii.gz -input $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-aligned.nii.gz
fi

# then register the anat to EPI
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-zp_al_to_${task}_${run}.nii.gz ];
then
cd $directory_path/preprocessed/${subjid}/${scan}/anat/ 
	echo "++++++++++++++++++++++++++++++++++++++++++ registering anatomical to EPI ++++++++++++++++++++++++++++++++++++++++++"
	align_epi_anat.py -anat2epi -anat ${subjid}_${scan}_T2w_desc-zp.nii.gz \
    	 -anat_has_skull no -suffix _al_to_${task}_${run}.nii.gz     \
    	 -epi $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-resampled.nii.gz -epi_base 0  \
    	 -epi_strip None                 \
    	 -giant_move                      \
    	 -cost lpc+nmi				\
    	 -tshift off
cd ${directory_path}/
fi
  

# then register the EPI-aligned anat to the template
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-zp_al_to_${task}_${run}-at.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ registering the EPI-aligned anatomical to the 36-week GA template ++++++++++++++++++++++++++++++++++++++++++"
	cd $directory_path/preprocessed/${subjid}/${scan}/anat/
	cp $directory_path/atlases/CRL_Fetal_Brain_Atlas_2017v2/STA36exp.nii.gz ./
	@auto_tlrc -base STA36exp.nii.gz -input ${subjid}_${scan}_T2w_desc-zp_al_to_${task}_${run}.nii.gz -no_ss -init_xform AUTO_CENTER -prefix ${subjid}_${scan}_T2w_desc-zp_al_to_${task}_${run}-at.nii.gz
rm STA36exp.nii.gz
cd ${directory_path}/
fi


### warp the EPI to template space using the transformed anatomical data
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-at.nii.gz ];
then
	echo "++++++++++++++++++++++++++++++++++++++++++ registering EPI to template ++++++++++++++++++++++++++++++++++++++++++"
	cd $directory_path/preprocessed/${subjid}/${scan}/func/
	@auto_tlrc -apar $directory_path/preprocessed/${subjid}/${scan}/anat/${subjid}_${scan}_T2w_desc-zp_al_to_${task}_${run}-at.nii.gz -input ${subjid}_${scan}_${task}_${run}_desc-resampled.nii.gz -prefix ${subjid}_${scan}_${task}_${run}_desc-at.nii.gz -dxyz 1
	cd $directory_path
fi
          
### smooth the functionals - decide on kernel
if [ ! -f $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-smoothed.nii.gz ];
then
echo "++++++++++++++++++++++++++++++++++++++++++ smoothing EPI to 5 mm ++++++++++++++++++++++++++++++++++++++++++"
3dmerge -1blur_fwhm 5.0 -doall -prefix $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-smoothed.nii.gz \
          $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-at.nii.gz 
fi
          
# calculate percent signal change
echo "++++++++++++++++++++++++++++++++++++++++++ calculating percent signal change ++++++++++++++++++++++++++++++++++++++++++"
minclip=$(3dClipLevel $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-smoothed.nii.gz)
3dTstat -prefix $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-mean-intensity $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-smoothed.nii.gz

3dcalc  -a  $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-smoothed.nii.gz -b $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-mean-intensity+orig \
       -expr "(a/b*100)*step(b-"${minclip}")" \
       -prefix $directory_path/preprocessed/${subjid}/${scan}/func/${subjid}_${scan}_${task}_${run}_desc-percent.nii.gz     
   
# move all intermediate files to subdirectory "intermediate_steps"    
#echo "cleaning up"  
#mv 4D_${sub}_${run}_percent.nii.gz keep.nii.gz
#mv 4D_${sub}_${run}_* ${run}_intermediate_steps
#mv mean_intensity* ${run}_intermediate_steps
#mv ${sub}_anat_${run}_zp* ${run}_intermediate_steps
#mv *${sub}_anat_reorient* ${run}_intermediate_steps
#mv keep.nii.gz 4D_${sub}_${run}_percent.nii.gz
#mv pre* ${run}_intermediate_steps


echo "++++++++++++++++++++++++++++++++++++++++++ " ${sub} " preprocessed! ++++++++++++++++++++++++++++++++++++++++++"

done