cmake_minimum_required(VERSION 3.10)
project(stbtt_hdll C)

set(CMAKE_C_STANDARD 99)

# Locate HashLink headers (hl.h) and the libhl import library.
#
# Pass -DHASHLINK_DIR=<path> to point at your HashLink install or source tree:
#   Windows: the unzipped HashLink release dir (contains hl.h or include/hl.h
#            and libhl.lib), e.g. -DHASHLINK_DIR="C:/HashLink"
#   macOS:   auto-detected from a Homebrew install if HASHLINK_DIR is unset.
if(NOT DEFINED HASHLINK_INCLUDE_DIR)
	if(DEFINED HASHLINK_DIR AND EXISTS "${HASHLINK_DIR}/include/hl.h")
		set(HASHLINK_INCLUDE_DIR "${HASHLINK_DIR}/include")
	elseif(DEFINED HASHLINK_DIR AND EXISTS "${HASHLINK_DIR}/hl.h")
		set(HASHLINK_INCLUDE_DIR "${HASHLINK_DIR}")
	elseif(EXISTS "/usr/local/include/hl.h")
		set(HASHLINK_INCLUDE_DIR "/usr/local/include")
	elseif(EXISTS "/opt/homebrew/include/hl.h")
		set(HASHLINK_INCLUDE_DIR "/opt/homebrew/include")
	else()
		message(FATAL_ERROR "hl.h not found; pass -DHASHLINK_DIR=<hashlink install/source dir>")
	endif()
endif()

# HDLLs link against libhl. On Windows this is the libhl.lib import library
# shipped with the HashLink release; on macOS it sits next to the headers.
find_library(HL_LIB
	NAMES hl libhl
	PATHS
		"${HASHLINK_DIR}"
		"${HASHLINK_DIR}/lib"
		/usr/local/lib
		/opt/homebrew/lib
	REQUIRED)

add_library(stbtt MODULE stbtt_hl.c)
target_include_directories(stbtt PRIVATE ${HASHLINK_INCLUDE_DIR})
target_link_libraries(stbtt PRIVATE ${HL_LIB})
set_target_properties(stbtt PROPERTIES
	PREFIX ""
	SUFFIX ".hdll")
