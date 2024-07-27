# vim: sw=2 ts=2 et
# TBD: have gpu bool to control FOO (in addition to FOO-cpu) environment production.
root=$HOME          # for laptop
gpu=false

# snake10 gpu settings..
root=/local/kruus   # for snake10
gpu=true

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

# set true to force create (or recreate) various environments
#    (set them false once they have run nicely)
stage1=false
stage2=true
stage3=true
stage4=true

if $stage1; then
  cd "${root}/hug/transformers"
  # **Testing** Begin with "clean" base environments: pyt and pyt-cpu
  conda deactivate
  conda activate
  if conda env list | grep -q pyt-cpu; then conda env remove -y -n pyt-cpu; fi
  if conda env list | grep -q pyt; then conda env remove -y -n pyt; fi
  mamba create -y -n pyt-cpu --override-channels -c pytorch -c defaults pytorch torchvision torchaudio cpuonly 2>&1 | tee env-pyt-cpu.log
  if $gpu; then
    mamba create -y -n pyt --override-channels -c pytorch -c nvidia -c defaults pytorch torchvision torchaudio pytorch-cuda=11.8 nvidia::cuda-toolkit 2>&1 | tee env-pyt.log
  fi
  echo "conda envs pyt-cpu (and maybe pyt) created!"
  echo ""
  # (Note: cuda 11.8 needed only because my GPU is ancient)  
  # (Note: added `cuda-toolkit` because "CUDA_HOME does not exist" in later pip)  
fi

# TBD: test for env pyt / pyt-cpu existing

if $stage2; then
  cd "${root}/hug/transformers"
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
    if $gpu; then
      conda create -n hug --clone pyt
      conda activate hug;
      echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
      pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
      echo "Created env hug"
      echo ""
    fi
  } 2>&1 | tee env-hug.log
  echo "conda envs hug-cpu (and maybe hug) created!  See env-hug*.log"
  echo ""
fi

# TBD: test for env hug / hug-cpu existing

if $stage3; then
  cd "${root}/hug/transformers"
  # recreate basic envs: dsm and dsm-cpu
  { conda deactivate; conda activate
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    if conda env list | grep -q dsm-cpu; then conda env remove -y -n dsm-cpu; fi
    conda create -n dsm-cpu --clone pyt-cpu;
    conda activate dsm-cpu;
    echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
    # Here is a nominal list of additional dsmbind development dependencies
    mamba install -y --override-channels -c conda-forge -c bioconda -y $dsm_conda_pkgs
    pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
    echo ""
    echo "Now for DSMBind ..."
    # OH. DSMBind is NOT a pip project at all (yet)
    #    ( cd ../DSMBind && pip install -e . )
    echo "Created env dsm-cpu"
    echo ""
  } 2>&1 | tee env-dsm-cpu.log  # this log will end up in /local/kruus/hug/transformers/
  # oh -- conda biopython (CONFLICT w/ python-3.12?) numpy (NO numpy-base conflict?)
  echo "conda envs dsm-cpu created!  See env-dsm-cpu.log"
  echo ""
fi

# TBD: test for env dsm-cpu existing

if $stage4; then
  if $gpu; then
    # TBD...
    { conda deactivate; conda activate
      echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
      if conda env list | grep -q dsm; then conda env remove -y -n dsm; fi
      conda create -n dsm --clone pyt;
      conda activate dsm;
      echo "CONDA_DEFAULT_ENV = $CONDA_DEFAULT_ENV"
      # Here is a nominal list of additional dsmbind development dependencies
      mamba install -y --override-channels -c conda-forge -c bioconda -y $dsm_conda_pkgs
      pip install -e '.[dev-torch,testing,quality,decord,deepspeed]';
      echo ""
      echo "Now for DSMBind ..."
      # OH. DSMBind is NOT a pip project at all (yet)
      #    ( cd ../DSMBind && pip install -e . )
      echo "Created env dsm"
      echo ""
    } 2>&1 | tee env-dsm.log  # this log will end up in /local/kruus/hug/transformers/
    echo "conda envs dsm created!  See env-dsm.log"
    echo ""
  fi
fi

# TBD: test for env dsm existing

