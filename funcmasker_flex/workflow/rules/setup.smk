from glob import glob
import snakebids
from snakebids import bids, generate_inputs

from pathlib import Path
from snakeboost import PipEnv

###
# Add inputs to the config file (can later change this to inputs instead)
##

config.update(generate_inputs(
        bids_dir=config["bids_dir"],
        pybids_inputs=config["pybids_inputs"],
        derivatives=config["derivatives"],
        participant_label=config["participant_label"],
        exclude_participant_label=config["exclude_participant_label"],
    )
)

###
# Add wildcard constraints based on inputs
###
wildcard_constraints:
    **snakebids.get_wildcard_constraints(config["pybids_inputs"]),


### 
# Set-up global input variables
###
model = config["use_downloaded"]
work = config['scratch_dir']

###
# Pipenvs
###
nnunet_env = PipEnv(
    packages = [
        'batchgenerators==0.21',
        'nnunet-inference-on-cpu-and-gpu==1.6.6'
    ],
    flags = config["pip-flags"],
    root = Path(work)
)

