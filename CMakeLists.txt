cmake_minimum_required(VERSION 3.15)
project(stm32_proj C)

# Set C standard
set(CMAKE_C_STANDARD 11)

# Check if we're cross-compiling for ARM
if(CMAKE_CROSSCOMPILING AND CMAKE_SYSTEM_NAME STREQUAL "Generic")
    # ARM cross-compilation: build static library only
    add_library(stm32_proj STATIC src/main.c)
    message(STATUS "Building ARM static library")
else()
    # Host compilation: build executable for testing
    add_executable(host_test "${CMAKE_SOURCE_DIR}/tests/main.c")
    message(STATUS "Building host test executable")
endif()
