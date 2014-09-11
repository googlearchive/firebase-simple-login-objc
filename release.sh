#!/bin/bash

cd $(dirname $0)

FIREBASEM="FirebaseSimpleLogin/FirebaseSimpleLogin.m"
if [[ ! -e $FIREBASEM ]]; then
  echo "error: Can't find main $FIREBASEM source."
  exit 1
fi

STANDALONE_DEST="../firebase-clients/ios"
STANDALONE_STUB="FirebaseSimpleLogin.framework"

# Check for destination
if [[ ! -d $STANDALONE_DEST ]]; then
  echo "error: Destination directory not found; 'firebase-clients' needs to be a sibling of this repo."
  exit 1
fi

# We'll be diong these builds on mac, so we need gsort
which gsort 1> /dev/null
if [[ $? -ne 0 ]]; then
  echo "error: can't do version sorting. brew install coreutils."
  exit 1
fi

# Get version we're releasing based on old tag
PREV_VER=$(git tag -l | awk -F 'v' '{print $2}' | gsort -V | tail -1)
if [[ ! -z $PREV_VER ]]; then
  VERSION_CAND=$(echo $PREV_VER | ( IFS=".$IFS" ; read a b c && echo $a.$b.$((c + 1)) ))
fi
read -p "What version are we releasing? ($VERSION_CAND) " VER
if [[ -z $VER ]]; then
  VER=$VERSION_CAND
fi

# Check if we already have this in the destination
STANDALONE_TARGET=$STANDALONE_DEST/$STANDALONE_STUB-$VER.zip
if [[ -e $STANDALONE_TARGET ]]; then
  echo "error: This version has already been published:"
  ls -l $STANDALONE_TARGET
  exit 1
fi

# Check for outstanding changes; we don't want to release something that isn't checked in and tagged.
if [[ $(git status | grep -c "nothing to commit, working directory clean") -ne 1 ]]; then
  echo "error: It appears there are outstanding git changes."
  exit 1
fi

# Update version in Firebase.m and spec file
sed -i "" -e "s/XXX_TAG_VERSION_XXX/$VER/g" $FIREBASEM

# Do the actual building
./build.sh
if [[ $? -ne 0 ]]; then
  echo "error: There was an error in the build."
  exit 1
fi

STANDALONE_SRC="target/${STANDALONE_STUB}.zip"
if [[ ! -e $STANDALONE_SRC ]]; then
  echo "error: The build indicated success but couldn't find the expected artifact."
  exit 1
fi

cp $STANDALONE_SRC $STANDALONE_TARGET
cp $STANDALONE_SRC ${STANDALONE_DEST}/${STANDALONE_STUB}-LATEST.zip

pushd ${STANDALONE_DEST}/
git add .
git commit -am "[firebase-release] Updated Firebase iOS Simple Login client to $VER"
popd

echo "firebase-clients repo updated. Push and deploy to make changes live."

# Revert the sed'd files for versions and podspec
git checkout $FIREBASEM

# Once everything is successful then tag it
git tag v$VER
git push --tags origin master

echo "Manual steps:"
echo "  - Push and deploy firebase-clients from jenkins"
echo "  - node tweetomaton.js \"v${VER} of iOS @Firebase Simple Login client is available https://www.firebase.com/docs/downloads.html Changelog: https://cdn.firebase.com/ios/changelog.txt\""
echo ---
echo "w00! done!!"
