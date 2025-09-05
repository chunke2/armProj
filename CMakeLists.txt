cmake_minimum_required(VERSION 3.15)

# 单一 project，包含 ASM（启动文件需要）
project(stm32_proj C ASM)

# 让 Ninja 使用响应文件，避免 Windows 命令行过长/引号问题
set(CMAKE_NINJA_FORCE_RESPONSE_FILE ON)

set(CMAKE_C_STANDARD 11)

# ===== 路径设置 =====
set(PROJ_ROOT ${CMAKE_SOURCE_DIR})
set(DRIVERS   ${PROJ_ROOT}/Drivers)
set(MCU_ROOT  ${PROJ_ROOT}/mcu)
set(MCU_INC   ${MCU_ROOT}/Inc)
set(MCU_SRC   ${MCU_ROOT}/src)
set(MCU_SYS   ${MCU_ROOT}/system)
set(MCU_STUP  ${MCU_ROOT}/startup)
set(MCU_LD    ${MCU_ROOT}/linker)

# ===== 头文件路径 =====
include_directories(
  ${DRIVERS}/CMSIS/Include
  ${DRIVERS}/CMSIS/Device/ST/STM32F7xx/Include
  ${DRIVERS}/STM32F7xx_HAL_Driver/Inc
  ${MCU_INC}
)

# --- 可选：FreeRTOS 头 ---
if(EXISTS "${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS")
  include_directories(
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/include
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM7/r0p1
  )
endif()

