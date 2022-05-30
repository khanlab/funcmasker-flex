
localrules:
    download_model,


rule download_model:
    params:
        url=config["download_model"][model]["url"],
    output:
        os.path.join("resources", config["download_model"][model]["tar"]),
    shell:
        "pushd resources && wget {params.url}"


rule extract_model:
    input:
        rules.download_model.output,
    output:
        models=expand(
            os.path.join(
                "resources", "trained_models", config["download_model"][model]["out"]
            ),
            fold=range(5),
        ),
    shell:
        "mkdir -p resources/trained_model && tar -C resources/trained_models -xvf {input}"


rule split:
    input:
        config["input_path"]["bold"],
    output:
        split_dir=temp(
            directory(
                bids(
                    root="results",
                    datatype="func",
                    desc="split",
                    suffix="bold",
                    **config["input_wildcards"]["bold"]
                )
            )
        ),
    container:
        config["singularity"]["neuroglia"]
    group:
        "subj"
    shell:
        "mkdir -p {output} && fslsplit {input}  {output}/vol_"


rule conform:
    input:
        rules.split.output,
    params:
        resample_mm="3.5x3.5x3.5mm",
        pad_to="96x96x37",
    output:
        nii_dir=temp(
            directory(
                bids(
                    root="results",
                    datatype="func",
                    desc="conform",
                    suffix="bold",
                    **config["input_wildcards"]["bold"]
                )
            )
        ),
    container:
        config["singularity"]["neuroglia"]
    group:
        "subj"
    shell:
        "mkdir -p {output} && "
        "for in_nii in `ls {input}/*.nii.gz`; do "
        " filename=${{in_nii##*/}} && "
        " prefix=${{filename%%.nii.gz}} &&"
        " out_nii={output}/${{prefix}}_0000.nii.gz && "
        " c3d $in_nii -resample-mm {params.resample_mm} -pad-to {params.pad_to} 0 $out_nii;"
        "done"


rule run_inference:
    input:
        nii_dir=rules.conform.output,
        model_tar=rules.download_model.output,
    output:
        nii_dir=temp(
            directory(
                bids(
                    root="results",
                    datatype="func",
                    desc="brain",
                    suffix="mask",
                    **config["input_wildcards"]["bold"]
                )
            )
        ),
    threads: 8
    resources:
        gpus=1,
        mem_mb=32000,
        time=60,
        dataaugment_threads=4,
    group:
        "subj"
    shadow:
        "minimal"
    params:
        model_dir="tempmodel",
        in_folder="tempimg",
        out_folder="templbl",
        dataaugment_threads=4,
        chkpnt=config["download_model"][model]["checkpoint"],
        unettask=config["download_model"][model]["unettask"],
    shell:
        #create temp folders
        #cp input image to temp folder
        #extract model
        #set nnunet env var to point to model
        #set threads
        # run inference
        #copy from temp output folder to final output
        "mkdir -p {params.model_dir} {params.in_folder} {params.out_folder} {output.nii_dir} && "
        "cp -v {input.nii_dir}/*.nii.gz {params.in_folder} && "
        "tar -xvf {input.model_tar} -C {params.model_dir} && "
        "export RESULTS_FOLDER={params.model_dir} && "
        "export nnUNet_n_proc_DA={resources.dataaugment_threads} && "
        "nnUNet_predict -i {params.in_folder} -o {params.out_folder} "
        " -t {params.unettask} -chk {params.chkpnt} && "
        "cp -v {params.out_folder}/*.nii.gz {output.nii_dir}"


rule merge_mask:
    input:
        rules.run_inference.output,
    output:
        nii=temp(
            bids(
                root="results",
                datatype="func",
                desc="conform",
                suffix="mask.nii.gz",
                **config["input_wildcards"]["bold"]
            )
        ),
    group:
        "subj"
    log:
        bids(root="logs", **config["input_wildcards"]["bold"], suffix="merge.txt"),
    container:
        config["singularity"]["neuroglia"]
    shell:
        "fslmerge -t {output} {input}/*.nii.gz"


rule unconform:
    """ unconform by resampling mask to the input nifti space"""
    input:
        ref=config["input_path"]["bold"],
        mask=rules.merge_mask.output,
    output:
        mask=bids(
            root="results",
            datatype="func",
            desc="brain",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    container:
        config["singularity"]["neuroglia"]
    group:
        "subj"
    shell:
        "reg_resample -NN 0 -ref {input.ref} -flo {input.mask} -res {output.mask}"


#        "antsApplyTransforms -d 3 -e 3 -n NearestNeighbor -r  {input.ref} -i {input.mask} -o {output.mask}"
