
ALL_TEST_SRC = $(filter-out %~ %\# %.m, $(wildcard test/*))
XFAIL_TEST_SRC = $(shell grep -l xfail $(ALL_TEST_SRC))

RUN_TEST_SRC = $(filter-out $(XFAIL_TEST_SRC), $(ALL_TEST_SRC))

CXXFLAGS := -g -O2 -Irt

# Set up the flags to handle OpenCL
ifeq ($(shell uname), Darwin)
CXXFLAGS := $(CXXFLAGS) -framework OpenCL
CXX := g++-4.2
else
ifeq ($(shell uname), Linux)
# This should work on 64-bit Gentoo with NVIDIA GPUs at least. YMMV.
CXXFLAGS := $(CXXFLAGS) -I/opt/cuda/include -lOpenCL -lrt
CXX := g++
ECHO_ESCAPE := "-e"
else
$(error Your operating system is not yet supported.)
endif
endif

HARLAN_SRC = \
	harlanc \
	$(wildcard harlan/*) \
	$(wildcard harlan/front/*) \
	$(wildcard harlan/middle/*) \
	$(wildcard harlan/back/*) \
	util/verify-grammar.ss \

# Invokes the harlan compiler. The first argument is the name of the
# source file, the second is the name of the output file.
HC = ./harlanc $(1) | $(CXX) -x c++ - -x none rt/libharlanrt.a $(CXXFLAGS) \
     -o $(2)

TEST_EXE_NAME = $(patsubst test/%, test.bin/%.bin, $(1))

TEST_OUT_NAME = $(patsubst test/%, test.bin/%.out, $(1))

COMPILE_TEST = $(call HC, $(1), $(call TEST_EXE_NAME, $(1)))

RUN_TEST = $(1)

.phony: check
check : test.bin rt/libharlanrt.a update-submodules
	@./run-tests.scm
	@echo $(ECHO_ESCAPE) "\033[32mAll tests succeeded.\033[39m"

# Shorthands:
.phony: rt
rt: rt/libharlanrt.a


.phony: update-submodules
update-submodules: .gitmodules
	git submodule init
	git submodule update

.phony: force-check
force-check :
	rm -rf test.bin
	make -C . check

test.bin:
	mkdir -p test.bin

.phony: clean
clean:
	rm -rf test.bin *.dSYM gc
	make -C rt clean

test.bin/%.out : test.bin/%.bin
	@echo Running $<
	@$(call RUN_TEST, $(call TEST_EXE_NAME, $<)) > $@

.precious : $(call TEST_EXE_NAME, $(RUN_TEST_SRC))
test.bin/%.bin : test/% rt/libharlanrt.a $(HARLAN_SRC)
	@echo Compiling $<
	$(call COMPILE_TEST, $<)

rt/libharlanrt.a : rt/*.h rt/*.cpp rt/*.hpp
	make -C rt

.phony: docs
docs: update-submodules
	make -C doc
