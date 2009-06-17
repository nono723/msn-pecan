CC := gcc
XGETTEXT := xgettext
MSGFMT := msgfmt

PLATFORM := $(shell uname -s)

PURPLE_CFLAGS := $(shell pkg-config --cflags purple)
PURPLE_LIBS := $(shell pkg-config --libs purple)
PURPLE_LIBDIR := $(shell pkg-config --variable=libdir purple)
PURPLE_DATADIR := $(shell pkg-config --variable=datadir purple)

GOBJECT_CFLAGS := $(shell pkg-config --cflags gobject-2.0)
GOBJECT_LIBS := $(shell pkg-config --libs gobject-2.0)

# default configuration options
CVR := y
LIBSIREN := y
PLUS_SOUNDS := y
DEBUG := y

CFLAGS := -O2

ifdef DEBUG
  CFLAGS += -ggdb
endif

EXTRA_WARNINGS := -Wall -Wextra -Wformat-nonliteral -Wcast-align -Wpointer-arith \
	-Wbad-function-cast -Wmissing-prototypes -Wstrict-prototypes \
	-Wmissing-declarations -Winline -Wundef -Wnested-externs -Wcast-qual \
	-Wshadow -Wwrite-strings -Wno-unused-parameter -Wfloat-equal -ansi -std=c99

SIMPLE_WARNINGS := -Wextra -ansi -std=c99 -Wno-unused-parameter

OTHER_WARNINGS := -D_FORTIFY_SOURCE=2 -fstack-protector -g3 -Wdisabled-optimization \
	-Wendif-labels -Wformat=2 -Wstack-protector -Wswitch

CFLAGS += -Wall # $(EXTRA_WARNINGS)

override CFLAGS += -D_XOPEN_SOURCE
override CFLAGS += -I. -D GETTEXT_PACKAGE='"libmsn-pecan"' -DENABLE_NLS -DHAVE_LIBPURPLE -DPURPLE_DEBUG -D PLUGIN_NAME='msn-pecan'

ifdef CVR
  override CFLAGS += -DPECAN_CVR
endif

ifndef DO_NOT_USE_PSM
  override CFLAGS += -DPECAN_USE_PSM
endif

ifdef LIBSIREN
  override CFLAGS += -DPECAN_LIBSIREN
  LIBSIREN_LIBS := -lm
endif

ifdef PLUS_SOUNDS
  override CFLAGS += -DRECEIVE_PLUS_SOUNDS
endif

# extra debugging
override CFLAGS += -DPECAN_DEBUG_SLP

# For glib < 2.6 support (libpurple maniacs)
FALLBACK_CFLAGS := -I./fix_purple

LDFLAGS := -Wl,--no-undefined

plugin_dir := $(DESTDIR)/$(PURPLE_LIBDIR)/purple-2
data_dir := $(DESTDIR)/$(PURPLE_DATADIR)

objects := msn.o \
	   nexus.o \
	   notification.o \
	   page.o \
	   session.o \
	   switchboard.o \
	   sync.o \
	   pecan_log.o \
	   pecan_printf.o \
	   pecan_util.o \
	   pecan_error.o \
	   pecan_status.o \
	   pecan_oim.o \
	   pecan_ud.o \
	   cmd/cmdproc.o \
	   cmd/command.o \
	   cmd/history.o \
	   cmd/msg.o \
	   cmd/table.o \
	   cmd/transaction.o \
	   io/pecan_buffer.o \
	   io/pecan_parser.o \
	   ab/pecan_group.o \
	   ab/pecan_contact.o \
	   ab/pecan_contactlist.o \
	   io/pecan_stream.o \
	   io/pecan_node.o \
	   io/pecan_cmd_server.o \
	   io/pecan_http_server.o \
	   io/pecan_ssl_conn.o \
	   fix_purple.o

ifdef CVR
  objects += cvr/slp.o \
	     cvr/slpcall.o \
	     cvr/slplink.o \
	     cvr/slpmsg.o \
	     cvr/slpsession.o \
	     cvr/pecan_slp_object.o

endif

ifdef SOCKET
  objects += io/pecan_socket.o
  override CFLAGS += -DPECAN_SOCKET
endif

ifdef DIRECTCONN
  objects += directconn.o
  override CFLAGS += -DMSN_DIRECTCONN
endif

