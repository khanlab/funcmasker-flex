
localrules:
    download_model,


# currently generates a mask on a 4d vol:
#  split
#  conform
#  apply_model
#  run_inference
#  unconform
#  merge

# to do:
# 1. mask the bold scan (after splitting, before conforming) - done
# 2. perform moco - done
#


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


rule import_bold:
    input:
        config["input_path"]["bold"],
    output:
        bids(
            root="results",
            datatype="func",
            desc="raw",
            suffix="bold.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    container:
        config["singularity"]["fsl"]
    group:
        "subj"
    shell:
        "cp {input} {output}"


rule split_bold:
    input:
        bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="bold.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    output:
        split_dir=temp(
            directory(
                bids(
                    root="results",
                    datatype="func",
                    desc="{desc}",
                    suffix="bold",
                    **config["input_wildcards"]["bold"]
                )
            )
        ),
    container:
        config["singularity"]["fsl"]
    group:
        "subj"
    shell:
        "mkdir -p {output} && fslsplit {input}  {output}/vol_"


rule conform:
    input:
        bids(
            root="results",
            datatype="func",
            desc="raw",
            suffix="bold",
            **config["input_wildcards"]["bold"]
        ),
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
        config["singularity"]["itksnap"]
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
        config["singularity"]["fsl"]
    shell:
        "fslmerge -t {output} {input}/*.nii.gz"


rule unconform_mask:
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


rule split_mask:
    input:
        mask_4d=rules.unconform_mask.output.mask,
    output:
        split_dir=temp(
            directory(
                bids(
                    root="results",
                    datatype="func",
                    desc="split",
                    suffix="mask",
                    **config["input_wildcards"]["bold"]
                )
            )
        ),
    container:
        config["singularity"]["fsl"]
    group:
        "subj"
    shell:
        "mkdir -p {output} && fslsplit {input}  {output}/vol_ "


rule apply_mask_to_bold:
    input:
        bold_dir=bids(
            root="results",
            datatype="func",
            desc="raw",
            suffix="bold",
            **config["input_wildcards"]["bold"]
        ),
        mask_dir=rules.split_mask.output.split_dir,
    output:
        bold_dir=temp(
            directory(
                bids(
                    root="results",
                    datatype="func",
                    desc="brain",
                    suffix="bold",
                    **config["input_wildcards"]["bold"]
                )
            )
        ),
    container:
        config["singularity"]["itksnap"]
    group:
        "subj"
    shell:
        "mkdir -p {output} && "
        "for in_bold in `ls {input.bold_dir}/*.nii.gz`; do "
        " filename=${{in_bold##*/}} && "
        " prefix=${{filename%%.nii.gz}} &&"
        " in_mask={input.mask_dir}/${{prefix}}.nii.gz && "
        " out_nii={output.bold_dir}/${{prefix}}.nii.gz && "
        " c3d $in_bold $in_mask -multiply -o $out_nii;"
        "done"


ruleorder: upsample_bold > merge_bold


rule upsample_bold:
    input:
        bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="bold.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    output:
        upsample=bids(
            root="results",
            datatype="func",
            desc="{desc,brain}upsampled",
            suffix="bold.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    container:
        config["singularity"]["itksnap"]
    group:
        "subj"
    shell:
        "c4d {input} -resample 200% {output}"


rule upsample_mask:
    input:
        bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    output:
        bids(
            root="results",
            datatype="func",
            desc="{desc}upsampled",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    container:
        config["singularity"]["itksnap"]
    group:
        "subj"
    shell:
        "c4d -interpolation NearestNeighbor {input} -resample 200% {output}"


ruleorder: moco_bold > split_bold


rule moco_bold:
    input:
        bold_dir=bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="bold",
            **config["input_wildcards"]["bold"]
        ),
    output:
        bold_dir=directory(
            bids(
                root="results",
                datatype="func",
                desc="{desc}moco",
                suffix="bold",
                **config["input_wildcards"]["bold"]
            )
        ),
        affine_dir=directory(
            bids(
                root="results",
                datatype="func",
                desc="{desc}moco",
                suffix="xfm",
                **config["input_wildcards"]["bold"]
            )
        ),
    threads: 32
    resources:
        mem_mb=32000,
    shadow:
        "minimal"
    container:
        config["singularity"]["prepdwi"]  #-- this rule needs niftyreg, c3d and mrtrix
    group:
        "subj"
    shell:
        "mkdir -p {output.affine_dir} {output.bold_dir} && "
        "parallel --eta --jobs {threads} "
        "reg_aladin -flo {input.bold_dir}/vol_{{1}}.nii.gz  -ref {input.bold_dir}/vol_0000.nii.gz -res {output.bold_dir}/vol_{{1}}.nii.gz -aff {output.affine_dir}/affine_xfm_ras_{{1}}.txt -rigOnly "
        " ::: `ls {input.bold_dir}/vol_????.nii.gz | tail -n +2 | grep -Po '(?<=vol_)[0-9]+'` && "
        " echo -e '1 0 0 0\n0 1 0 0\n0 0 1 0\n0 0 0 1' > {output.affine_dir}/affine_xfm_ras_000.txt "


rule merge_bold:
    input:
        bold_dir=bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="bold",
            **config["input_wildcards"]["bold"]
        ),
    output:
        nii=bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="bold.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    group:
        "subj"
    container:
        config["singularity"]["fsl"]
    shell:
        "fslmerge -t {output} {input}/*.nii.gz"
