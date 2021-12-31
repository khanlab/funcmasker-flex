from glob import glob
import snakebids
from snakebids import bids, generate_inputs


config.update(generate_inputs(
        bids_dir=config["bids_dir"],
        pybids_inputs=config["pybids_inputs"],
        derivatives=config["derivatives"],
        participant_label=config["participant_label"],
        exclude_participant_label=config["exclude_participant_label"],
    )
)

# this adds constraints to the bids naming
wildcard_constraints:
    **snakebids.get_wildcard_constraints(config["pybids_inputs"]),



model = config["use_downloaded"]



