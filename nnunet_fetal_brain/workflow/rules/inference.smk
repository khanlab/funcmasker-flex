
localrules: download_model

rule download_model:
    params: 
        url = config['download_model'][model]['url']
    output: os.path.join('resources',config['download_model'][model]['tar'])
    shell: 'pushd resources && wget {params.url}'

rule extract_model:
    input: os.path.join('resources',config['download_model'][model]['tar'])
    output: 
        models = expand(os.path.join('resources','trained_models',config['download_model'][model]['out']),fold=range(5)),
    shell: 'mkdir -p resources/trained_model && tar -C resources/trained_models -xvf {input}'



rule split:
    input: config['input_path']['bold']
    output: 
        split_dir = directory(bids(root='results', datatype='func',
                  desc='split', suffix='bold',
                  **config['input_wildcards']['bold']))
    container: '/project/6050199/akhanf/singularity/bids-apps/khanlab_neuroglia-core_latest.sif'
    group: 'subj'
    shell: 'mkdir -p {output} && fslsplit {input}  {output}/vol_'


rule conform:
    input: 
        nii_dir = bids(root='results', datatype='func',
                  desc='split', suffix='bold',
                  **config['input_wildcards']['bold'])
    params:
        resample_mm = '3.5x3.5x3.5mm',
        pad_to = '96x96x37',
    output: 
        nii_dir = directory(bids(root='results', datatype='func',
                  desc='conform', suffix='bold',
                  **config['input_wildcards']['bold']))
 
    container: '/project/6050199/akhanf/singularity/bids-apps/khanlab_autotop_deps_v0.4.1.sif'
    group: 'subj'
    shell: 'mkdir -p {output} && '
            'for in_nii in `ls {input}/*.nii.gz`; do '
            ' filename=${{in_nii##*/}} && '
            ' prefix=${{filename%%.nii.gz}} &&'
            ' out_nii={output}/${{prefix}}_0000.nii.gz && ' #always append _0000.nii.gz for nnunet
            ' c3d $in_nii -resample-mm {params.resample_mm} -pad-to {params.pad_to} 0 $out_nii;' 
            'done'





rule run_inference:
    input:
        nii_dir = bids(root='results', datatype='func',
                  desc='conform', suffix='bold',
                  **config['input_wildcards']['bold']),
        model_tar = os.path.join('resources',config['download_model'][model]['tar'])
    output:
        nii_dir = directory(
                    bids(root='results', datatype='func',
                        desc='brain', suffix='mask',
                        **config['input_wildcards']['bold']))
    threads: 8
    resources:
        gpus = 1,
        mem_mb = 32000,
        time = 60,
        dataaugment_threads = 4,
    group: 'subj'
    shadow: 'minimal'
    params:
        temp_img = 'tempimg/temp_0000.nii.gz',
        temp_lbl = 'templbl/temp.nii.gz',
        model_dir = 'tempmodel',
        in_folder = 'tempimg',
        out_folder = 'templbl',
        dataaugment_threads = 4,
        chkpnt = config['download_model'][model]['checkpoint'],
        unettask = config['download_model'][model]['unettask'],
    container: '/project/6050199/akhanf/singularity/bids-apps/khanlab_hippunfold_v0.5.1.sif'
    shell: 'mkdir -p {params.model_dir} {params.in_folder} {params.out_folder} {output.nii_dir} && ' #create temp folders
           'cp -v {input.nii_dir}/*.nii.gz {params.in_folder} && ' #cp input image to temp folder
           'tar -xvf {input.model_tar} -C {params.model_dir} && ' #extract model
           'export RESULTS_FOLDER={params.model_dir} && ' #set nnunet env var to point to model
           'export nnUNet_n_proc_DA={resources.dataaugment_threads} && ' #set threads
           'nnUNet_predict -i {params.in_folder} -o {params.out_folder} '
           ' -t {params.unettask} -chk {params.chkpnt} && ' # run inference
           'cp -v {params.out_folder}/*.nii.gz {output.nii_dir}' #copy from temp output folder to final output



rule merge_mask:
    input:
        nii_dir = bids(root='results', datatype='func',
                  desc='brain', suffix='mask',
                  **config['input_wildcards']['bold'])
    output:
        nii = bids(root='results', datatype='func',
                  desc='conform', suffix='mask.nii.gz',
                  **config['input_wildcards']['bold'])
    group: 'subj'
    log: bids(root='logs',**config['input_wildcards']['bold'],suffix='merge.txt')
    container: '/project/6050199/akhanf/singularity/bids-apps/khanlab_neuroglia-core_latest.sif'
    shell: 
        'fslmerge -t {output} {input}/*.nii.gz'

rule unconform:
    """ unconform by resampling mask to the input nifti space"""
    input:
        ref = config['input_path']['bold'],
        mask = bids(root='results', datatype='func',
                  desc='conform', suffix='mask.nii.gz',
                  **config['input_wildcards']['bold'])
    output:
        mask = bids(root='results', datatype='func',
                  desc='brain', suffix='mask.nii.gz',
                  **config['input_wildcards']['bold'])
    shell:
        'c4d -int NearestNeighbor {input.ref} {input.mask} -reslice-identity -o {output.mask}'


