# manual masks have orientation issues, so delete the
# orientation like we do for training before calculating Dice


rule cleanorient_manual_mask:
    input:
        nii=config["input_path"]["mask"],
    params:
        del_orient=lambda wildcards, output: "&& fslorient -deleteorient {output}".format(
            output=output
        )
        if config["del_orient"]
        else "",
    output:
        nii=bids(
            root="results",
            datatype="func",
            desc="manualclean",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    shell:
        "c4d {input} -foreach -binarize -endfor -o {output} {params.del_orient}"


rule cleanorient_unet_mask:
    input:
        nii=bids(
            root="results",
            datatype="func",
            desc="brain",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    params:
        del_orient=lambda wildcards, output: "&& fslorient -deleteorient {output}".format(
            output=output
        )
        if config["del_orient"]
        else "",
    output:
        nii=bids(
            root="results",
            datatype="func",
            desc="unetclean",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    shell:
        "c4d {input} -foreach -binarize -endfor -o {output} {params.del_orient}"


def getcmd_split_mask(wildcards, input, output):
    if config["del_orient"]:
        return (
            "mkdir -p {output} && fslsplit {input}  {output}/vol && "
            "for im in `ls {output}/*.nii.gz`; do "
            "c3d $im -pad-to 96x96x37 -o ${{im%%.nii.gz}}_pad.nii.gz && rm -f $im "
            "&& fslorient -deleteorient ${{im%%.nii.gz}}_pad.nii.gz ; done "
        ).format(input=input, output=output)
    else:
        return (
            "mkdir -p {output} && fslsplit {input}  {output}/vol && "
            "for im in `ls {output}/*.nii.gz`; do "
            "c3d $im -pad-to 96x96x37 -o ${{im%%.nii.gz}}_pad.nii.gz && rm -f $im; done"
        ).format(input=input, output=output)


checkpoint split_manual_mask:
    input:
        nii=bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    params:
        cmd=getcmd_split_mask,
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
        "{params.cmd}"


checkpoint split_unet_mask:
    input:
        nii=bids(
            root="results",
            datatype="func",
            desc="{desc}",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    params:
        cmd=getcmd_split_mask,
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
        "{params.cmd}"


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
                **config["input_wildcards"]["mask"]
            ),
            zip,
            **config["input_zip_lists"]["mask"]
        ),
    params:
        header="id,voxels_manual,voxels_auto,voxels_overlap,dice,jaccard",
    output:
        csv="test_dice.csv",
    shell:
        "echo {params.header} > {output.csv} && "
        " cat {input} >> {output.csv}"
