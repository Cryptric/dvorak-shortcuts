#pkg-config from: https://www.geany.org/manual/gtk/glib/glib-compiling.html
#https://github.com/joprietoe/gdbus/blob/master/Makefile
#https://stackoverflow.com/questions/51269129/minimal-gdbus-client
TARGET = dvorak
CC = gcc

PKG_FLAGS = $(shell pkg-config --cflags --libs libsystemd dbus-1)

CFLAGS = -Wall -O3
LIBS = $(PKG_FLAGS) -lpthread

SRCS = dvorak.c dvorak_dbus.c
OBJS = $(SRCS:.c=.o)

.PHONY: default all clean install uninstall

default: all

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(LIBS)

%.o: %.c dvorak_dbus.h
	$(CC) $(CFLAGS) $(shell pkg-config --cflags libsystemd dbus-1) -c $< -o $@

clean:
	-rm -f *.o
	-rm -f $(TARGET)

install:
	mkdir -p ~/.dvorak
	cp dvorak ~/.dvorak/dvorak

uninstall:
	rm /usr/local/bin/dvorak
	rm /etc/udev/rules.d/80-dvorak.rules
	rm /etc/systemd/system/dvorak@.service
	udevadm control --reload
	systemctl restart systemd-udevd.service
	systemctl daemon-reload
