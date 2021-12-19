# manual masks have orientation issues, so delete the
# orientation like we do for training before calculating Dice


rule cleanorient_manual_mask:
    input:
        nii=config["input_path"]["mask"],
    output:
        nii=bids(
            root="results",
            datatype="func",
            desc="manualclean",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    shell:
        "c4d {input} -foreach -binarize -endfor -o {output} && fslorient -deleteorient {output}"


rule cleanorient_unet_mask:
    input:
        nii=bids(
            root="results",
            datatype="func",
            desc="brain",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    output:
        nii=bids(
            root="results",
            datatype="func",
            desc="unetclean",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    shell:
        "c4d {input} -foreach -binarize -endfor -o {output} && fslorient -deleteorient {output}"


checkpoint split_manual_mask:
    input:
        nii=bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    output:
        split_dir=directory(
            bids(
                root="results",
                datatype="func",
                desc="{desc,manualclean}",
                suffix="mask",
                **config["input_wildcards"]["mask"]
            )
        ),
    container:
        config["singularity"]["neuroglia"]
    group:
        "subj"
    shell:
        "mkdir -p {output} && fslsplit {input}  {output}/vol && "
        "for im in `ls {output}/*.nii.gz`; do "
        "c3d $im -pad-to 96x96x37 -o ${{im%%.nii.gz}}_pad.nii.gz && rm -f $im && "
        "fslorient -deleteorient ${{im%%.nii.gz}}_pad.nii.gz ;"
        "done"


checkpoint split_unet_mask:
    input:
        nii=bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    output:
        split_dir=directory(
            bids(
                root="results",
                datatype="func",
                desc="{desc,unetclean}",
                suffix="mask",
                **config["input_wildcards"]["mask"]
            )
        ),
    container:
        config["singularity"]["neuroglia"]
    group:
        "subj"
    shell:
        "mkdir -p {output} && fslsplit {input}  {output}/vol && "
        "for im in `ls {output}/*.nii.gz`; do "
        "c3d $im -pad-to 96x96x37 -o ${{im%%.nii.gz}}_pad.nii.gz && rm -f $im && "
        "fslorient -deleteorient ${{im%%.nii.gz}}_pad.nii.gz ;"
        "done"


def get_manual_masks(wildcards):
    split_dir = checkpoints.split_manual_mask.get(
        desc="manualclean", **wildcards
    ).output[0]
    return sorted(glob(os.path.join(split_dir, "*.nii.gz")))


def get_unet_masks(wildcards):
    split_dir = checkpoints.split_unet_mask.get(desc="unetclean", **wildcards).output[0]
    return sorted(glob(os.path.join(split_dir, "*.nii.gz")))


def get_num_masks(wildcards):
    split_dir = checkpoints.split_manual_mask.get(
        desc="manualclean", **wildcards
    ).output[0]
    return sorted(glob(os.path.join(split_dir, "*.nii.gz")))


def get_dice_cmd(wildcards, input, output):

    split_dir = checkpoints.split_unet_mask.get(desc="unetclean", **wildcards).output[0]
    split_dir = checkpoints.split_manual_mask.get(
        desc="manualclean", **wildcards
    ).output[0]

    cmd = []

    subjid = bids(
        include_subject_dir=False,
        include_session_dir=False,
        **config["input_wildcards"]["mask"],
    ).format(**wildcards)

    for i, (manual, unet) in enumerate(zip(input.manual_masks, input.unet_masks)):
        cmd.append(
            f"c3d {manual} {unet} -overlap 1 -pop -pop | "
            f" sed 's/OVL: 1/{subjid}_vol-{i}/' "
            f" >> {output.csv}"
        )
    return " && ".join(cmd)


rule calc_dice:
    input:
        manual_masks=get_manual_masks,
        unet_masks=get_unet_masks,
    params:
        dice_cmd=get_dice_cmd,
    output:
        csv=bids(
            root="results",
            datatype="func",
            suffix="dice.txt",
            **config["input_wildcards"]["mask"]
        ),
    shell:
        "{params.dice_cmd}"


rule concat_dice:
    input:
        dice=expand(
            bids(
                root="results",
                datatype="func",
                suffix="dice.txt",
                **config["input_wildcards"]["bold"]
            ),
            zip,
            **config["input_zip_lists"]["bold"]
        ),
    params:
        header="id,voxels_manual,voxels_auto,voxels_overlap,dice,jaccard",
    output:
        csv="test_dice.csv",
    shell:
        "echo {params.header} > {output.csv} && "
        " cat {input} >> {output.csv}"
