cmake_minimum_required(VERSION 3.15)

# 单一 project，包含 ASM（启动文件需要）
project(stm32_proj C ASM)

set(CMAKE_C_STANDARD 11)

# ===== 路径设置 =====
set(PROJ_ROOT ${CMAKE_SOURCE_DIR})
set(DRIVERS   ${PROJ_ROOT}/Drivers)
set(MCU_ROOT  ${PROJ_ROOT}/mcu)
set(MCU_INC   ${MCU_ROOT}/inc)
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

# --- 如果启用了 FreeRTOS（main.c 里包含 cmsis_os.h），加入 FreeRTOS 头文件 ---
if(EXISTS "${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS")
  include_directories(
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/include
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM7/r0p1
  )
endif()



# ===== 源文件收集 =====
# HAL 源码（可按需精简）
file(GLOB HAL_SRCS ${DRIVERS}/STM32F7xx_HAL_Driver/Src/*.c)

# 启动/系统/用户源码
file(GLOB STARTUP_S ${MCU_STUP}/startup_stm32f746*.s)

set(MCU_SRCS
  ${HAL_SRCS}
  ${MCU_SYS}/system_stm32f7xx.c
  ${MCU_SRC}/main.c
)

# 可选的中断源（有就编，没有就忽略）
if(EXISTS "${MCU_SRC}/stm32f7xx_it.c")
  list(APPEND MCU_SRCS ${MCU_SRC}/stm32f7xx_it.c)
endif()

# ===== FreeRTOS 源码（仅当目录存在时接入）=====
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
    ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FreeRTOS/Source/portable/MemMang/heap_4.c  # 按 CubeMX 选择的 heap3/4/5 调整
  )
  # 如果你把 freertos.c 拷进了 mcu/src，也把它加进来：
  if(EXISTS "${MCU_SRC}/freertos.c")
    list(APPEND FREERTOS_SRC ${MCU_SRC}/freertos.c)
  endif()
endif()

# ===== 生成 MCU 可执行文件 =====
add_executable(app.elf
  ${MCU_SRCS}
  ${FREERTOS_SRC}
  ${STARTUP_S}
)

# 设备/HAL 宏（必要）
target_compile_definitions(app.elf PRIVATE USE_HAL_DRIVER STM32F746xx)


# ===== FATFS 接线（仅当目录存在时启用）=====
set(FATFS_DIR ${CMAKE_SOURCE_DIR}/Middlewares/Third_Party/FatFs)
set(FATFS_APP ${CMAKE_SOURCE_DIR}/FATFS/App)
set(FATFS_TGT ${CMAKE_SOURCE_DIR}/FATFS/Target)

if(EXISTS "${FATFS_DIR}" AND EXISTS "${FATFS_APP}")
  message(STATUS "Enable FATFS")

  include_directories(
    ${FATFS_DIR}/src
    ${FATFS_APP}
    ${FATFS_TGT}
  )

  set(FATFS_SRC
    ${FATFS_DIR}/src/ff.c
    ${FATFS_DIR}/src/ff_gen_drv.c
    ${FATFS_DIR}/src/diskio.c
  )

  # 可选：如果存在 syscall.c / ffunicode.c / option 目录等，也并入
  if(EXISTS "${FATFS_DIR}/src/option/syscall.c")
    list(APPEND FATFS_SRC ${FATFS_DIR}/src/option/syscall.c)
  endif()
  if(EXISTS "${FATFS_DIR}/src/ffunicode.c")
    list(APPEND FATFS_SRC ${FATFS_DIR}/src/ffunicode.c)
  endif()

  # App & Target（CubeMX 生成）
  if(EXISTS "${FATFS_APP}/fatfs.c")
    list(APPEND FATFS_SRC ${FATFS_APP}/fatfs.c)
  endif()
  # 介质驱动：根据你 CubeMX 选择的存储介质启用其 .c
  foreach(_drv IN ITEMS user_diskio.c sd_diskio.c usb_diskio.c)
    if(EXISTS "${FATFS_TGT}/${_drv}")
      list(APPEND FATFS_SRC ${FATFS_TGT}/${_drv})
    endif()
  endforeach()

  target_sources(app.elf PRIVATE ${FATFS_SRC})
endif()

# ===== USB Host 接线（仅当目录存在时启用）=====
set(USBH_DIR ${CMAKE_SOURCE_DIR}/Middlewares/ST/STM32_USB_Host_Library)
set(USBH_APP ${CMAKE_SOURCE_DIR}/USB_HOST/App)
set(USBH_TGT ${CMAKE_SOURCE_DIR}/USB_HOST/Target)

if(EXISTS "${USBH_DIR}" AND EXISTS "${USBH_APP}")
  message(STATUS "Enable USB Host")

  # Core 头文件
  include_directories(${USBH_DIR}/Core/Inc)

  # Class 头文件（自动把存在的 Class/*/Inc 全部加进来）
  file(GLOB USBH_CLASS_INC_DIRS ${USBH_DIR}/Class/*/Inc)
  if(USBH_CLASS_INC_DIRS)
    include_directories(${USBH_CLASS_INC_DIRS})
  endif()

  # App/Target 头文件
  include_directories(${USBH_APP} ${USBH_TGT})

  # Core 源码
  set(USBH_SRC
    ${USBH_DIR}/Core/Src/usbh_core.c
    ${USBH_DIR}/Core/Src/usbh_ctlreq.c
    ${USBH_DIR}/Core/Src/usbh_ioreq.c
  )

  # Class 源码（自动收集现有的类，如 MSC/HID/CDC等）
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

  target_sources(app.elf PRIVATE ${USBH_SRC})
endif()


# CPU/FPU/Thumb 选项（注意写成多个参数，而不是带空格的一个字符串）
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
  --specs=nosys.specs              # 提供弱系统调用桩，避免再缺 _exit/_close 等
  -Wl,--gc-sections
  -Wl,--print-memory-usage
  -Wl,-Map=app.map                  # 生成映射表，方便排查未定义/重定义
)


# 链接脚本（尽量用确切文件名；如果你的文件名不同，改成实际名字）
set(LD_SCRIPT ${MCU_LD}/STM32F746XX_FLASH.ld)
if(NOT EXISTS "${LD_SCRIPT}")
  message(FATAL_ERROR "Linker script not found at: ${LD_SCRIPT}")
endif()
target_link_options(app.elf PRIVATE -T${LD_SCRIPT})

# 产物（objdump/objcopy 需能在 PATH，或在 toolchain 文件里设 CMAKE_OBJDUMP/CMAKE_OBJCOPY）
add_custom_command(TARGET app.elf POST_BUILD
  COMMAND ${CMAKE_OBJDUMP} -h -S app.elf > app.list
  COMMAND ${CMAKE_OBJCOPY} -O ihex app.elf app.hex
  COMMAND ${CMAKE_OBJCOPY} -O binary app.elf app.bin
  COMMENT "Generating list/hex/bin"
)

# =====（可选）Host 侧小测试：仅在非交叉编译时构建 =====
if(NOT CMAKE_CROSSCOMPILING AND EXISTS "${CMAKE_SOURCE_DIR}/tests/main.c")
  add_executable(host_test ${CMAKE_SOURCE_DIR}/tests/main.c)
  message(STATUS "Building host test executable")
endif()

