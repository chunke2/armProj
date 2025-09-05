cmake_minimum_required(VERSION 3.15)
project(stm32_proj C)
# project(stm32f746_app C CXX ASM)   # 要包含 ASM 语言

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

# ===== STM32F746 MCU target (CubeMX + CMake) =====
set(PROJ_ROOT ${CMAKE_SOURCE_DIR})
set(DRIVERS   ${PROJ_ROOT}/Drivers)
set(MCU_ROOT  ${PROJ_ROOT}/mcu)
set(MCU_INC   ${MCU_ROOT}/inc)
set(MCU_SRC   ${MCU_ROOT}/src)
set(MCU_SYS   ${MCU_ROOT}/system)
set(MCU_STUP  ${MCU_ROOT}/startup)
set(MCU_LD    ${MCU_ROOT}/linker)

include_directories(
  ${DRIVERS}/CMSIS/Include
  ${DRIVERS}/CMSIS/Device/ST/STM32F7xx/Include
  ${DRIVERS}/STM32F7xx_HAL_Driver/Inc
  ${MCU_INC}
)

# HAL 源码
file(GLOB HAL_SRCS ${DRIVERS}/STM32F7xx_HAL_Driver/Src/*.c)

# 启动/系统/用户源码
file(GLOB STARTUP_S ${MCU_STUP}/startup_stm32f746*.s)
set(SRCS
  ${HAL_SRCS}
  ${MCU_SYS}/system_stm32f7xx.c
  ${MCU_SRC}/main.c
  ${MCU_SRC}/stm32f7xx_it.c         # 若不存在可以删除这一行
  ${STARTUP_S}
)

# 链接脚本
file(GLOB LD_SCRIPT ${MCU_LD}/STM32F746*FLASH*.ld)

add_executable(app.elf ${SRCS})

# === CPU/FPU/Thumb 选项（F746: Cortex-M7 + 单精度FPU） ===
set(MCPU_FLAGS "-mcpu=cortex-m7 -mthumb -mfloat-abi=hard -mfpu=fpv5-sp-d16")

# 作用到 C/C++/ASM 编译和链接（target 作用域，最可靠）
target_compile_options(app.elf PRIVATE ${MCPU_FLAGS} -ffunction-sections -fdata-sections -Wall -Wextra)
target_link_options(app.elf    PRIVATE ${MCPU_FLAGS} -Wl,--gc-sections -Wl,--print-memory-usage --specs=nano.specs)




# 关键宏（没有这些会编译不过）
target_compile_definitions(app.elf PRIVATE USE_HAL_DRIVER STM32F746xx)

# 链接脚本与产物
target_link_options(app.elf PRIVATE -T${LD_SCRIPT})
add_custom_command(TARGET app.elf POST_BUILD
  COMMAND ${CMAKE_OBJDUMP} -h -S app.elf > app.list
  COMMAND ${CMAKE_OBJCOPY} -O ihex app.elf app.hex
  COMMAND ${CMAKE_OBJCOPY} -O binary app.elf app.bin
  COMMENT "Generating list/hex/bin"
)
