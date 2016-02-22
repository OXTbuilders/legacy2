#!/bin/bash -ex

BUILDID=$1
BRANCH=$2
LAYERS=$3
OVERRIDES=$4
ISSUE=$5

do_overrides () {
    for trip in $OVERRIDES; do
        name=$(echo $trip | cut -f 1 -d ':')
        git=$(echo $trip | cut -f 2 -d ':')
        branch=$(echo $trip | cut -f 3 -d ':')
        
        rm -rf git/$name.git
        git clone --mirror git://$git/$name git/$name.git
        # Copyright (c) Jed
	# The following code will name the override $BRANCH, to match what we're building
	if [[ $branch != "${BRANCH}" ]]; then
	    pushd git/$name.git
	    # Avoid being on a releavant branch by moving the HEAD to a tmp branch
	    git branch tmp
	    git symbolic-ref HEAD refs/heads/tmp
	    # Move $BRANCH to a backup location (avoid removing it, since some branches can't be removed)
	    #   Do not fail if the branch doesn't exist, it can happen
	    git branch -m $BRANCH original$BRANCH || true
	    # Create a branch named $BRANCH out of the $branch requested by the override
	    git branch $BRANCH $branch
	    # Make $BRANCH the head of the repository
	    git symbolic-ref HEAD refs/heads/$BRANCH
	    popd
	    fi
    done
}

umask 0022

# Handle overrides
#   Note: It is against policy to set both $ISSUE and $OVERRIDES in the buildbot ui
if [[ $ISSUE != 'None' && $OVERRIDES != 'None' ]]; then
    echo "Cannot pass both a Jira ticket and custom repository overrides to build from."
    exit -1
elif [[ $ISSUE != 'None' && $OVERRIDES == 'None' ]]; then
    OVERRIDES=$( ./build_for_issue.sh $ISSUE )
else
    echo "Building using method other than Jira ticket."
fi
OFS=$IFS
IFS=','
[ $OVERRIDES != "None" ] && do_overrides
IFS=$OFS

cd build
git clone -b $BRANCH file:///home/buildbot/legacy2/openxt-legacy2/build/git/openxt.git
cd openxt
cp -r ../../certs .
mkdir wintools
rsync -r builds@158.69.227.117:/home/builds/win/$BRANCH/ wintools/
WINTOOLS="`pwd`/wintools"
WINTOOLS_ID="`grep -o '[0-9]*' wintools/BUILD_ID`"
mv /tmp/git_heads_$BUILDID git_heads
cp example-config .config

# This builder is meant to be fast, let's build only the principal steps
cat <<EOF >> .config
STEPS="initramfs,stubinitramfs,dom0,uivm,ndvm,installer,installer2"
EOF

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
SYNC_CACHE_OE=builds@158.69.227.117:/home/builds/oe
BUILD_RSYNC_DESTINATION=builds@158.69.227.117:/home/builds/builds
NETBOOT_HTTP_URL=http://158.69.227.117/builds
EOF
./do_build.sh -i $BUILDID -s setupoe #,sync_cache

# Handle layers
if [[ $LAYERS != 'None' ]]; then
    ../../engage_layers.sh $LAYERS
fi

./do_build.sh -i $BUILDID | tee build.log
ret=${PIPESTATUS[0]}
cd -
cd -

exit $ret
