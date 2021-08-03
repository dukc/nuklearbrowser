This is a simple local file browser for the backend-agnostic
[Nuklear](https://github.com/Immediate-Mode-UI/Nuklear) GUI library. It
is a [D](https://dlang.org) translation (with some major changes) from
[example file of the original library](https://github.com/Immediate-Mode-UI/Nuklear/blob/master/example/file_browser.c).
Interfacing is handled by [BindBC-Nuklear](https://github.com/Timu5/bindbc-nuklear).

This is a library, not an application. It is used simply by including the source
in your Nuklear application and calling the functions - see `example` directory.
Note that this is not a `-betterC` library - you will need full DRuntime.
In principle, you should be able to use it regardless of the Nuklear backend.
In practice, I have only tested it with the backend at the example directory.
You can run unittests without writing any extra code with `dub test`. Currently
this does not require the Nuklear binary, but this may change in future.

The file browser is currently primitive. It should work, but you'll likely
want to use it only as a base for your own modification. Known limitations:

* Can only search the current drive -no going to explore your USB stick
* Long texts do not warp
* Likely to have serious bugs

Currently tested on 64bit Linux and [Wine](https://www.winehq.org/) as 32bit.
Boost Licensed.
