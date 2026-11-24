.PHONY: audio-helper
audio-helper: audio/es9-helper

audio/es9-helper: audio/es9.m
	$(CC) -O2 -Wall -Wextra -fobjc-arc -framework Foundation -framework IOKit -framework IOUSBHost -framework CoreAudio $< -o $@.new
	mv $@.new $@
