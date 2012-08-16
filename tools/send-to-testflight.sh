#!/bin/bash --

PROJECT_NAME="Wammer-iOS"
TF_API_TOKEN="267d14b54906a94ec9b58d775a4641e0_OTkxODY"
TF_TEAM_TOKEN="2e0589c9a03560bfeb93e215fdd9cbbb_MTg2ODAyMDExLTA5LTIyIDA0OjM4OjI1LjMzNTEyNg"

VERSION_MARKETING="`agvtool mvers -terse1`"
VERSION_BUILD="`agvtool vers -terse`"
COMMIT_SHA="`git rev-parse HEAD`"

BUILD_CONFIGURATION="Release"
BUILD_SDK="iphoneos"
SYMROOT="Deploy"
PRODUCT_NAME="$PROJECT_NAME.app"
TARGET_NAME="wammer-iOS"

IPA_NAME=build/$BUILD_CONFIGURATION-$BUILD_SDK/wammer-iOS-$BUILD_CONFIGURATION-$VERSION_MARKETING$'\n'$VERSION_BUILD.ipa
DSYM_ZIP_NAME=build/$BUILD_CONFIGURATION-$BUILD_SDK/wammer-iOS-$BUILD_CONFIGURATION-$VERSION_MARKETING$'\n'$VERSION_BUILD-dSYM.zip

GIT_INFO="` git log --oneline --format="- %h %s (%an)" HEAD...`expr $GIT_LATEST_TAG - 1` | grep -v "Merge branch" `"

git tag $VERSION_BUILD
git push origin $VERSION_BUILD

TF_API_URI="http://testflightapp.com/api/builds.json"
TF_NOTES="$PROJECT_NAME $VERSION_MARKETING ($VERSION_BUILD) # $COMMIT_SHA\n$GIT_INFO"
TF_NOTIFY="True"
TF_DIST_LISTS="Developer"

curl  http://testflightapp.com/api/builds.json \
     -F file=@"$IPA_NAME" \
     -F dsym=@"$DSYM_ZIP_NAME" \
     -F api_token="$TF_API_TOKEN" \
     -F team_token="$TF_TEAM_TOKEN" \
     -F notes="$TF_NOTES" \
     -F notify="$TF_NOTIFY" \
     -F distribution_lists="$TF_DIST_LISTS"