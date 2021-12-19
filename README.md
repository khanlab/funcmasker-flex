# funcmasker-flex

Brain masking app using Unet for fetal bold mri


### Example usage:

Get a sample subject dataset:

    datalad install https://github.com/OpenNeuroDatasets/ds003090.git
    cd ds003090/
    datalad get sub-2225
    cd ../

Run `funcmasker-flex` on it:
    
    singularity run -e docker://khanlab/funcmasker-flex:latest  ds003090/ funcmasker participant --participant_label 2225 --cores all

