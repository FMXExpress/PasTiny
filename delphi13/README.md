# Modern PasTiny for Delphi 13 and Free Pascal

Both projects run the original TINY.BIN network. TinyConsole is a native console application for Free Pascal and Delphi 13 Florence. TinyChat is a Delphi 13 VCL application for Windows with a question field and a conversation transcript. Each answer starts with a fresh model context.

## Delphi 13 on Windows

Open `TinyChat.dpr` or `TinyConsole.dpr` in the IDE, choose Windows 32-bit or Windows 64-bit and build. For a command-line build, use a RAD Studio command prompt in this folder and run `dcc64 -B TinyConsole.dpr` or `dcc64 -B TinyChat.dpr`. Use `dcc32` for Win32. Copy the repository’s `TINY.BIN` beside the resulting executable. TinyChat uses deterministic integer inference. Enter a question and press Enter or click **Ask**.

## Free Pascal on Linux

From the repository root, build the console with FPC 3.2.2 (the current stable release) in Delphi Unicode mode. [Free Pascal releases](https://www.freepascal.org/)

```sh
mkdir -p build/delphi13
(cd delphi13 && fpc -B -O2 -Mdelphiunicode -FU../build/delphi13 -FE../build/delphi13 TinyConsole.dpr)
cp TINY.BIN build/delphi13/
build/delphi13/TinyConsole 0
build/delphi13/TinyConsole /BENCH
build/delphi13/TinyConsole /FLOAT /BENCH
python3 delphi13/check.py build/delphi13/TinyConsole
```

The console reads standard input and writes standard output. Enter `quit` or send EOF to finish. Pass a creativity level from 0 to 9 (default 5), `/FLOAT` for floating-point inference, `/MODEL=path` for another compatible weights file, or `/IN=path` and `/OUT=path` for batch use. The default model path is relative to the executable. Explicit paths are relative to the current working directory.

The modern target shares the [Delphi 1 inference source](../delphi1/TNYNET.PAS). The modern build uses Unicode strings, reads the binary header as four bytes and stores quantized vectors as signed 16-bit values. The original Win16 neon UI and PC-speaker effects are available in the [Delphi 1 edition](../delphi1/).

The Linux x86-64 FPC build matched all 60 original C reference answers with both engines. Delphi 13 compilation and Windows GUI execution are pending verification on a RAD Studio installation. The same Python check accepts a Delphi-built TinyConsole.exe.
