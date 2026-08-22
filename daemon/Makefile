CC=gcc

CFLAGS=-Wall -Wextra -O2 -fPIC -pthread
LDFLAGS=-pthread

PREFIX=/usr/local
BIN_DIR=$(PREFIX)/bin
CONF_DIR=/etc/zenbook-duo

GTK_FLAGS=
GTK_LIB=

SRCS=src/main.c
OBJS=$(SRCS:.c=.o)

all: zenbook-duo zenbook-sendkey

zenbook-duo: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^ $(GTK_LIB)

zenbook-sendkey: src/zenbook-sendkey.c
	$(CC) $(CFLAGS) -o $@ $<

%.o: %.c
	$(CC) $(CFLAGS) $(GTK_FLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) zenbook-duo zenbook-sendkey

install: all
	mkdir -p $(CONF_DIR)
	cp -f conf/zenbook-duo.conf $(CONF_DIR)/
	install -m 755 zenbook-duo $(BIN_DIR)/
	install -m 755 zenbook-sendkey $(BIN_DIR)/
	@echo "Installed. Run: zenbook-duo daemon"

uninstall:
	rm -f $(BIN_DIR)/zenbook-duo
	rm -f $(BIN_DIR)/zenbook-sendkey
	rm -rf $(CONF_DIR)

.PHONY: all clean install uninstall
