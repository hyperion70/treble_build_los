#!/bin/bash
echo ""
echo "LineageOS 17.x Treble Buildbot"
echo "ATTENTION: this script syncs repo on each run"
echo "Executing in 5 seconds - CTRL-C to exit"
echo ""
sleep 5

START=`date +%s`
BUILD_DATE="$(date +%Y%m%d)"
BL=$PWD/treble_build_los

echo "Preparing local manifest"
mkdir -p .repo/local_manifests
cp $BL/manifest.xml .repo/local_manifests/manifest.xml
echo ""

echo "Syncing repos"
repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
echo ""

echo "Setting up build environment"
source build/envsetup.sh &> /dev/null
echo ""

echo "Reverting LOS FOD implementation"
cd frameworks/base
git am $BL/patches/0001-Squashed-revert-of-LOS-FOD-implementation.patch
cd ../..
cd frameworks/native
git revert 470dde656e0ee547f78ac403a6f959e1438c2158 --no-edit # surfaceflinger: Add support for extension lib
cd ../..
cd vendor/lineage
git revert 612c5a846ea5aed339fe1275c119ee111faae78c --no-edit # soong: Add flag for fod extension
cd ../..
echo ""

echo "Applying PHH patches"
rm -f device/*/sepolicy/common/private/genfs_contexts
bash ~/treble_experimentations/apply-patches.sh treble_patches
echo ""

echo "Applying universal patches"
cd frameworks/base
git am $BL/patches/0001-UI-Revive-navbar-layout-tuning-via-sysui_nav_bar-tun.patch
git am $BL/patches/0001-Disable-vendor-mismatch-warning.patch
git am $BL/patches/0001-core-Add-support-for-MicroG.patch
git am $BL/patches/0001-frameworks_base_services_PhoneWindowManager.patch
cd ../..
cd lineage-sdk
git am $BL/patches/0001-sdk-Invert-per-app-stretch-to-fullscreen.patch
cd ..
cd packages/apps/LineageParts
git am $BL/patches/0001-LineageParts-Invert-per-app-stretch-to-fullscreen.patch
cd ../../..
cd vendor/lineage
git am $BL/patches/0001-vendor_lineage-Log-privapp-permissions-whitelist-vio.patch
cd ../..
echo ""

echo "Applying GSI-specific patches"
cd build/make
git am $BL/patches/0001-build-Don-t-handle-apns-conf.patch
cd ../..
cd external/tinycompress
git revert 82c8fbf6d3fb0a017026b675adf2cee3f994e08a --no-edit # tinycompress: Use generated kernel headers
cd ../..
cd frameworks/native
git revert 581c22f979af05e48ad4843cdfa9605186d286da --no-edit # Add suspend_resume trace events to the atrace 'freq' category.
cd ../..
cd hardware/lineage/interfaces
git am $BL/patches/0001-cryptfshw-Remove-dependency-on-generated-kernel-head.patch
cd ../../..
cd system/hardware/interfaces
git revert 5c145c49cc83bfe37c740bcfd3f82715ee051122 --no-edit # system_suspend: start early
cd ../../..
cd system/sepolicy
git revert d12551bf1a6e8a9ece6bbb98344a27bde7f9b3e1 --no-edit # sepolicy: Relabel wifi. properties as wifi_prop
cd ../..
cd vendor/lineage
git am $BL/patches/0001-build_soong-Disable-generated_kernel_headers.patch
cd ../hardware_overlay
git am $BL/patches/0001-phh_hardware_overlay.patch
cd ../..
echo ""

echo "CHECK PATCH STATUS NOW!"
sleep 5
echo ""

export WITHOUT_CHECK_API=true
export WITH_SU=true
mkdir -p ~/build-output/

buildVariant() {
	lunch ${1}-userdebug
	make installclean
	make -j$(nproc --all) systemimage
	make vndk-test-sepolicy
	mv $OUT/system.img ~/build-output/lineage-17.1-$BUILD_DATE-UNOFFICIAL-${1}.img
}

buildVariant treble_arm64_bgN
ls ~/build-output | grep 'lineage'

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))
echo "Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo ""
