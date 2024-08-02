# vim: sw=2 ts=2 et
# TBD: have gpu bool to control FOO (in addition to FOO-cpu) environment production.
root=$HOME          # for laptop
gpu=false

if [ `hostname` = "cipr-slurm-js01" ]; then
  gpu=true
elif [ `hostname` = "snake10" ]; then
  root=/local/kruus   # for snake10
  gpu=true
fi

if [ ! -d "${root}" ]; then
  echo "Please set \$root"
  return 1 2> /dev/null
  exit 1
fi

if [ ! -d "${root}/hug/transformers" ]; then
  echo "Please set run hugsetup.sh to set initial ${root}/hug/... git directories"
  return 1 2> /dev/null
  exit 1
fi

# set true to FORCE remove and recreate of various environments
#    (set them false once they have run nicely)
stage1=false      # pyt pyt-cpu
stage2=false      # hug hug-cpu
stage3=false      # dsm-cpu
stage4=false      # dsm
stage5=false      # esm-pyt2
stage6=true      # dsm0

echo "Current envs:"
conda env list
echo ""
echo "hug-envs.sh -- force env recreate from scratch:"
echo " gpu $gpu   stage1 $stage1   stage2 ${stage2}   stage3 ${stage3}   stage4 ${stage4}"
echo ""

# DSMBind relies on some pip packages that will NOT install with python 3.12.
if ! conda env list | grep -q '^pyt-cpu '; then stage1=true; fi
if $gpu; then if ! conda env list | grep -q '^pyt '; then stage1=true; fi; fi
if $stage1; then
  cd "${root}/hug/transformers"
  # **Testing** Begin with "clean" base environments: pyt and pyt-cpu
  conda deactivate
  conda activate
  if conda env list | grep -q '^pyt-cpu '; then conda remove -y -n pyt-cpu --all; fi
  if conda env list | grep -q '^pyt '; then conda remove -y -n pyt --all; fi
  mamba create -y -n pyt-cpu --override-channels -c pytorch -c defaults \
    'python=3.11.*' pytorch torchvision torchaudio cpuonly \
    2>&1 | tee env-pyt-cpu.log
  if $gpu; then
    mamba create -y -n pyt --override-channels -c pytorch -c nvidia -c defaults \
      'python=3.11.*' pytorch torchvision torchaudio pytorch-cuda=11.8 nvidia::cuda-toolkit \
      2>&1 | tee env-pyt.log
  fi
  echo "conda envs pyt-cpu (and maybe pyt) created!"
  echo ""
  # (Note: cuda 11.8 needed only because my GPU is ancient)  
  # (Note: added `cuda-toolkit` because "CUDA_HOME does not exist" in later pip)  
fi

# TBD: test for env pyt / pyt-cpu existing

if ! conda env list | grep -q '^pyt-cpu '; then stage2=true; fi
if $gpu; then if ! conda env list | grep -q '^pyt '; then stage2=true; fi; fi
if $stage2; then
  cd "${root}/hug/transformers"
  # recreate basic envs: hug and hug-cpu
  { conda deactivate; conda activate
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    if conda env list | grep -q '^hug-cpu '; then conda remove -y -n hug-cpu --all; fi
    conda create -n hug-cpu --clone pyt-cpu;
    conda activate hug-cpu;
    # pip dill and evaluate proper versions not installable via conda
    # pip would reinstall codecarbon urllib3 fsspec accelerate (w/ same version)
    # pip would reinstall regex faiss-cpu (w/ newer version)
    # seaborn is 'extra', at this point
    mamba install --override-channels -c conda-forge -y 'safetensors>=0.4.1' 'tqdm>=4.27' 'deepspeed>=0.9.3' 'pytest>=7.2.0,<8.0.0' 'pydantic' 'seaborn' git git-lfs
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
    pip install pre-commit black pylint
    echo "Created env hug-cpu"
    echo ""
  } 2>&1 | tee env-hug-cpu.log
  { conda deactivate; conda activate
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    if conda env list | grep -q '^hug '; then conda remove -y -n hug --all; fi
    if $gpu; then
      conda create -n hug --clone pyt
      conda activate hug;
      mamba install --override-channels -c conda-forge -y 'safetensors>=0.4.1' 'tqdm>=4.27' 'deepspeed>=0.9.3' 'pytest>=7.2.0,<8.0.0' 'pydantic' 'seaborn' git git-lfs
      echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
      pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
      pip install pre-commit black pylint
      echo "Created env hug"
      echo ""
    fi
  } 2>&1 | tee env-hug.log
  echo "conda envs hug-cpu (and maybe hug) created!  See env-hug*.log"
  echo ""
fi

# TBD: test for env hug / hug-cpu existing

