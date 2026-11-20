# Modern PasTiny for Delphi 13 and Free Pascal

All three projects run the original TINY.BIN network. TinyConsole is a native console application for Free Pascal and Delphi 13 Florence. TinyChat is a Delphi 13 VCL application for Windows with a question field and a conversation transcript. TinyChatFMX provides a FireMonkey chat window with a form you can edit in the RAD Studio designer. Each answer starts with a fresh model context.

## Delphi 13 on Windows

Open `TinyChat.dpr` or `TinyConsole.dpr` in the IDE, choose Windows 32-bit or Windows 64-bit and build. For a command-line build, use a RAD Studio command prompt in this folder and run `dcc64 -B TinyConsole.dpr` or `dcc64 -B TinyChat.dpr`. Use `dcc32` for Win32. Copy the repository’s `TINY.BIN` beside the resulting executable. TinyChat uses deterministic integer inference. Enter a question and press Enter or click **Ask**.

## Delphi 13 FireMonkey

Open `TinyChatFMX.dpr` in RAD Studio and choose your installed FireMonkey target. The project shares its inference engine with TinyChat and uses deterministic integer inference. Add the repository’s `TINY.BIN` to the selected platform’s deployment, preserving the uppercase filename.

| Target | Model location |
| --- | --- |
| Windows | Copy beside the compiled `TinyChatFMX.exe`. |
| macOS | Deploy to `Contents/Resources/TINY.BIN` in the application bundle. |
| Android | Use the Deployment Manager remote path `assets\internal`. Delphi’s startup copy places the model in the app’s documents directory. |
| iOS | Use the Deployment Manager remote path `StartUp\Documents`. |

Run the app, enter `what is the capital of peru` and press **Ask** or Enter. The expected answer is `Lima.`. If loading fails, the transcript shows the model path and error.

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

The modern target shares the [Delphi 1 inference source](../delphi1/TNYNET.PAS). The modern build uses Unicode strings, reads the binary header as four bytes and stores quantized vectors as signed 16-bit values. The original Win16 neon UI is available in the [Delphi 1 edition](../delphi1/).

The Linux x86-64 FPC build matched all 60 original C reference answers with both engines. Delphi 13 compilation and VCL/FireMonkey GUI execution are pending verification on a RAD Studio installation. The same Python check accepts a Delphi-built TinyConsole.exe.

## Robot voice

VCL and FireMonkey play each completed answer as square-wave robot chatter. Clear **Sound** to stop playback and mute subsequent answers. The console opts in with `/SOUND` and waits for each answer to finish playing. Benchmarks stay silent. On Linux install ALSA’s `aplay` or FFmpeg’s `ffplay`. Windows uses the system audio output and FireMonkey uses its platform media player.

## Neural monitor

The VCL and FireMonkey chat windows stream the answer and show each layer’s activity relative to its recent peak. The confidence meter tracks the latest emitted character. The strip underneath keeps the last 18 character confidences, with denser shading for higher confidence. This measures character prediction, so even a confidently generated answer can be factually wrong. The panel also displays generation speed in letters per second, model dimensions, and creativity.
