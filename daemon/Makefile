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

all: zenbook-duo

zenbook-duo: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^ $(GTK_LIB)

%.o: %.c
	$(CC) $(CFLAGS) $(GTK_FLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) zenbook-duo

install: all
	sudo mkdir -p $(CONF_DIR)
	sudo cp -f conf/zenbook-duo.conf $(CONF_DIR)/
	sudo install -m 755 zenbook-duo $(BIN_DIR)/
	@echo "Installed. Run: zenbook-duo daemon"

uninstall:
	sudo rm -f $(BIN_DIR)/zenbook-duo
	sudo rm -rf $(CONF_DIR)

.PHONY: all clean install uninstall