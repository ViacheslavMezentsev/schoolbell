CC ?= cc
AR ?= ar
CFLAGS ?= -Os
BUILD ?= ../../../out/native-schoolbell-player
WARN = -std=c99 -Wall -Wextra -Werror -pedantic
.PHONY: all
all: $(BUILD)/libschoolbell-player.a
$(BUILD):
	mkdir -p "$@"
$(BUILD)/player.o: player.c player.h | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARN) -c player.c -o "$@"
$(BUILD)/libschoolbell-player.a: $(BUILD)/player.o
	$(AR) rcs "$@" "$<"

# Optional host Lua 5.1 module. It is not installed into the package payload.
LUA_CFLAGS ?= -I/usr/include/lua5.1
.PHONY: lua
lua: $(BUILD)/schoolbell/player_linux.so $(BUILD)/schoolbell/media_linux.so $(BUILD)/schoolbell/clock_linux.so
$(BUILD)/schoolbell/player_linux.so: player.c player.h player_lua.c | $(BUILD)
	mkdir -p "$(BUILD)/schoolbell"
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARN) $(LUA_CFLAGS) -fPIC -shared player.c player_lua.c -lm -o "$@"

$(BUILD)/schoolbell/media_linux.so: media_lua.c | $(BUILD)
	mkdir -p "$(BUILD)/schoolbell"
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARN) $(LUA_CFLAGS) -fPIC -shared media_lua.c -lm -o "$@"

$(BUILD)/schoolbell/clock_linux.so: clock_lua.c | $(BUILD)
	mkdir -p "$(BUILD)/schoolbell"
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARN) $(LUA_CFLAGS) -fPIC -shared clock_lua.c -lm -o "$@"
