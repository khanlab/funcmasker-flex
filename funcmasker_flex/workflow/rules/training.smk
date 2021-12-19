
rule cleanorient_bold:
    input:
        nii=config["input_path"]["bold"],
    output:
        nii=bids(
            root="results",
            datatype="func",
            desc="cleanorient",
            suffix="bold.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    shell:
        "c4d {input} -o {output} && fslorient -deleteorient {output}"


rule cleanorient_mask:
    input:
        nii=config["input_path"]["mask"],
    output:
        nii=bids(
            root="results",
            datatype="func",
            desc="cleanorient",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    shell:
        "c4d {input} -foreach -binarize -endfor -o {output} && fslorient -deleteorient {output}"


rule split_cleanorient_bold:
    input:
        nii=bids(
            root="results",
            datatype="func",
            desc="cleanorient",
            suffix="bold.nii.gz",
            **config["input_wildcards"]["bold"]
        ),
    params:
        img_prefix=bids(
            suffix="",
            include_subject_dir=False,
            include_session_dir=False,
            **config["input_wildcards"]["bold"]
        ),
    output:
        split_dir=directory(
            bids(
                root="results",
                datatype="func",
                desc="cleanorient",
                suffix="bold",
                **config["input_wildcards"]["bold"]
            )
        ),
    container:
        config["singularity"]["neuroglia"]
    group:
        "subj"
    shell:
        #split, then replace suffix with _0000.nii.gz 
        #need to pad to 96x96x37 as some datasets in rutherford have incorrect cropping..
        "mkdir -p {output} && fslsplit {input}  {output}/{params.img_prefix} && "
        "for im in `ls {output}/*.nii.gz`; do "
        "c3d $im -pad-to 96x96x37 -o ${{im%%.nii.gz}}_0000.nii.gz &&  rm -f $im; "
        "fslorient -deleteorient ${{im%%.nii.gz}}_0000.nii.gz ; "
        "done"


rule split_cleanorient_mask:
    input:
        nii=bids(
            root="results",
            datatype="func",
            desc="cleanorient",
            suffix="mask.nii.gz",
            **config["input_wildcards"]["mask"]
        ),
    params:
        img_prefix=bids(
            suffix="",
            include_subject_dir=False,
            include_session_dir=False,
            **config["input_wildcards"]["mask"]
        ),
    output:
        split_dir=directory(
            bids(
                root="results",
                datatype="func",
                desc="cleanorient",
                suffix="mask",
                **config["input_wildcards"]["mask"]
            )
        ),
    container:
        config["singularity"]["neuroglia"]
    group:
        "subj"
    shell:
        "mkdir -p {output} && fslsplit {input}  {output}/{params.img_prefix}"


checkpoint cp_training_img:
    input:
        split_dirs=expand(
            bids(
                root="results",
                datatype="func",
                desc="cleanorient",
                suffix="bold",
                **config["input_wildcards"]["bold"]
            ),
            zip,
            **config["input_zip_lists"]["bold"]
        ),
    output:
        training_img_dir=directory(
            "results/nnUNet_raw_data/{unettask}/imagesTr".format(
                unettask=config["download_model"][model]["unettask"]
            )
        ),
    threads: 32  #to make it serial on a node
    group:
        "preproc"
    shell:
        "mkdir -p {output} && "
        "for dir in {input.split_dirs}; do"
        "  cp -v ${{dir}}/*.nii.gz {output.training_img_dir}; "
        "done"


checkpoint cp_training_lbl:
    input:
        split_dirs=expand(
            bids(
                root="results",
                datatype="func",
                desc="cleanorient",
                suffix="mask",
                **config["input_wildcards"]["mask"]
            ),
            zip,
            **config["input_zip_lists"]["bold"]
        ),
    output:
        training_img_dir=directory(
            "results/nnUNet_raw_data/{unettask}/labelsTr".format(
                unettask=config["download_model"][model]["unettask"]
            )
        ),
    threads: 32  #to make it serial on a node
    group:
        "preproc"
    shell:
        "mkdir -p {output} && "
        "for dir in {input.split_dirs}; do"
        "  cp -v ${{dir}}/*.nii.gz {output.training_img_dir}; "
        "done"


def get_training_imgs(wildcards):
    checkpoint_output = checkpoints.cp_training_img.get(**wildcards).output[0]
    return sorted(glob(os.path.join(checkpoint_output, "*.nii.gz")))


def get_training_lbls(wildcards):
    checkpoint_output = checkpoints.cp_training_lbl.get(**wildcards).output[0]
    return sorted(glob(os.path.join(checkpoint_output, "*.nii.gz")))


def get_training_imgs_nosuffix(wildcards, input):
    return [img[:-12] + ".nii.gz" for img in input.training_imgs]


rule create_dataset_json:
    input:
        training_imgs=get_training_imgs,
        training_lbls=get_training_lbls,
        template_json=workflow.source_path("../../resources/template.json"),
    params:
        training_imgs_nosuffix=get_training_imgs_nosuffix,
    output:
        dataset_json="results/nnUNet_raw_data/{unettask}/dataset.json".format(
            unettask=config["download_model"][model]["unettask"]
        ),
    group:
        "preproc"
    script:
        "../scripts/create_json.py"


rule plan_preprocess:
    input:
        dataset_json="results/nnUNet_raw_data/{unettask}/dataset.json".format(
            unettask=config["download_model"][model]["unettask"]
        ),
    params:
        nnunet_env_cmd=get_nnunet_env,
        task_num=lambda wildcards: re.search(
            "Task([0-9]+)\w*", config["download_model"][model]["unettask"]
        ).group(1),
    output:
        dataset_json="preprocessed/{unettask}/dataset.json".format(
            unettask=config["download_model"][model]["unettask"]
        ),
    group:
        "preproc"
    resources:
        threads=8,
        mem_mb=16000,
    shell:
        "{params.nnunet_env_cmd} && "
        "nnUNet_plan_and_preprocess  -t {params.task_num} --verify_dataset_integrity"


def get_checkpoint_opt(wildcards, output):
    if os.path.exists(output.latest_model):
        return "--continue_training"
    else:
        return ""


rule train_fold:
    input:
        dataset_json="preprocessed/{unettask}/dataset.json".format(
            unettask=config["download_model"][model]["unettask"]
        ),
    params:
        nnunet_env_cmd=get_nnunet_env_tmp,
        rsync_to_tmp=f"rsync -av {config['nnunet_env']['nnUNet_preprocessed']} $SLURM_TMPDIR",
        #add --continue_training option if a checkpoint exists
        checkpoint_opt=get_checkpoint_opt,
        unettask=config["download_model"][model]["unettask"],
        trainer=config["nnunet"]["trainer"],
        arch=config["nnunet"]["arch"],
    output:
        latest_model="resources/trained_models/nnUNet/{arch}/{unettask}/{trainer}__nnUNetPlansv2.1/fold_{{fold}}/model_latest.model".format(
            unettask=config["download_model"][model]["unettask"],
            trainer=config["nnunet"]["trainer"],
            arch=config["nnunet"]["arch"],
        ),
        best_model="resources/trained_models/nnUNet/{arch}/{unettask}/{trainer}__nnUNetPlansv2.1/fold_{{fold}}/model_best.model".format(
            unettask=config["download_model"][model]["unettask"],
            trainer=config["nnunet"]["trainer"],
            arch=config["nnunet"]["arch"],
        ),
    threads: 16
    resources:
        gpus=1,
        mem_mb=64000,
        time=1440,
        dataaugment_threads=16,
    group:
        "train"
    shell:
        "{params.nnunet_env_cmd} && "
        "{params.rsync_to_tmp} && "
        "export nnUNet_n_proc_DA={resources.dataaugment_threads} && "
        "nnUNet_train {params.checkpoint_opt} {params.arch} {params.trainer} {params.unettask} {wildcards.fold}"


rule package_trained_model:
    """ Creates tar file for performing inference with workflow_inference -- note, if you do not run training to completion (1000 epochs), then you will need to clear the snakemake metadata before running this rule, else snakemake will not believe that the model has completed. """
    input:
        latest_model=expand(
            "resources/trained_models/nnUNet/{arch}/{unettask}/{trainer}__nnUNetPlansv2.1/fold_{fold}/{checkpoint}.model",
            fold=range(5),
            allow_missing=True,
        ),
        latest_model_pkl=expand(
            "resources/trained_models/nnUNet/{arch}/{unettask}/{trainer}__nnUNetPlansv2.1/fold_{fold}/{checkpoint}.model.pkl",
            fold=range(5),
            allow_missing=True,
        ),
        plan="resources/trained_models/nnUNet/{arch}/{unettask}/{trainer}__nnUNetPlansv2.1/plans.pkl",
    params:
        trained_model_dir=config["nnunet_env"]["RESULTS_FOLDER"],
        files_to_tar="nnUNet/{arch}/{unettask}/{trainer}__nnUNetPlansv2.1",
    output:
        model_tar="resources/trained_model.{arch}.{unettask}.{trainer}.{checkpoint}.tar",
    shell:
        "tar -cvf {output} -C {params.trained_model_dir} {params.files_to_tar}"
