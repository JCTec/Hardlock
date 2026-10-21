APP := build/Hardlock.app

.PHONY: app dmg run install clean

app:
	./scripts/build-app.sh

dmg:
	./scripts/make-dmg.sh

run: app
	open $(APP)

# Replaces any installed copy: quit it and remove it before copying the new build.
install: app
	-pkill -x Hardlock
	rm -rf /Applications/Hardlock.app
	cp -R $(APP) /Applications/

clean:
	rm -rf .build build
