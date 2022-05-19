# Installation

funcmasker-flex: BIDS App for fetal bold brain masking

## Requirements

-   Docker (Mac/Windows/Linux) or Singularity (Linux) or Python+Singularity (Linux)
-   GPU not required

### Notes:

-   Inputs to funcmasker-flex should typically be a BIDS dataset, though you can also use the `--path-bold` option to parse non-BIDS file/folder structures, as long as the subject (or subject+session) are only unique identifiers in the file/folder structure


## Running with Docker

Pull the container:

    docker pull khanlab/funcmasker-flex:latest

See funcmasker-flex usage docs:

    docker run -it --rm \
    khanlab/funcmasker-flex:latest \
    -h

Do a dry run, printing the command at each step:

    docker run -it --rm \
    -v PATH_TO_BIDS_DIR:/bids:ro \
    -v PATH_TO_OUTPUT_DIR:/output \
    khanlab/funcmasker-flex:latest \
    /bids /output participant -np 

Run it with maximum number of cores:

    docker run -it --rm \
    -v PATH_TO_BIDS_DIR:/bids:ro \
    -v PATH_TO_OUTPUT_DIR:/output \
    khanlab/funcmasker-flex:latest \
    /bids /output participant -p --cores all

For those not familiar with Docker, the first three lines of this
example are generic Docker arguments to ensure it is run with the safest
options and has permission to access your input and output directories
(specified here in capital letters). The third line specifies the
funcmasker-flex Docker container, and the fourth line contains the required
arguments for funcmasker-flex, after which you can additionally specify optional arguments. You may want to familiarize yourself with
[Docker options](https://docs.docker.com/engine/reference/run/), and an
overview of funcmasker-flex arguments is provided in the [Command line
interface](https://funcmasker-flex.readthedocs.io/en/stable/usage/app_cli.html)
documentation section.

## Running with Singularity

Pull from dockerhub:

    singularity pull funcmasker-flex_latest.sif docker://khanlab/funcmasker-flex:latest

See funcmasker-flex usage docs:

    singularity run -e funcmasker-flex_latest.sif -h

Do a dry run, printing the command at each step:

    singularity run -e funcmasker-flex_latest.sif \
    PATH_TO_BIDS_DIR PATH_TO_OUTPUT_DIR participant -np 

Run it with maximum number of cores:

    singularity run -e funcmasker-flex_latest.sif \
    PATH_TO_BIDS_DIR PATH_TO_OUTPUT_DIR participant -p --cores all

Note that you may need to adjust your [Singularity options](https://sylabs.io/guides/3.1/user-guide/cli/singularity_run.html) to ensure this container can read and write to yout input and output directories, respectively. For example, if your home directory is full or inaccessible, you may wish to set the following singularity parameters:

    export SINGULARITY_CACHEDIR=/YOURDIR/.cache/singularity
    export SINGULARITY_BINDPATH=/YOURDIR:/YOURDIR

, where `YOURDIR` is your preferred storage location.


## Running with Python+Singularity

If you are using Python on Linux, you can run funcmasker-flex directly from python, and with the `--use-singularity` option, it will download any required containers for rules that require additional dependencies. 

To install the funcmasker-flex python package, you can either `pip install funcmasker-flex` (preferably in a virtualenv), or `pipx install funcmasker-flex`, or for active development of the code you can clone the github repository and use poetry. 


