BUILD_PATH=.build
SWIFT_BUILD_FLAGS=--product CommandLineTool --configuration release --disable-sandbox --scratch-path ${BUILD_PATH}

EXECUTABLE_X86_64=$(shell swift build ${SWIFT_BUILD_FLAGS} --arch x86_64 --show-bin-path)/CommandLineTool
EXECUTABLE_ARM64=$(shell swift build ${SWIFT_BUILD_FLAGS} --arch arm64 --show-bin-path)/CommandLineTool
EXECUTABLE=${BUILD_PATH}/CommandLineTool

clean:
	@swift package clean

build_x86_64:
	@swift build ${SWIFT_BUILD_FLAGS} --arch x86_64

build_arm64:
	@swift build ${SWIFT_BUILD_FLAGS} --arch arm64

build_release: clean build_x86_64 build_arm64
	@lipo -create -output ${EXECUTABLE} ${EXECUTABLE_X86_64} ${EXECUTABLE_ARM64}
	@strip -rSTX ${EXECUTABLE}

show_bin_path:
	@echo ${EXECUTABLE}