#!/bin/sh

set -e # Exit sub shell if anything errors
DIR="$(cd "$(dirname "$0")"; pwd)"
OUTPUT_DIR=${DIR}/target
XCODE_PROJECT=${DIR}/FirebaseSimpleLogin.xcodeproj

echo "===> Cleaning target directory"
rm -rf $OUTPUT_DIR

echo "===> Building iOS binary"
xcodebuild \
  -project ${XCODE_PROJECT} \
  -target FirebaseSimpleLogin \
  -configuration Release \
  -sdk iphoneos \
  BUILD_DIR=${OUTPUT_DIR}/Products \
  OBJROOT=${OUTPUT_DIR}/Intermediates \
  BUILD_ROOT=${OUTPUT_DIR} \
  SYMROOT=${OUTPUT_DIR} \
  IPHONEOS_DEPLOYMENT_TARGET=7.0 \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="armv7 armv7s arm64" \
  build

echo "===> Building simulator binary"
xcodebuild \
  -project ${XCODE_PROJECT} \
  -target FirebaseSimpleLogin \
  -configuration Release \
  -sdk iphonesimulator \
  BUILD_DIR=${OUTPUT_DIR}/Products \
  OBJROOT=${OUTPUT_DIR}/Intermediates \
  BUILD_ROOT=${OUTPUT_DIR} \
  SYMROOT=${OUTPUT_DIR} \
  IPHONEOS_DEPLOYMENT_TARGET=7.0 \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="i386 x86_64" \
  build

echo "===> Using simulator binary as base project for headers and directory structure"
cp -a ${OUTPUT_DIR}/Products/Release-iphoneos ${OUTPUT_DIR}/Products/Release-combined

echo -n "===> Combining all binaries into one ..."
lipo \
  -create \
    ${OUTPUT_DIR}/Products/Release-iphoneos/libFirebaseSimpleLogin.a \
    ${OUTPUT_DIR}/Products/Release-iphonesimulator/libFirebaseSimpleLogin.a \
  -output ${OUTPUT_DIR}/Products/Release-combined/FirebaseSimpleLogin.framework/Versions/A/FirebaseSimpleLogin

echo -n "===> Checking how the final binary looks ..."
EXPECTEDCOUNT=6
ARCHCOUNT=$(file ${OUTPUT_DIR}/Products/Release-combined/FirebaseSimpleLogin.framework/Versions/A/FirebaseSimpleLogin | wc -l)
if [[ $ARCHCOUNT -ne $EXPECTEDCOUNT ]]; then
  echo " bad."
  file ${OUTPUT_DIR}/Products/Release-combined/Firebase.framework/Versions/A/Firebase
  echo "===> The architecture count ($ARCHCOUNT) looks wrong. It should be $EXPECTEDCOUNT.";
  exit 1
else
  echo " good."
fi

echo "===> Creating zip of final framework"
pushd ${OUTPUT_DIR}/Products/Release-combined
zip -ry ../../FirebaseSimpleLogin.framework.zip FirebaseSimpleLogin.framework
popd

ls -l ${OUTPUT_DIR}/FirebaseSimpleLogin.framework.zip
