import std;

int main()
{   import bindbc.sdl;
    import bindbc.opengl;
    import bindbc.nuklear;
    import nuklearbrowser;
    import sdlbindings;

    auto windowSize = staticArray([800, 600]);

    switch (loadSDL)
    {   case sdlSupport: break;
        case SDLSupport.badLibrary:
			writeln("SDL2-kirjasto (.so or .dll) only partially loaded. Most probably too old version of it.");
			return 1;
        default:
			writeln("Could not find SDL2 library! (.so or .dll)");
			return 1;
    }
    if (not(loadNuklear == NuklearSupport.Nuklear4))
    {	writeln("Nuklear library (.so or .dll) missing");
		return 1;
	}
    if (SDL_Init(SDL_INIT_VIDEO|SDL_INIT_TIMER|SDL_INIT_EVENTS) == -1)
    {	writeln(text("Error: failed to init SDL: ", SDL_GetError().fromStringz));
		return 1;
	}
	
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    auto window = SDL_CreateWindow
    (	"Nuklear file browser",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		windowSize[0], windowSize[1],
		SDL_WINDOW_OPENGL|SDL_WINDOW_SHOWN|SDL_WINDOW_RESIZABLE
	);
	
    SDL_GLContext glContext =  SDL_GL_CreateContext(window);
    if (not(loadOpenGL))
    {	writeln("OpenGL functions did not load. Graphics driver likely does not support OpenGL (is it out of date, or are you using MacOS?).");
		return 1;
	}
    SDL_GL_SetSwapInterval(1);
    glViewport(0, 0, windowSize[0], windowSize[1]);

    auto guiStatus = makeNkSdl(window);

    nk_font_atlas *atlas;
    guiStatus.atlas.beginFontStash;
    guiStatus.endFontStash;
    nk_style_default(&guiStatus.ctx);

	nk_colorf bg;
	bg.r = 0.10f, bg.g = 0.18f, bg.b = 0.24f, bg.a = 1.0f;
	
	auto browserMedia = new Media;
	if (true)
	{	Icons icons =
		{	home: loadIcon("icon/home.png"),
			directory: loadIcon("icon/directory.png"),
			workingDirectory: loadIcon("icon/workingdirectory.png"),
			root: loadIcon("icon/root.png"),
			defaultFile: loadIcon("icon/default.png"),
			textFile: loadIcon("icon/text.png"),
			musicFile: loadIcon("icon/music.png"),
			fontFile:  loadIcon("icon/font.png"),
			imgFile: loadIcon("icon/image.png"),
		};
		*browserMedia = icons.makeMedia;
	}
    
    scope(exit)
    {	guiStatus.shutdown();
		SDL_GL_DeleteContext(glContext);
		SDL_DestroyWindow(guiStatus.win);
		SDL_Quit();
	}
	
	auto browser = makeFileBrowser(*browserMedia).nullable;

    eventloop: while (browser.hasValue)
    {   SDL_Event evt;
        (&guiStatus.ctx).nk_input_begin;
        while (SDL_PollEvent(&evt)) {
            if (evt.type == SDL_QUIT) break eventloop;
            guiStatus.handleEvent(&evt);
        }
        (&guiStatus.ctx).nk_input_end;
		
		nk_begin
		(	&guiStatus.ctx, "File Browser",
			nk_rect(0, 0, windowSize[0], windowSize[1]),
			NK_WINDOW_BACKGROUND
		);
		
		if(not
		(	browser.get.run(guiStatus.ctx).visit!
			(	(bool x){if(x) writeln("Browser closed"); return !x;},
				(const(char)[] x){writeln("file chosen: ", x); return false;}
			)
		))	browser.nullify;
		
		nk_end(&guiStatus.ctx);
        
        SDL_GetWindowSize(guiStatus.win, &windowSize[0], &windowSize[1]);
        glViewport(0, 0, windowSize[0], windowSize[1]);
        glClear(GL_COLOR_BUFFER_BIT);
        glClearColor(bg.r, bg.g, bg.b, bg.a);
        /* IMPORTANT: `nk_sdl_render` modifies some global OpenGL state
        * with blending, scissor, face culling, depth test and viewport and
        * defaults everything back into a default state.
        * Make sure to either a.) save and restore or b.) reset your own state after
        * rendering the UI. */
        guiStatus.render(NK_ANTI_ALIASING_ON, 512*1024, 128*1024);
        SDL_GL_SwapWindow(guiStatus.win);
    }
    
    return 0;
}

//////////////////////////////////
//random utility stuff
private:

bool not(V)(V v) if (is(typeof(cast(bool)v)))
{   return !cast(bool)v;
}

bool hasValue(NullableType)(NullableType nullableValue) if (isInstanceOf!(Nullable, NullableType))
{	return !nullableValue.isNull;
}
bool hasValue(FloatingType)(FloatingType nullableValue) if (isFloatingPoint!(FloatingType))
{	return !nullableValue.isNaN;
}
nothrow @nogc pure @safe bool hasValue(scope const(void)* nullableValue)
{	return nullableValue !is null;
}
