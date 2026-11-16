FPC ?= fpc
CC ?= gcc
FLAGS = -Mtp -O2 -B

.PHONY: all host float debug test go32v2 go32v2-float test-dos clean
all: host
host:
	mkdir -p build/int
	$(FPC) $(FLAGS) -FUbuild/int -FEbuild/int -oTINY TINY.PAS
float:
	mkdir -p build/float
	$(FPC) $(FLAGS) -dFLOATMATH -FUbuild/float -FEbuild/float -oTINY TINY.PAS
debug:
	mkdir -p build/debug
	$(FPC) $(FLAGS) -dDEBUG -FUbuild/debug -FEbuild/debug -oTINY TINY.PAS
test:
	FPC="$(FPC)" CC="$(CC)" sh tests/run_host.sh
go32v2:
	mkdir -p build/dos
	$(FPC) -Tgo32v2 -Mtp -O3 -Cp80386 -XX -Xs -B -FUbuild/dos -FEbuild/dos -oTINY.EXE TINY.PAS
go32v2-float:
	mkdir -p build/dosfloat
	$(FPC) -Tgo32v2 -Mtp -O3 -Cp80386 -XX -Xs -B -dFLOATMATH -FUbuild/dosfloat -FEbuild/dosfloat -oTNYFLT.EXE TINY.PAS
test-dos:
	sh tests/run_dos.sh
clean:
	rm -rf build
