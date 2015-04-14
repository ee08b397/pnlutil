#!/bin/bash -eu

source SetUpData.sh

redo-ifchange ../warp.sh

verify $t1 b3414e6fd18eec3440c3fd73308cf0f7
verify $t1align 2d9e31d707421c024bccb19df1e56708

out=$output/rigid.nrrd
outtrans=$output/rigidxfm.txt
rm $out $outtrans || true
run ../warp.sh -x $outtrans -r $t1 $t1align $out
verify $out e2ca83b715611cf6ce247f569e18863b
test -f $outtrans

out=$output/warped.nrrd
outtrans=$output/warpedxfm.nii.gz
rm $out $outtrans || true
run ../warp.sh -x $outtrans $t1 $t1align $out
verify $out 36785119c152442c04bd8f4c0db9888b
test -f $outtrans