ifdef LIBSIREN
  objects += lib/libsiren/common.o \
	     lib/libsiren/dct4.o \
	     lib/libsiren/decoder.o \
	     lib/libsiren/huffman.o \
	     lib/libsiren/rmlt.o \
	     pecan_siren7.o
endif

sources := $(objects:.o=.c)
deps := $(objects:.o=.d)

PO_TEMPLATE := po/messages.pot
CATALOGS := ar da de es fi tr hu it nb nl pt_BR pt sr sv tr zh_CN zh_TW

ifeq ($(PLATFORM),Darwin)
  SHLIBEXT := dylib
else
ifeq ($(PLATFORM),win32)
  SHLIBEXT := dll
  LDFLAGS := -Wl,--enable-auto-image-base -Wl,--exclude-libs=libintl.a
  objects += win32/resource.res
else
  SHLIBEXT := so
endif
endif

ifdef STATIC
  plugin := libmsn-pecan.a
  override CFLAGS += -DPURPLE_STATIC_PRPL
else
  plugin := libmsn-pecan.$(SHLIBEXT)
ifneq ($(PLATFORM),win32)
  override CFLAGS += -fPIC
endif
endif

.PHONY: clean

all: $(plugin)

version := $(shell ./get-version.sh)

# from Lauri Leukkunen's build system
ifdef V
  Q = 
  P = @printf "" # <- space before hash is important!!!
else
  P = @printf "[%s] $@\n" # <- space before hash is important!!!
  Q = @
endif

plugin_libs := $(PURPLE_LIBS) $(GOBJECT_LIBS)

ifdef LIBSIREN
  plugin_libs += $(LIBSIREN_LIBS)
endif

$(plugin): $(objects)
$(plugin): CFLAGS := $(CFLAGS) $(PURPLE_CFLAGS) $(GOBJECT_CFLAGS) $(FALLBACK_CFLAGS) -D VERSION='"$(version)"'
$(plugin): LIBS := $(plugin_libs)

%.dylib::
	$(P)DYLIB
	$(Q)$(CC) $(LDFLAGS) -dynamiclib -o $@ $^ $(LIBS)

%.dll::
	$(P)SHLIB
	$(Q)$(CC) $(LDFLAGS) -shared -o $@ $^ $(LIBS)

%.so::
	$(P)SHLIB
	$(Q)$(CC) $(LDFLAGS) -shared -o $@ $^ $(LIBS)

%.a::
	$(P)ARCHIVE
	$(Q)(AR) rcs $@ $^

%.o:: %.c
	$(P)CC
	$(Q)$(CC) $(CFLAGS) -MMD -o $@ -c $<

%.res:: %.rc
	$(WINDRES) $< -O coff -o $@

clean:
	find -name '*.mo' -delete
	rm -f $(plugin) $(objects) $(deps)

po:
	mkdir -p $@

$(PO_TEMPLATE): $(sources) | po
	$(XGETTEXT) -kmc --keyword=_ --keyword=N_ -o $@ $(sources)

dist:
	git archive --format=tar --prefix=msn-pecan-$(version)/ HEAD > /tmp/msn-pecan-$(version).tar
	mkdir -p msn-pecan-$(version)
	git-changelog > msn-pecan-$(version)/ChangeLog
	chmod 664 msn-pecan-$(version)/ChangeLog
	tar --append -f /tmp/msn-pecan-$(version).tar --owner root --group root msn-pecan-$(version)/ChangeLog
	echo $(version) > msn-pecan-$(version)/version
	chmod 664 msn-pecan-$(version)/version
	tar --append -f /tmp/msn-pecan-$(version).tar --owner root --group root msn-pecan-$(version)/version
	rm -r msn-pecan-$(version)
	bzip2 /tmp/msn-pecan-$(version).tar

install: $(plugin)
	mkdir -p $(plugin_dir)
	install $(plugin) $(plugin_dir)
	# chcon -t textrel_shlib_t $(plugin_dir)/$(plugin) # for selinux

%.mo:: %.po
	$(MSGFMT) -c -o $@ $<

install_locales: $(foreach e,$(CATALOGS),po/libmsn-pecan-$(e).mo)
	for x in $(CATALOGS); do \
	install -D po/libmsn-pecan-$$x.mo $(data_dir)/locale/$$x/LC_MESSAGES/libmsn-pecan.mo; \
	done

-include $(deps)
