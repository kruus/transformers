<!-- Required extensions: sane_lists, mdx_math(enable_dollar_delimiter=1), mathtools, ams, tagformat, mediawiki-texvc -->
<!-- mdx_math is for $...$ and $$...$$ support -->
<!-- other extensions (examples) wikilinks -->
$\require{mediawiki-texvc}$
# Setup
- Follow [Huggingface - add new model](https://huggingface.co/docs/transformers/v4.17.0/en/add_new_model)
- set up for conda/mamba, instead of venv
    - `mamba create -y -n pyt-cpu -c pytorch -c defaults pytorch torchvision torchaudio cpuonly`
    - `mamba create -y -n pyt --override-channels -c pytorch -c nvidia -c defaults pytorch torchvision torchaudio pytorch-cuda=11.8`
    - env `pyt-cpu` is recommended for initial development work.
- `conda activate `pyt-cpu`
- `pip install -e '.[dev-torch]' 2>&1 | tee pyt-cpu-pip-install-.+dev.log`
    - "Could not find a version that satisfies the requirement tensorflow<2.16,>2.9;"
- `pip install -e '.' 2>&1 | tee pyt-cpu-pip-install.log` was OK
- `pip install -e '.[dev-torch,testing,quality,video,deepspeed]' 2>&1 | tee pyt-hug.log`
    - (flax install could not find proper version)
    - 'av-9.2.0.tar.gz' install was missing many libav* libraries
    - partial fix: `sudo apt install libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev libswscale-dev libswresample-dev sndiod`  (sndiod was only *recommended*)
    - Now get cython compilation error av/logging.pyx:216:22 cannot assign ...
    - fix? `mamba install -y --override-channels -c conda-forge cython` downgrades g++ 14->11 which is perhaps less strict about 'except' vs 'noexcept' C++ code.
    - *STILL* get except vs noexcept error for component 'av'
- downgrade from 'video' = 'decord' + 'av' to just 'decord' (a video frame shuffling sampler)
    -  oh also try with pip install cython...
- `pip install -e '.[dev-torch,testing,quality,decord,deepspeed]' 2>&1 | tee x.log`

### Summary script (so far)
**Install conda** (somewhere)  
This depends on what machine (desktop, slurm) you're on.

**Testing** Begin with "clean" base environments: pyt and pyt-cpu
```
conda deactivate
conda activate
if conda env list | grep -q pyt-cpu; then conda env remove -y -n pyt-cpu; fi
if conda env list | grep -q pyt; then conda env remove -y -n pyt; fi
mamba create -y -n pyt-cpu --override-channels -c pytorch -c defaults pytorch torchvision torchaudio cpuonly 2>&1 | tee env-pyt-cpu.log
mamba create -y -n pyt --override-channels -c pytorch -c nvidia -c defaults pytorch torchvision torchaudio pytorch-cuda=11.8 nvidia::cuda-toolkit 2>&1 | tee env-pyt.log
echo "conda envs pyt and pyt-cpu created!"
echo ""
```
(Note: cuda 11.8 needed only because my GPU is ancient)  
(Note: added `cuda-toolkit` because "CUDA_HOME does not exist" in later pip)  


**Recreate** derived hug envs
```
# recreate basic envs: hug and hug-cpu
{ conda deactivate; conda activate
  echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
  if conda env list | grep -q hug-cpu; then conda env remove -y -n hug-cpu; fi
  conda create -n hug-cpu --clone pyt-cpu;
  conda activate hug-cpu;
  echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
  pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
  echo "Created env hug-cpu"
  echo ""
} 2>&1 | tee env-hug-cpu.log
{ conda deactivate; conda activate
  echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
  if conda env list | grep -q hug; then conda env remove -y -n hug; fi
  conda create -n hug --clone pyt
  conda activate hug;
  echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
  pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
  echo "Created env hug"
  echo ""
} 2>&1 | tee env-hug.log
```

For DSMbind, may need added pip installs --> new env dsm

1. biotite
1. sru++
1. chemprop

/local/kruus/chem/esm env-dsm0.yml (+ env.sh) *suggests*

- `mamba install --override-channels -c nvidia -c pytorch -c conda-forge -c bioconda -y biopython==1.79 numpy==1.23.5 ipython jupyterlab ipywidgets ipykernel conda-forge::nb_conda_kernels conda-forge::scikit-learn conda-forge::rdkit conda-forge::chemprop`
- `pip install 'git+https://github.com/NVIDIA/dllogger.git' 'biopython==1.79'
 'sru==3.0.0.dev6' 'git+https://github.com/jonathanking/sidechainnet/'`

It would be nice to avoid the numpy restriction and biopython restriction.
Perhaps 'trace' to see what parts are used from sidechainnet, biopython, sru?
DSMBind should get some 'global' device (ex. 'gpu' or 'cpu') and default
to storing big stuff on 'cpu' (w/ transfer to 'gpu' as required for infer/train)

How do HuggingFace (HF) projects handle setting default and cpu device, so that
things "just run" on either cpu/gpu machines?

Fork DSMBind
```
cd /local/kruus/hug
git clone https://github.com/kruus/DSMBind.git
git switch ejk  # I will work on a branch, with previous fixes applied
```
This branch also has ejk.ipynb and ejk.py "large test", which I will want
to prune down to "short test", and be able to run without GPU, for correctness
tests.

cd /local/kruus/hug/transformers
# recreate basic envs: dsm and dsm-cpu
{ conda deactivate; conda activate
  echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
  if conda env list | grep -q dsm-cpu; then conda env remove -y -n dsm-cpu; fi
  conda create -n dsm-cpu --clone pyt-cpu;
  conda activate dsm-cpu;
  echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
  mamba install -y --override-channels -c conda-forge -c bioconda -y ipython jupyterlab ipywidgets ipykernel conda-forge::nb_conda_kernels conda-forge::scikit-learn conda-forge::rdkit conda-forge::chemprop
  pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
  echo ""
  echo "Now for DSMBind ..."
  # OH. DSMBind is NOT a pip project at all (yet)
  #    ( cd ../DSMBind && pip install -e . )
  echo "Created env dsm-cpu"
  echo ""
} 2>&1 | tee env-dsm-cpu.log  # this log will end up in /local/kruus/hug/transformers/
```
# oh -- conda biopython (CONFLICT w/ python-3.12?) numpy (NO numpy-base conflict?)
```
# TBD...
{ conda deactivate; conda activate
  echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
  if conda env list | grep -q hug; then conda env remove -y -n hug; fi
  conda create -n hug --clone pyt
  conda activate hug;
  echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
  pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
  echo "Created env hug"
  echo ""
} 2>&1 | tee env-hug.log
```

### Testing
for ejk.py original, try with 24 GB GPU memory, by logging in to
machine `ml21-pc01`.



