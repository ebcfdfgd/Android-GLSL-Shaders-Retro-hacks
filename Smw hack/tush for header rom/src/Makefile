INSTALLDIR=/usr/local/bin

CPP=g++
WXCONFIG=wx-config
TARGET=tush

CFLAGS=-Os -pipe `$(WXCONFIG) --cflags`
LDFLAGS=-s
LIBS=`$(WXCONFIG) --libs`
OBJS=main.o wx_stuff.o addrem/addrem.o

$(TARGET): $(OBJS)
	$(CPP) $(LDFLAGS) -o $(TARGET) $(OBJS) $(LIBS)

main.o: main.cpp
	$(CPP) $(CFLAGS) -c -o main.o main.cpp

wx_stuff.o: wx_stuff.cpp
	$(CPP) $(CFLAGS) -c -o wx_stuff.o wx_stuff.cpp

addrem/addrem.o: addrem/addrem.cpp
	$(CPP) $(CFLAGS) -c -o addrem/addrem.o addrem/addrem.cpp

.PHONY: install uninstall clean clean-all

install: $(TARGET)
	install -Dm755 $(TARGET) $(INSTALLDIR)/$(TARGET)

uninstall:
	rm $(INSTALLDIR)/$(TARGET)

clean:
	rm -f $(OBJS)

clean-all: clean
	rm -f $(TARGET)

