APP_NAME = app_amp_xmos_poc

TARGET = amp_xmos_poc.xn

# The flags passed to xcc when building the application
XCC_FLAGS	= -O3 -report \
			  -g -Wno-unused-function \
			  -DXUD_CORE_CLOCK=600 \
			  -DUSB_TILE=tile[0] \
			  -fxscope \
			  -DUAC_FORCE_FEEDBACK_EP=1

XCC_CPP_FLAGS = $(XCC_FLAGS) -std=c++11 -Wno-missing-braces
			  
# The USED_MODULES variable lists other module used by the application. These
# modules will extend the SOURCE_DIRS, INCLUDE_DIRS and LIB_DIRS variables.
# Modules are expected to be in the directory above the BASE_DIR directory.
USED_MODULES = lib_xua lib_xud lib_i2c

EXCLUDE_FILES = demo_tuning.yaml

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
