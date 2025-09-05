set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_CXX_COMPILER arm-none-eabi-g++)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# STM32F746 (Cortex-M7 + single-precision FPU)
#set(MCPU_FLAGS -mcpu=cortex-m7 -mthumb -mfloat-abi=hard -mfpu=fpv5-sp-d16)

# add_compile_options(${MCPU_FLAGS} -ffunction-sections -fdata-sections -Wall -Wextra)
#add_link_options(${MCPU_FLAGS} -Wl,--gc-sections -Wl,--print-memory-usage --specs=nano.specs)
