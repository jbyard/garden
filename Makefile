SQL          := $(sort $(wildcard sql/*.sql))
SRC          := $(sort $(wildcard src/*))
WWW          := /var/www/html/garden

.PHONY: test install sql src

install: sql src $(WWW)/.env.php

sql: $(SQL)
	for file in $^; do \
		psql -qX postgresql://${PGUSER}@localhost/${PGDATABASE} < $${file}; \
	done;

src: $(SRC) 
	sudo mkdir -p $(WWW)
	for file in $^; do \
		sudo cp $${file} $(WWW)/; \
	done;

$(WWW)/.env.php:
	sudo bash -c " \
	sed '0,/REPLACEME/{s/REPLACEME/${PGDATABASE}/}' env.php |\
	sed '1,/REPLACEME/{s/REPLACEME/${PGUSER}/}' |\
	sed '2,/REPLACEME/{s/REPLACEME/${PGPASSWORD}/}' > $@ "
