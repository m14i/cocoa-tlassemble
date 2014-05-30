#-------Target and Source-------#
TARGET = tlassemble
SRC = $(TARGET).m

#-------Compiler Flags-------#
CFLAGS = -mmacosx-version-min=10.9
CFLAGS += -framework Foundation
CFLAGS += -framework AppKit
CFLAGS += -framework AVFoundation
CFLAGS += -framework CoreVideo
CFLAGS += -framework CoreMedia

DEBUG = -D DEBUG

all:
	clang $(CFLAGS) $(SRC) -o $(TARGET)

debug:
	clang $(DEBUG) $(CFLAGS) $(SRC) -o $(TARGET)
