REPO_ROOT=$(shell [ -e "../../../../lixuz.yml.tpl" ]  && echo "../../../../" || echo "../../../")
default:
	@echo "*** This is not a normal makefile, use \"make buildjs\" in the root directory of the Lixuz tree ***"
include $(REPO_ROOT)/script/Makefiles/build
buildjs_sub:
	[ -e "yui.built.js" ] || wget "http://yui.yahooapis.com/combo?2.8.0r4/build/yahoo-dom-event/yahoo-dom-event.js&2.8.0r4/build/dragdrop/dragdrop-min.js&2.8.0r4/build/element/element-min.js&2.8.0r4/build/resize/resize-min.js&2.8.0r4/build/imagecropper/imagecropper-min.js" -O yui.built.js
	@$(JS_BUILDER) "yui.built.js" > $(JS_TARGET_DIR)/$(OUTFILE)