if ! conda env list | grep -q '^dsm-cpu '; then stage3=true; fi
# OUCH. biopython (pip?) install requires python <3.11.0a0
# dsm_conda_pkgs="numpy==1.23.5 'python<3.11.0a0' biopython==1.79 ipython jupyterlab ipywidgets ipykernel conda-forge::nb_conda_kernels conda-forge::scikit-learn conda-forge::rdkit conda-forge::chemprop"
# or leave out python and biopython here and let pip control it.
# ? is biotite also required ?
#
# install all, but w/ python<3.12
# numpy: pip will later replace w/ 1.23.5, but 1.23.5 is not installable by conda
#    sru change 3.0.0.dev6 to 3.0.0.dev DID NOT WORK (from sru import SRUpp failed)
# ohoh. conda chemprop-2.0.4 has 'No module named chemprop.features'
#       chemprop.features is in chemprop-1.7.1  (features/ --> featurizers in >=2.0.0)
dsm_conda_pkgs="python<3.12.0a0 biopython ipython jupyterlab ipywidgets ipykernel conda-forge::nb_conda_kernels conda-forge::scikit-learn conda-forge::rdkit conda-forge::chemprop<2 conda-forge::biotite tqdm configparser"
dsm_pip_pkgs="git+https://github.com/NVIDIA/dllogger.git biopython==1.79 sru==3.0.0.dev6 git+https://github.com/jonathanking/sidechainnet/ openmm"
# pip: worst throwback might be sidechainnet -> ProDy -> numpy-1.23.5
# dllogger          OK
# biopython-1.79    OK
# sru=3.0.0.dev     ninja-1.11.1.1 fsspec-2024.6.1
# sidechainnet      ProDy>=2.0 (2.4.1), scipy-1.14.0, tqdm-4.66.4, py3Dmol-2.2.1, pandas-2.2.2, numpy-1.23.5
#   ProDy           pyparsing-3.1.2, *** numpy-1.23.5 *** see https://github.com/prody/ProDy/issues/1915
#   pandas          python-dateutil>=2.8.2 (2.9.0), pytz>=2020.1 (2024.1), tzdata>=2022.7 (2024.1)
#   python-dateutil six>=1.5 (1.16.0
#
# unfortunately DSMBind -> sidechainnet -> openmm conda-installed later will bungle nvidia versions.
# (so do this w/ pip install later)
#
# ProDy may need to be pip-installed from github source with [PR#1908](https://github.com/prody/ProDy/pull/1908) applied
#


if $stage3; then
  cd "${root}/hug/transformers"
  # recreate basic envs: dsm and dsm-cpu
  { conda deactivate; conda activate
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    if conda env list | grep -q '^dsm-cpu '; then conda remove -y -n dsm-cpu --all; fi
    conda create -n dsm-cpu --clone pyt-cpu
    conda activate dsm-cpu;
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    echo ""
    echo " dsm-cpu: adapt conda packages ..."
    echo "          $dsm_conda_pkgs"
    echo "          mamba install --override-channels -c pytorch -c conda-forge -c bioconda -y $dsm_conda_pkgs"
    echo ""
    # Here is a nominal list of additional dsmbind development dependencies
    mamba install --override-channels -c pytorch -c conda-forge -c bioconda -y $dsm_conda_pkgs
    echo ""
    echo " dsm-cpu: pip install transformers 'everything' ..."
    echo ""
    pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
    echo ""
    echo " dsm-cpu: pip install DSMBind extra requirements"
    echo "          $dsm_pip_pkgs"
    echo ""
    # pip install $dsm_pip_pkgs
    #   or take a close look at what preqrequisites are claimed...
    for pp in $dsm_pip_pkgs; do
      set -x
      pip install ${pp}
      set +x
    done
    # for some reason I ended up having "lost" seaborn !
    set -x
    mamba install -y --override-channels -c pytorch -c nvidia -c conda-forge -y seaborn
    set +x
    echo ""
    echo "Now for DSMBind/ ... OH.  it is not a pip project at all"
    # (cd ../DSMBind && pip install -e .)
    echo "Created env dsm-cpu"
    echo ""
  } 2>&1 | tee env-dsm-cpu.log 
  # this log will end up in /local/kruus/hug/transformers/
  # oh -- conda biopython (CONFLICT w/ python-3.12?) numpy (NO numpy-base conflict?)
  echo "conda envs dsm-cpu created!  See env-dsm-cpu.log"
  echo ""
fi

# TBD: test for env dsm-cpu existing

if $gpu; then if ! conda env list | grep -q '^dsm '; then stage4=true; fi; fi

