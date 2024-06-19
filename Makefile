#pkg-config from: https://www.geany.org/manual/gtk/glib/glib-compiling.html
#https://github.com/joprietoe/gdbus/blob/master/Makefile
#https://stackoverflow.com/questions/51269129/minimal-gdbus-client
TARGET = dvorak
CC = gcc
CFLAGS = -Wall -O3

.PHONY: default all clean install uninstall

default: all

all: dvorak.c
	$(CC) $(CFLAGS) -o $(TARGET) dvorak.c

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
