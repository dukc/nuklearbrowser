You will need the same shared object binaries as when building
https://github.com/Timu5/bindbc-nuklear/tree/master/demo, the
application this example is based on. Static and dynamic configurations
are not used here - BindBC is always used in dynamic configuration.

For convenience in POSIX systems, `./lib` is added to the executable RPATH
after compilation. This means that you can make a `lib` directory and dump your
`nuklear.so` there, if you do not want to install it globally.

For some reason, building with DMD won't work on Linux at least. It will
initialize Nuklear without error, but crash on first Nuklear function call.
Use LDC (Or try GDC, I have not tested it). Even DMD calls SDL2 and OpenGL
correctly though. Perhaps I have built my own Nuklear.so wrong. Any insights
on this are welcome.

You may find the `sdlbindings.d` source file useful for other purposes of using
D with Nuklear. As of writing, the bindings are closer to idiomatic D than in
the BindBC example.
