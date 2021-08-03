import bindbc.nuklear;
import std;

private alias StringFilter = nothrow pure @safe bool delegate(const(char)[]);

struct Icons
{   nk_image home;
    nk_image root;
    nk_image directory;
    nk_image workingDirectory;
    nk_image defaultFile;

    nk_image[] files;
};

struct Media
{   int font;
    int icon_sheet;
    Icons icons;
    size_t[string] suffixIcons;
}


struct FileBrowser
{   const(char)[] home;
    const(char)[] directory;
    StringFilter suffixFilter;
    //no reactions to clicks during the first frame, to prevent
    //reactions to the same click that initiated the browser
    bool firstFrameExecuted;

    /* directory content */
    const(char)[][] files;
    const(char)[][] directories;
    Media* media;
}

private ref nk_image getFileIcon(return ref Media media, const(char)[] path)
{   if(auto iconId = path.extension in media.suffixIcons)
    {   return media.icons.files[*iconId];
    }
    return media.icons.defaultFile;
}

private void loadDirectory(ref FileBrowser browser, const(char)[] path)
{   browser.directory = path;
    auto directoryStuff= path.idup
    .dirEntries(SpanMode.shallow).map!(de => de.name)
    .array
    .fold!((string[][2] acc, string en)
    {   try acc[en.isDir] ~= en;
        catch(FileException){} //Most likely a broken symlink
        return acc;
    })(string[][2].init);

    browser.files=
    directoryStuff[0]
    .zip(browser.suffixFilter.repeat)
    .filter!(tupArg!((path, filt) => filt(path.extension)))
    .map!(x=>x[0].to!(const(char)[]))
    .array;
    browser.directories = directoryStuff[1].to!(const(char)[][]);

    browser.files.sort;
    browser.directories.sort;
}

FileBrowser makeFileBrowser(Icons icons, size_t[string] suffixMap,
    StringFilter suffixFilter = x => true)
{   import core.stdc.stdlib;
    FileBrowser browser;
    browser.media= new Media();
    browser.media.icons= icons;
    browser.media.suffixIcons= suffixMap;

    /* load files and sub-directory list */
    const(char)* home = getenv("HOME");
    if (!home)
    {   version (Windows) home = getenv("USERPROFILE");
        else version (Posix)
        {   import core.sys.posix.pwd, core.sys.posix.unistd;
            home = getpwuid(getuid()).pw_dir;
        }
    }

    browser.home = home.fromStringz ~ "/";
    browser.suffixFilter = suffixFilter;
    browser.loadDirectory(browser.home);
    return browser;
}

unittest
{   import std;

    auto browser = makeFileBrowser(Icons.init, size_t[string].init, s=>s.empty);
    browser.loadDirectory(getcwd.buildPath("testdir"));
    assert(browser.files.sort.map!baseName.equal(["file1", "file2", "link1"]));
    assert(browser.directories.map!baseName.equal(["dir1"]));
    assert(!browser.firstFrameExecuted);
}

//Return value:
//  false: browser still ongoing
//  true: browser closed
//  any string: file of that absolute path chosen
Algebraic!(bool, const(char)[]) run(ref FileBrowser browser, ref nk_context ctx)
{   typeof(return) result = false;
    immutable ratio = [0.25f, NK_UNDEFINED];
    float spacing_x = ctx.style.window.spacing.x;

    /* output path directory selector in the menubar */
    ctx.style.window.spacing.x = 0;
    nk_menubar_begin(&ctx);
    nk_layout_row_dynamic(&ctx, 25, 6);
    foreach
    (   i, dirNames;
        browser
        .directory
        .pathSplitter
        .map!(pathPart => pathPart.until(dirSeparator).byUTF!(char).array)
        .adjoin!(x=>x, splits=>splits.cumulativeFold!((a,b)=>a~dirSeparator~b))
        .expand
        .zip
        .enumerate
    )
    if
    (   i == 0?
        nk_button_image_label(&ctx, browser.media.icons.root, "", NK_TEXT_CENTERED):
        nk_button_text(&ctx, dirNames[0].ptr, dirNames[0].length.to!int)
    )
    {   browser.loadDirectory(dirNames[1]);
        break;
    }
    nk_menubar_end(&ctx);
    ctx.style.window.spacing.x = spacing_x;

    /* window layout */
    auto totalSpace = nk_window_get_content_region(&ctx);
    nk_layout_row(&ctx, NK_DYNAMIC, totalSpace.h, 2, ratio.ptr);
    nk_group_begin(&ctx, "Special", NK_WINDOW_NO_SCROLLBAR);
    {   nk_layout_row_dynamic(&ctx, 40, 1);
        if (browser.firstFrameExecuted && browser.home.length && nk_button_image_label(&ctx, browser.media.icons.home, "Home", NK_TEXT_CENTERED))
        {   browser.loadDirectory(browser.home);
        }
        if (browser.firstFrameExecuted && nk_button_image_label(&ctx, browser.media.icons.workingDirectory, "Working dir", NK_TEXT_CENTERED))
        {   browser.loadDirectory(getcwd);
        }
        if (browser.firstFrameExecuted && nk_button_label(&ctx, "Cancel"))
        {   result = true;
        }
        nk_group_end(&ctx);
    }

    /* output directory content window */
    nk_group_begin(&ctx, "Content", 0);
    {   immutable count = browser.directories.length + browser.files.length;
        enum cols = 4;
        immutable rows = (count + cols - 1) / cols;
        Unqual!(typeof(count)) index = count;
        foreach (i; 0 .. rows)
        {   nk_layout_row_dynamic(&ctx, 135, cast(int)cols);
            foreach (j; i*cols .. (i*cols+cols).min(count))
            {   if (j < browser.directories.length)
                {   if (browser.firstFrameExecuted && nk_button_image(&ctx, browser.media.icons.directory)) index = j.to!int;
                }
                else
                {   /* draw and execute files buttons */
                    size_t fileIndex = (j - browser.directories.length);
                    nk_image *icon = new nk_image;
                    *icon = (*browser.media).getFileIcon(browser.files[fileIndex]);
                    if (browser.firstFrameExecuted && nk_button_image(&ctx, *icon))
                    {   result = browser.files[fileIndex];
                    }
                }
            }

            nk_layout_row_dynamic(&ctx, 20, cast(int)cols);
            foreach (k; i*cols .. (i*cols+cols).min(count)) {
                /* draw one row of labels */
                if (k < browser.directories.length) nk_text
                (   &ctx,
                    browser.directories[k]
                    .pathSplitter.back.byCodeUnit.array
                    .adjoin!(x=>x.ptr, x=>x.length.to!int).expand,
                    NK_TEXT_CENTERED
                );
                else nk_text
                (   &ctx,
                    browser.files[k - browser.directories.length]
                    .pathSplitter.back.byCodeUnit.array
                    .adjoin!(x=>x.ptr, x=>x.length.to!int).expand,
                    NK_TEXT_CENTERED
                );
            }
        }

        if (index < count) browser.loadDirectory(browser.directories[index]);
        nk_group_end(&ctx);
    }

    browser.firstFrameExecuted = true;
    return result;
}

private alias tupArg(alias func) = x => func(x.expand);