# ===== 源文件收集 =====
# HAL 源码
file(GLOB HAL_SRCS ${DRIVERS}/STM32F7xx_HAL_Driver/Src/*.c)

# 启动/系统/用户源码
file(GLOB STARTUP_S ${MCU_STUP}/startup_stm32f746*.s)

# collect all user MCU C sources (CubeMX generates many peripheral .c files in ${MCU_SRC})
file(GLOB MCU_USER_C_SRCS "${MCU_SRC}/*.c")
# avoid duplicating main.c if it's added explicitly elsewhere
list(REMOVE_ITEM MCU_USER_C_SRCS "${MCU_SRC}/main.c")
list(APPEND MCU_USER_C_SRCS "${MCU_SRC}/main.c")

# If CubeMX-generated files exist under the workspace (e.g. "CubeMX files/<proj>/Core/Src"),
# automatically include their sources and include directories so generated MX_* functions
# and peripheral handles are compiled into the app. This avoids needing to copy files.
set(CUBEMX_BASE "${CMAKE_SOURCE_DIR}/../../CubeMX files")
if(EXISTS "${CUBEMX_BASE}")
  file(GLOB CUBEMX_CORE_SRCS "${CUBEMX_BASE}/*/Core/Src/*.c")
  if(CUBEMX_CORE_SRCS)
    message(STATUS "Found CubeMX Core/Src files at: ${CUBEMX_BASE}")
    # Exclude files that we already provide in project (to prevent multiple definitions)
    list(REMOVE_ITEM CUBEMX_CORE_SRCS
      "${CUBEMX_BASE}/test1/Core/Src/main.c"
      "${CUBEMX_BASE}/test1/Core/Src/freertos.c"
      "${CUBEMX_BASE}/test1/Core/Src/stm32f7xx_it.c"
      "${CUBEMX_BASE}/test1/Core/Src/system_stm32f7xx.c"
      "${CUBEMX_BASE}/test1/Core/Src/syscalls.c"
      "${CUBEMX_BASE}/test1/Core/Src/sysmem.c"
    )
    list(APPEND MCU_USER_C_SRCS ${CUBEMX_CORE_SRCS})
  endif()

  # Add CubeMX Core/Inc include directories if present
  file(GLOB CUBEMX_CORE_INC_DIRS "${CUBEMX_BASE}/*/Core/Inc")
  if(CUBEMX_CORE_INC_DIRS)
    include_directories(${CUBEMX_CORE_INC_DIRS})
  endif()

  # Also add any CubeMX Drivers/*/Inc folders (device/HAL headers created by CubeMX)
  file(GLOB CUBEMX_DRV_INC_DIRS "${CUBEMX_BASE}/*/Drivers/*/Inc")
  if(CUBEMX_DRV_INC_DIRS)
    include_directories(${CUBEMX_DRV_INC_DIRS})
  endif()
endif()

set(MCU_SRCS
  ${HAL_SRCS}
  ${MCU_SYS}/system_stm32f7xx.c
  ${MCU_USER_C_SRCS}
)

if(EXISTS "${MCU_SRC}/stm32f7xx_it.c")
  list(APPEND MCU_SRCS ${MCU_SRC}/stm32f7xx_it.c)
endif()

# ===== FreeRTOS 源码（若存在）=====
set(FREERTOS_SRC)
if(EXISTS "${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS")
  list(APPEND FREERTOS_SRC
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/list.c
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/queue.c
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/tasks.c
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/timers.c
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/event_groups.c
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/stream_buffer.c
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS/cmsis_os.c
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM7/r0p1/port.c
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/portable/MemMang/heap_4.c
  )
  if(EXISTS "${MCU_SRC}/freertos.c")
    list(APPEND FREERTOS_SRC ${MCU_SRC}/freertos.c)
  endif()
endif()

# ===== FATFS 接线（若存在）=====
set(FATFS_DIR ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FatFs)
set(FATFS_APP ${CMAKE_SOURCE_DIR}/FATFS/App)
set(FATFS_TGT ${CMAKE_SOURCE_DIR}/FATFS/Target)
set(FATFS_SRC)
if(EXISTS "${FATFS_DIR}" AND EXISTS "${FATFS_APP}")
  include_directories(
    ${FATFS_DIR}/src
    ${FATFS_APP}
    ${FATFS_TGT}
  )
  list(APPEND FATFS_SRC
    ${FATFS_DIR}/src/ff.c
    ${FATFS_DIR}/src/ff_gen_drv.c
    ${FATFS_DIR}/src/diskio.c
  )
  if(EXISTS "${FATFS_DIR}/src/option/syscall.c")
    list(APPEND FATFS_SRC ${FATFS_DIR}/src/option/syscall.c)
  endif()
  if(EXISTS "${FATFS_DIR}/src/ffunicode.c")
    list(APPEND FATFS_SRC ${FATFS_DIR}/src/ffunicode.c)
  endif()
  if(EXISTS "${FATFS_APP}/fatfs.c")
    list(APPEND FATFS_SRC ${FATFS_APP}/fatfs.c)
  endif()
  foreach(_drv IN ITEMS user_diskio.c sd_diskio.c usb_diskio.c bsp_driver_sd.c)
    if(EXISTS "${FATFS_TGT}/${_drv}")
      list(APPEND FATFS_SRC ${FATFS_TGT}/${_drv})
    endif()
  endforeach()
  # Also include optional platform helper from FATFS Target (contains BSP_PlatformIsDetected)
  if(EXISTS "${FATFS_TGT}/fatfs_platform.c")
    list(APPEND FATFS_SRC ${FATFS_TGT}/fatfs_platform.c)
  endif()
endif()

# ===== USB Host 接线（若存在）=====
set(USBH_DIR ${CMAKE_SOURCE_DIR}/Middlewares/ST/STM32_USB_Host_Library)
set(USBH_APP ${CMAKE_SOURCE_DIR}/USB_HOST/App)
set(USBH_TGT ${CMAKE_SOURCE_DIR}/USB_HOST/Target)
set(USBH_SRC)

if(EXISTS "${USBH_DIR}" AND EXISTS "${USBH_APP}")
  include_directories(${USBH_DIR}/Core/Inc ${USBH_APP} ${USBH_TGT})
  file(GLOB USBH_CLASS_INC_DIRS ${USBH_DIR}/Class/*/Inc)
  if(USBH_CLASS_INC_DIRS)
    include_directories(${USBH_CLASS_INC_DIRS})
  endif()

  # Core 必要源码（注意包含 usbh_pipes.c）
  list(APPEND USBH_SRC
    ${USBH_DIR}/Core/Src/usbh_core.c
    ${USBH_DIR}/Core/Src/usbh_ctlreq.c
    ${USBH_DIR}/Core/Src/usbh_ioreq.c
    ${USBH_DIR}/Core/Src/usbh_pipes.c
  )
  # Class 源码（自动收集）
  file(GLOB USBH_CLASS_SRCS ${USBH_DIR}/Class/*/Src/*.c)
  list(APPEND USBH_SRC ${USBH_CLASS_SRCS})
  # App & Target
  if(EXISTS "${USBH_APP}/usb_host.c")
    list(APPEND USBH_SRC ${USBH_APP}/usb_host.c)
  endif()
  foreach(_f IN ITEMS usbh_conf.c usbh_platform.c usbh_storage_if.c usbh_diskio.c)
    if(EXISTS "${USBH_TGT}/${_f}")
      list(APPEND USBH_SRC ${USBH_TGT}/${_f})
    endif()
  endforeach()
endif()

# ===== 交叉编译时的目标选择 =====
if(CMAKE_CROSSCOMPILING)
  # 当 CMAKE_TRY_COMPILE_TARGET_TYPE 设为 STATIC_LIBRARY 时，创建静态库（用于 CI 验证）
  if(CMAKE_TRY_COMPILE_TARGET_TYPE STREQUAL "STATIC_LIBRARY")
    # 创建静态库，仅包含核心源码（去除启动文件和链接器依赖）
    add_library(armlib STATIC
      ${HAL_SRCS}
      ${MCU_SYS}/system_stm32f7xx.c
      # 只包含可编译的 C 源码，去除 main.c 和启动文件
    )
    target_compile_definitions(armlib PRIVATE USE_HAL_DRIVER STM32F746xx)
    target_compile_options(armlib PRIVATE
      -mcpu=cortex-m7
      -mthumb
      -mfloat-abi=hard
      -mfpu=fpv5-sp-d16
      -ffunction-sections -fdata-sections -Wall -Wextra
    )
    # 确保 armlib 也能找到头文件
    target_include_directories(armlib PRIVATE
      ${DRIVERS}/CMSIS/Include
      ${DRIVERS}/CMSIS/Device/ST/STM32F7xx/Include
      ${DRIVERS}/STM32F7xx_HAL_Driver/Inc
      ${MCU_INC}
    )
    message(STATUS "Building ARM static library for CI")
  else()
    # 创建完整的可执行文件
    add_executable(app.elf
      ${MCU_SRCS}
      ${FREERTOS_SRC}
      ${FATFS_SRC}
      ${USBH_SRC}
      ${STARTUP_S}
    )

    # 设备/HAL 宏（必要）
    target_compile_definitions(app.elf PRIVATE USE_HAL_DRIVER STM32F746xx)

    # 自动把 syscalls.c/sysmem.c/retarget.c 并入（若存在）
    foreach(_f IN ITEMS syscalls.c sysmem.c retarget.c)
      if(EXISTS "${MCU_SRC}/${_f}")
        target_sources(app.elf PRIVATE ${MCU_SRC}/${_f})
      endif()
    endforeach()

    # CPU/FPU/Thumb 选项（注意分成多个参数）
    target_compile_options(app.elf PRIVATE
      -mcpu=cortex-m7
      -mthumb
      -mfloat-abi=hard
      -mfpu=fpv5-sp-d16
      -ffunction-sections -fdata-sections -Wall -Wextra
    )

    target_link_options(app.elf PRIVATE
      -mcpu=cortex-m7
      -mthumb
      -mfloat-abi=hard
      -mfpu=fpv5-sp-d16
      --specs=nano.specs
      --specs=nosys.specs
      -Wl,--gc-sections
      -Wl,--print-memory-usage
      -Wl,-Map=app.map
    )

    # 链接脚本
    set(LD_SCRIPT ${MCU_LD}/STM32F746XX_FLASH.ld)
    if(NOT EXISTS "${LD_SCRIPT}")
      message(FATAL_ERROR "Linker script not found at: ${LD_SCRIPT}")
    endif()
    target_link_options(app.elf PRIVATE -T${LD_SCRIPT})

    # 链接数学库
    target_link_libraries(app.elf PRIVATE m)

    # 找 objcopy/objdump（用于生成 hex/bin/list）
    find_program(CMAKE_OBJCOPY arm-none-eabi-objcopy)
    find_program(CMAKE_OBJDUMP arm-none-eabi-objdump)

    # 产物
    add_custom_command(TARGET app.elf POST_BUILD
      COMMAND ${CMAKE_OBJDUMP} -h -S app.elf > app.list
      COMMAND ${CMAKE_OBJCOPY} -O ihex app.elf app.hex
      COMMAND ${CMAKE_OBJCOPY} -O binary app.elf app.bin
      COMMENT "Generating list/hex/bin"
    )
  endif()
endif()

# =====（可选）Host 侧小测试：仅在非交叉编译时构建 =====
if(NOT CMAKE_CROSSCOMPILING AND EXISTS "${CMAKE_SOURCE_DIR}/tests/main.c")
  add_executable(host_test ${CMAKE_SOURCE_DIR}/tests/main.c)
  message(STATUS "Building host test executable")
endif()
