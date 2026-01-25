#@author Fred Brooker <git@gscloud.cz>
COUNT_REV := $(shell git rev-list --count HEAD)
DATE_REV := $(shell date +%Y%m%d)
HASH_REV := $(shell git rev-parse --short=8 HEAD)
GIT_REV := $(DATE_REV)-$(HASH_REV)
TIMESTAMP := $(shell date +%Y-%m-%d)
STEMS_DIR := stems

all:
	@echo "backup | build | clear | db | img";
	@echo "macro: everything";

clear:
	@-find ./cache/ -type f -mmin +3600 -delete -print 2> /dev/null || true
	@-find ./cache/ -type f -mmin +1600 2> /dev/null \
		| head -n 2000 \
		| shuf \
		| head -n 30 \
		| xargs -d '\n' -r rm -f || true

build:
	@echo "Building app ..."
	@cd go/ && go build -o koopi .

backup:
	@echo "Making backup ..."
	@rclone copy -P --exclude '.git/**' --exclude 'cache/' --exclude 'export/' . gsc:koopi2/

db: build
	@cd go/ && ./koopi
	@cp go/koopi.json ./data.json
	@mkdir -p $(STEMS_DIR)
	@cp data.json $(STEMS_DIR)/data_$(TIMESTAMP).json
	@printf '{\n  "count": "%s",\n  "date": "%s",\n  "hash": "%s",\n  "version": "%s"\n}\n' \
		"$(COUNT_REV)" "$(DATE_REV)" "$(HASH_REV)" "$(GIT_REV)" > meta.json

img:
	@echo "Converting images ..."
	@cd images && find . -type f \( -name "*.jpg" -o -name "*.png" \) -print0 | xargs -0 -P $(shell nproc) -I {} sh -c ' \
		INPUT="$$1"; \
		OUTPUT=$${INPUT%.*}.webp; \
		if [ "$$INPUT" -nt "$$OUTPUT" ] || [ ! -f "$$OUTPUT" ]; then \
			convert "$$INPUT" -quality 80 "$$OUTPUT"; \
		fi \
	' _ {}
	@cd markets-v2 && find . -type f \( -name "*.jpg" -o -name "*.png" \) -print0 | xargs -0 -P $(shell nproc) -I {} sh -c ' \
		INPUT="$$1"; \
		OUTPUT=$${INPUT%.*}.webp; \
		if [ "$$INPUT" -nt "$$OUTPUT" ] || [ ! -f "$$OUTPUT" ]; then \
			convert "$$INPUT" -quality 80 "$$OUTPUT"; \
		fi \
	' _ {}

# macros
everything: clear db img cf backup
	@-git add -A
	@-git commit -am 'automatic update'
	@-git push origin master

cf:
#	@echo "Building version: $(GIT_REV)"
#	@mkdir -p export/images export/markets-v2
#	@cd export && git pull origin master --allow-unrelated-histories || true
#	@rsync -aq --delete --exclude='.git' export-template/ export/
#	@rsync -aq --delete images/*.webp export/images/
#	@rsync -aq --delete markets-v2/*.webp export/markets-v2/
#	@cp index.html export/
#	@cp manifest.json export/
#	@cp meta.json export/
#	@cp sw.js export/
#	@cp go/koopi.json export/data.json
#	@sed -i 's/{{GIT_REV}}/$(GIT_REV)/g' ./export/sw.js
#	@sed -i 's/{{COUNT_REV}}/$(COUNT_REV)/g' ./export/index.html
#	@sed -i 's/{{DATE_REV}}/$(DATE_REV)/g' ./export/index.html
#	@sed -i 's/{{GIT_REV}}/$(GIT_REV)/g' ./export/index.html
#	@cd export && git add -A
#	@cd export && git commit -m 'automatic update: $$(date)' || true
#	@cd export && git push origin master
