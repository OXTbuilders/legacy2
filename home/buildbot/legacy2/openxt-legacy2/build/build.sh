#!/bin/bash -ex

BUILDID=$1
BRANCH=$2	# Unused for now

umask 0022
cd build
git clone file:///home/buildbot/legacy2/openxt-legacy2/build/git/openxt.git
cd openxt
git checkout $BRANCH
cp -r ../../certs .
mkdir wintools
rsync -r builds@158.69.227.117:/home/builds/win/$BRANCH/ wintools/
WINTOOLS="`pwd`/wintools"
WINTOOLS_ID="`grep -o '[0-9]*' wintools/BUILD_ID`"
mv /tmp/git_heads_$BUILDID git_heads
cp example-config .config
cat <<EOF >> .config
BRANCH=$BRANCH
NAME_SITE="oxt"
OPENXT_MIRROR="http://158.69.227.117/mirror"
OE_TARBALL_MIRROR="http://158.69.227.117/mirror"
OPENXT_GIT_MIRROR="/home/buildbot/legacy2/openxt-legacy2/build/git"
OPENXT_GIT_PROTOCOL="file"
REPO_PROD_CACERT="/home/buildbot/legacy2/openxt-legacy2/build/certs/prod-cacert.pem"
REPO_DEV_CACERT="/home/buildbot/legacy2/openxt-legacy2/build/certs/dev-cacert.pem"
REPO_DEV_SIGNING_CERT="/home/buildbot/legacy2/openxt-legacy2/build/certs/dev-cacert.pem"
REPO_DEV_SIGNING_KEY="/home/buildbot/legacy2/openxt-legacy2/build/certs/dev-cakey.pem"
WIN_BUILD_OUTPUT="$WINTOOLS"
XC_TOOLS_BUILD=$WINTOOLS_ID
SYNC_CACHE_OE=158.69.227.117:/home/builds/oe
BUILD_RSYNC_DESTINATION=158.69.227.117:/home/builds/builds
NETBOOT_HTTP_URL=http://158.69.227.117/builds
EOF
#./do_build.sh -i $BUILDID -s setupoe,sync_cache
./do_build.sh -i $BUILDID | tee build.log
ret=${PIPESTATUS[0]}
cd -
cd -

exit $ret
