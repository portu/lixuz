# This makefile is included into any other Makefiles contained
# within subdirectories of the 3rdparty-libs directory.
# 
# It contains generic targets used by those Makefiles.

REPO_ROOT=$(shell [ -e "../../../../lixuz.yml.tpl" ]  && echo "../../../../" || echo "../../../")
default:
	@echo "*** This is not a normal makefile, use \"make buildjs\" in the root directory of the Lixuz tree ***"
include $(REPO_ROOT)/script/Makefiles/build
build:
	@cd $(REPO_ROOT) && make buildjs
buildjs_sub:
	@$(JS_BUILDER) $(CUSTOM_ORDER) > $(JS_TARGET_DIR)/$(OUTFILE)
