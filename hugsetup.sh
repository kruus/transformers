#!/bin/bash
# vim: ts=4 sw=4 et

# set root to parent of "hug/" subdirectory that we'll populate
if [ x"`hostname`" = x"snake10" ]; then
    root=/local/kruus
else
    root="${HOME}"
fi

test -d "${root}" || { echo "OHOH: please set 'root' properly (was ${root})"; false; }

if [ ! -d "${root}/hug" ]; then
    # populate 'hug' directory

	cd "${root}"
	mkdir hug
	cd "${root}/hug"
	scp snake10:/local/kruus/hug/hug-notes.md ./
else
    echo "Good. ${root}/hug/ directory exists"
fi

echo ""
if [ ! -d "${root}/hug/transformers" ]; then
	cd "${root}/hug"
	git clone https://github.com/kruus/transformers.git
	cd transformers && git remote add upstream https://github.com/huggingface/transoformers.git
fi

echo ""
cd "${root}"
# DSMBind branches
#  master          my github fork of DSMbind
#    ^-- ejk       "runnable"
#    ^-- hug       "huggingface" style (lots of mods)
if [ ! -d "${root}/hug/DSMBind" ]; then
    echo "# create ${root}/DSMBind/ for branch 'hug' development"
    ls -l hug
	cd "${root}/hug"
	git clone https://github.com/kruus/DSMBind.git
	cd DSMBind
	git switch hug
	git branch --set-upstream-to hug
else
    echo "Good. ${root}/hug/DSMBind/ exists"
fi
cd "${root}/hug/DSMBind"
git remote -v
git branch -v

echo ""
cd "${root}"
if [ ! -d "${root}/hug/DSMBind-ejk" ]; then
    echo "# create DSMBind-ejk/ for branch 'ejk' runnable, small test"
    ls -l hug
	cd "${root}/hug"
	git clone https://github.com/kruus/DSMBind.git DSMBind-ejk
	cd DSMBind-ejk
	git switch ejk
	git branch --set-upstream-to ejk
else
    echo "Good. ${root}/hug/DSMBind-ejk/ exists"
fi
cd "${root}/hug/DSMBind-ejk"
git remote -v
git branch -v

echo ""
cd "${root}"

echo ""
echo "TBD: create huggingface environments for transformers + esm"
echo "     and DSMBind (a project, being transfered to hug code bit by bit)"
echo ""