if $stage4; then
  if $gpu; then
    # TBD...
    { conda deactivate; conda activate
      echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
      if conda env list | grep -q '^dsm '; then conda remove -y -n dsm --all; fi
      conda create -n dsm --clone pyt
      conda activate dsm
      echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
      echo ""
      echo " dsm: adapt conda packages ..."
      echo "          $dsm_conda_pkgs"
      echo "          mamba install --override-channels -c pytorch -c conda-forge -c bioconda -y $dsm_conda_pkgs"
      echo ""
      # Here is a nominal list of additional dsmbind development dependencies
      mamba install -y --override-channels -c pytorch -c nvidia -c conda-forge -c bioconda \
        -y $dsm_conda_pkgs
      echo ""
      echo " dsm: pip install transformers 'everything' ..."
      echo ""
      pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
      echo ""
      echo " dsm: pip install DSMBind extra requirements"
      echo "          $dsm_pip_pkgs"
      echo ""
      # pip install $dsm_pip_pkgs
      #   or take a close look at what preqrequisites are claimed...
      for pp in $dsm_pip_pkgs; do
        set -x
        pip install ${pp}
        set +x
      done
      # for some reason I ended up having "lost" seaborn !
      echo ""
      echo 'mamba install -y --override-channels -c pytorch -c nvidia -c conda-forge -y seaborn'
      mamba install -y --override-channels -c pytorch -c nvidia -c conda-forge -y seaborn
      echo ""
      echo "Now for DSMBind/ ... OH.  it is not a pip project at all"
      #    ( cd ../DSMBind && pip install -e . )
      echo "Created env dsm"
      echo ""
    } 2>&1 | tee env-dsm.log  # this log will end up in /local/kruus/hug/transformers/
    echo "conda envs dsm created!  See env-dsm.log"
    echo ""
  fi
fi
cd $root
conda env list

echo ""
echo "stage5: create / recreate environments for facebook ESMfold, for hug/esm/"
if ! $gpu; then
  echo "stage5 skipped -- no GPU"
else
  if ! conda env list | grep -q '^esm-pyt2 '; then stage5=true; fi
  if [ ! -f "${root}/hug/esm/env-pyt2.yml" ]; then
    echo "stage5 skipped -- missing ${root}/hug/esm/env-pyt2.yml file for esm-pyt2 environment"
    stage5=false
  fi
fi
echo ""
if $stage5; then
  { echo "stage5: create / recreate env esm-pyt2"
    conda deactivate; conda activate
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    if conda env list | grep -q '^esm-pyt2 '; then conda remove -y -n esm-pyt2 --all; fi
    mamba env create --file "${root}/hug/esm/env-pyt2.yml"   # from scratch, since python=3.9
    conda activate esm-pyt2
    if [ x"$CONDA_DEFAULT_ENV" = x"esm-pyt2" ]; then
      if [ -d hug/esm ]; then
        echo ""
        echo "pip install hug/esm in development mode"
        echo ""
        cd hug/esm
        pip install -e .
        # esm is now my copy from nj-gitlab, so run a quick test ...
        cd demo
        time python demo-esmfold.py 2>&1 | tee demo-esmfold-env-esm-pyt2.log
        echo ""
        echo "*** End env esm-pyt2 demo-esmfold.py test ***"
        echo ""
      fi
    fi
  } 2>&1 | tee env-esm-pyt2.log
fi
cd $root

echo ""
echo "stage6: create / recreate env dsm-ejk for DSMBind-ejk/ (python-3.9, facebook esm)"
if ! conda env list | grep -q '^dsm-ejk '; then stage6=true; fi
if ! $gpu; then
  echo "stage6 skipped -- no GPU"
  stage6=false
elif ! conda env list | grep -q '^esm-pyt2 '; then
  echo "stage6 skipped -- missing stage5 env esm-pyt2"
  stage6=false
fi
echo ""
if $stage6; then
  { echo "stage6: create / recreate env dsm-ejk"
    echo " patterned after hug/DSMBind-ejk/env.sh"
    conda deactivate; conda activate
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    if conda env list | grep -q '^dsm-ejk '; then conda remove -y -n dsm --all; fi
    conda create -n dsm-ejk --clone esm-pyt2
    conda activate dsm-ejk
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    if [ x"$CONDA_DEFAULT_ENV" = x"dsm-ejk" ]; then
      echo "conda remove -y fairscale ..."
      conda remove -y -n dsm-ejk fairscale
      echo "mamba adjustments ..."
      # This one seems to take a long time to resolve.  Are nvidia and pytorch channels contributing?
      echo "mamba install --override-channels -c nvidia -c pytorch -c conda-forge -c bioconda -y"
      echo "      biopython==1.79 numpy==1.23.5 ipython jupyterlab ipywidgets ipykernel"
      echo "      conda-forge::nb_conda_kernels conda-forge::scikit-learn conda-forge::rdkit"
      echo "      conda-forge::chemprop"
      mamba install --override-channels -c nvidia -c pytorch -c conda-forge -c bioconda -y biopython==1.79 numpy==1.23.5 ipython jupyterlab ipywidgets ipykernel conda-forge::nb_conda_kernels conda-forge::scikit-learn conda-forge::rdkit conda-forge::chemprop
      # These ADD to esm-pyt2 pip installs of dllogger, flash-attention, and openfold
      echo 'pip install sru==3.0.0.dev  git+https://github.com/jonathanking/sidechainnet/ ...'
      pip install 'sru==3.0.0.dev6' 'git+https://github.com/jonathanking/sidechainnet/'
    fi
  } 2>&1 | tee env-dsm-ejk.log
fi
cd $root

# TBD: test for env dsm existing
