def get_nnunet_env(wildcards):
    return " && ".join(
        [f"export {key}={val}" for (key, val) in config["nnunet_env"].items()]
    )


def get_nnunet_env_tmp(wildcards):
    return " && ".join(
        [f"export {key}={val}" for (key, val) in config["nnunet_env_tmp"].items()]
    )
