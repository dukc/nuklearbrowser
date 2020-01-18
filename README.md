This is a simple local file browser for the backend-agnostic
[Nuklear](https://github.com/Immediate-Mode-UI/Nuklear) GUI library. It
is a [D](https://dlang.org) translation (with some major changes) from
[example file of the original library](https://github.com/Immediate-Mode-UI/Nuklear/blob/master/example/file_browser.c).
Interfacing is handled by [BindBC-Nuklear](https://github.com/Timu5/bindbc-nuklear).

The file browser is currently primitive. It should work, but you'll likely
want to use it only as a base for your own modification. Known limitations:

* Can only search the current drive -no going to explore your USB stick
* Cannot follow (nor open) link files
* Long texts do not warp
* Limited images for different file types
* Almost guaranteed to have serious bugs

Currently tested on 64bit Linux and [Wine](https://www.winehq.org/) as 32bit.
Boost Licensed.
