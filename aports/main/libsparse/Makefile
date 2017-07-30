INC_DIR=include
CFLAGS=-Werror -I$(INC_DIR)
LDFLAGS=-lz
CC=gcc
PROGS=append2simg img2simg simg2img simg2simg
SOURCES=backed_block.c output_file.c sparse.c sparse_crc32.c sparse_err.c sparse_read.c
OBJECTS=$(SOURCES:.c=.o)

all: $(PROGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

append2simg: $(OBJECTS)
	$(CC) $(CFLAGS) $@.c $(OBJECTS) $(LDFLAGS) -o $@

img2simg: $(OBJECTS)
	$(CC) $(CFLAGS) $@.c $(OBJECTS) $(LDFLAGS) -o $@

simg2img: $(OBJECTS)
	$(CC) $(CFLAGS) $@.c $(OBJECTS) $(LDFLAGS) -o $@

simg2simg: $(OBJECTS)
	$(CC) $(CFLAGS) $@.c $(OBJECTS) $(LDFLAGS) -o $@

clean:
	rm -f *.o $(PROGS)
