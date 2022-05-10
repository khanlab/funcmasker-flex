# this is for evaluating the 2d unet from rutherford/fetal-code


def get_dice_cmd(wildcards, input, output):

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


def get_rutherford_masks(wildcards):
    """assume these are created elsewhere for now.."""
    in_dir = bids(
        root="results",
        datatype="func",
        desc="rutherford",
        suffix="mask",
        **config["input_wildcards"]["mask"],
    ).format(**wildcards)
    niftis = sorted(glob(f"{in_dir}/*.nii.gz"))
    return niftis


def get_manual_masks(wildcards):
    """assume these are created elsewhere for now.."""
    in_dir = bids(
        root="results",
        datatype="func",
        desc="manualclean",
        suffix="mask",
        **config["input_wildcards"]["mask"],
    ).format(**wildcards)

    niftis = sorted(glob(f"{in_dir}/*.nii.gz"))
    return niftis


rule calc_dice:
    input:
        manual_masks=get_manual_masks,
        unet_masks=get_rutherford_masks,
    params:
        dice_cmd=get_dice_cmd,
    output:
        csv=bids(
            root="results",
            datatype="func",
            desc="rutherfordunet",
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
                desc="rutherfordunet",
                suffix="dice.txt",
                **config["input_wildcards"]["bold"]
            ),
            zip,
            **config["input_zip_lists"]["bold"]
        ),
    params:
        header="id,voxels_manual,voxels_auto,voxels_overlap,dice,jaccard",
    output:
        csv="test_rutherfordunet_dice.csv",
    shell:
        "echo {params.header} > {output.csv} && "
        " cat {input} >> {output.csv}"
