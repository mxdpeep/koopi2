#@author Fred Brooker <git@gscloud.cz>

COUNT_REV := $(shell git rev-list --count HEAD)
DATE_REV := $(shell date +%Y%m%d)
HASH_REV := $(shell git rev-parse --short=8 HEAD)
GIT_REV := $(DATE_REV)-$(HASH_REV)
TIMESTAMP := $(shell date +%Y-%m-%d)
STEMS_DIR := stems

all:
	@echo "backup | build | hashmap | clear | db | img | cf"
	@echo "macro: everything"

clear:
	@-find ./cache/ -type f -mmin +4000 -delete 2> /dev/null || true
	@-find ./cache/ -type f -mmin +2000 2> /dev/null \
		| shuf \
		| head -n 100 \
		| xargs -d '\n' -r rm -f || true

build:
	@echo "Building koopi ..."
	@cd go/ && go build -mod=vendor -o koopi .
	@echo "Building imgconv ..."
	@cd go/imgconv && go build -mod=vendor -o imgconv .
	@cp go/imgconv/imgconv ./imgconv

img:
	@echo "Converting images ..."
	@./imgconv

hashmap:
	@echo "Generating hashmap ..."
	@find ./stems -name "data_2026-*.json" -print0 | xargs -0 cat | jq -cs \
		'reduce .[] as $$file ({};($$file.idhashmap // {}) as $$local_map | reduce ($$file.goods[] ? | select(.id != null)) as $$item (.;($$local_map[$$item.id | tostring]) as $$global_hash | if $$global_hash then .[$$global_hash] = {image: $$item.image, name: $$item.name, volume: $$item.volume} else . end))' > ./hashmap.json
	@echo "Created hashmap with $$(jq 'length' ./hashmap.json) unique items."

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

cf:
	@echo "Building version: $(GIT_REV)"
	@mkdir -p export/images export/markets-v2
#	@cd export && git pull origin master --allow-unrelated-histories || true

	@rsync -aq --delete --exclude='.git' export-template/ export/
	@rsync -aq --delete images/*.webp export/images/
	@rsync -aq --delete markets-v2/*.webp export/markets-v2/

	@cp index.html export/
	@cp manifest.json export/
	@cp hashmap.json export/
	@cp meta.json export/
	@cp go/koopi.json export/data.json
	@cp sw.js export/

	@sed -i 's/{{DEPT}}/drugs/g' ./export/index.html
	@sed -i 's/{{COUNT_REV}}/$(COUNT_REV)/g' ./export/index.html
	@sed -i 's/{{DATE_REV}}/$(DATE_REV)/g' ./export/index.html
	@sed -i 's/{{GIT_REV}}/$(GIT_REV)/g' ./export/index.html
	@sed -i 's/{{GIT_REV}}/$(GIT_REV)/g' ./export/sw.js

#	@cd export && git add -A
#	@cd export && git commit -m 'automatic update: $$(date)' || true
#	@cd export && git push origin master

everything: clear db img hashmap cf backup
	@-git add -A
	@-git commit -am 'automatic update'
	@-git push origin master
