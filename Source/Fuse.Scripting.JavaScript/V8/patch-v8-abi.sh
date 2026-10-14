#!/bin/sh
#
# Re-target the prebuilt V8 static libraries for an Android NDK newer than the one they were built
# with.
#
# The `v8-android-static` package (see android/v8-android-static.nuspec) was built with libc++'s
# "__Cr" ABI namespace, which Uno requests via _LIBCPP_ABI_NAMESPACE=__Cr (see V8Simple.cpp.uxl).
# NDK 21's libc++ honours that; newer NDKs ignore the macro and use "__ndk1" instead, so the one V8
# API whose mangled name contains a std type -- v8::platform::NewDefaultPlatform -- no longer
# matches, and linking fails with:
#
#   undefined symbol: v8::platform::NewDefaultPlatform(int, v8::platform::IdleTaskSupport,
#     v8::platform::InProcessStackDumping, std::__ndk1::unique_ptr<v8::TracingController, ...>)
#
# The machine-level ABI is identical (std::unique_ptr is a single pointer), so renaming the symbol
# inside the archive is enough.
#
# Where the libraries live:
#   * the package's own extraction:        V8/android/lib/<abi>/libv8.a
#   * the copy the app is built against:   Source/build/Fuse.Scripting.JavaScript/V8/android/lib
# Both are (re)created by extraction of the NuGet package, so this must run *after* they exist --
# which is why `prepack` invokes it (see package.json) and why it should be re-run after a fresh
# clone or a cleaned build directory.
#
# Note: V8 also bundles its own static libc++/libc++abi, which collides with a newer NDK's static
# copies (``duplicate symbol: __cxa_*`` / ``std::exception_ptr`` ...). Build with the shared NDK STL
# to avoid that, e.g.:
#
#   uno build -t android -s ndk.version=<new-ndk> -s STL=c++_shared
#
# Together, the patch and `STL=c++_shared` let a newer NDK (whose toolchain runs natively on Apple
# Silicon, unlike NDK 21's x86_64 one) build the app without Rosetta. Both become unnecessary once
# V8 itself is rebuilt with a modern NDK.
#
# Usage:
#   patch-v8-abi.sh [lib-dir]          # default: android/lib next to this script
#
# `llvm-objcopy` is taken from $OBJCOPY, else from PATH, else from a local Android NDK (found via
# $ANDROID_NDK / $ANDROID_HOME / $ANDROID_SDK_ROOT / the `android.sdk` setting in ~/.unoconfig).
# If it cannot be found, or there is nothing to patch, the script warns and exits successfully so it
# never fails a `prepack`.

DIR=${1:-"$(dirname "$0")/android/lib"}

OLD='_ZN2v88platform18NewDefaultPlatformEiNS0_15IdleTaskSupportENS0_21InProcessStackDumpingENSt4__Cr10unique_ptrINS_17TracingControllerENS3_14default_deleteIS5_EEEE'
NEW='_ZN2v88platform18NewDefaultPlatformEiNS0_15IdleTaskSupportENS0_21InProcessStackDumpingENSt6__ndk110unique_ptrINS_17TracingControllerENS3_14default_deleteIS5_EEEE'

find_objcopy()
{
	if [ -n "$OBJCOPY" ] && command -v "$OBJCOPY" >/dev/null 2>&1; then
		echo "$OBJCOPY"
		return 0
	fi

	if command -v llvm-objcopy >/dev/null 2>&1; then
		echo "llvm-objcopy"
		return 0
	fi

	SDK="$ANDROID_NDK"
	[ -n "$SDK" ] || SDK="$ANDROID_HOME"
	[ -n "$SDK" ] || SDK="$ANDROID_SDK_ROOT"
	if [ -z "$SDK" ] && [ -f "$HOME/.unoconfig" ]; then
		SDK=$(sed -n 's/^android\.sdk:[[:space:]]*//p' "$HOME/.unoconfig" | head -1 | sed 's/[[:space:]]*$//')
	fi
	[ -n "$SDK" ] || SDK="$HOME/Library/Android/sdk"

	for candidate in $(ls -d "$SDK"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-objcopy 2>/dev/null | sort -r); do
		if [ -x "$candidate" ]; then
			echo "$candidate"
			return 0
		fi
	done

	[ -x "$SDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-objcopy" ] &&
		{ echo "$SDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-objcopy"; return 0; }

	return 1
}

OBJCOPY_BIN=$(find_objcopy)
if [ -z "$OBJCOPY_BIN" ]; then
	echo "patch-v8-abi: skipped -- llvm-objcopy not found (set OBJCOPY or ANDROID_NDK to patch V8 for a newer NDK)" >&2
	exit 0
fi

found=0
for lib in "$DIR"/*/libv8.a; do
	[ -f "$lib" ] || continue
	found=1
	if ! "$OBJCOPY_BIN" --redefine-sym "$OLD=$NEW" "$lib"; then
		echo "patch-v8-abi: failed to patch $lib" >&2
		exit 1
	fi
done

if [ "$found" -eq 0 ]; then
	echo "patch-v8-abi: skipped -- no libv8.a under '$DIR' (nothing extracted yet)" >&2
	exit 0
fi

echo "patch-v8-abi: patched libv8.a under $DIR"
