//binding of SDL2 for Nuklear library.
//Based on https://github.com/Timu5/bindbc-nuklear/blob/master/demo/source/main.d

import bindbc.sdl;
import bindbc.opengl;
import bindbc.nuklear;

import std.conv;

struct NkSdlDevice
{  nk_buffer cmds;
   nk_draw_null_texture null_;
   GLuint vbo, vao, ebo;
   GLuint prog;
   GLuint vert_shdr;
   GLuint frag_shdr;
   GLint attrib_pos;
   GLint attrib_uv;
   GLint attrib_col;
   GLint uniform_tex;
   GLint uniform_proj;
   GLuint font_tex;
}

struct NkSdlVertex
{  float[2] position;
   float[2] uv;
   nk_byte[4] col;
};

struct NkSdl
{  SDL_Window *win;
   NkSdlDevice ogl;
   nk_context ctx;
   nk_font_atlas atlas;
}

NkSdlDevice makeNkSdlDevice()
{  NkSdlDevice result;
   GLint status;
   const(GLchar*) vertex_shader=
   q{ #version 300 es
      uniform mat4 ProjMtx;
      in vec2 Position;
      in vec2 TexCoord;
      in vec4 Color;
      out vec2 Frag_UV;
      out vec4 Frag_Color;
      void main() {
         Frag_UV = TexCoord;
         Frag_Color = Color;
         gl_Position = ProjMtx * vec4(Position.xy, 0, 1);
      }
   };

   const(GLchar*) fragment_shader=
   q{ #version 300 es
      precision mediump float;
      uniform sampler2D Texture;
      in vec2 Frag_UV;
      in vec4 Frag_Color;
      out vec4 Out_Color;
      void main(){Out_Color = Frag_Color * texture(Texture, Frag_UV.st);}
   };

   nk_buffer_init_default(&result.cmds);
   result.prog = glCreateProgram();
   result.vert_shdr = glCreateShader(GL_VERTEX_SHADER);
   result.frag_shdr = glCreateShader(GL_FRAGMENT_SHADER);
   glShaderSource(result.vert_shdr, 1, &vertex_shader, null);
   glShaderSource(result.frag_shdr, 1, &fragment_shader, null);
   glCompileShader(result.vert_shdr);
   glCompileShader(result.frag_shdr);
   glGetShaderiv(result.vert_shdr, GL_COMPILE_STATUS, &status);
   assert(status == GL_TRUE);
   glGetShaderiv(result.frag_shdr, GL_COMPILE_STATUS, &status);
   assert(status == GL_TRUE);
   glAttachShader(result.prog, result.vert_shdr);
   glAttachShader(result.prog, result.frag_shdr);
   glLinkProgram(result.prog);
   glGetProgramiv(result.prog, GL_LINK_STATUS, &status);
   assert(status == GL_TRUE);

   result.uniform_tex = glGetUniformLocation(result.prog, "Texture");
   result.uniform_proj = glGetUniformLocation(result.prog, "ProjMtx");
   result.attrib_pos = glGetAttribLocation(result.prog, "Position");
   result.attrib_uv = glGetAttribLocation(result.prog, "TexCoord");
   result.attrib_col = glGetAttribLocation(result.prog, "Color");

   if(true)
   {  /* buffer setup */
      GLsizei vs = NkSdlVertex.sizeof;
      size_t vp = NkSdlVertex.position.offsetof;
      size_t vt = NkSdlVertex.uv.offsetof;
      size_t vc = NkSdlVertex.col.offsetof;

      glGenBuffers(1, &result.vbo);
      glGenBuffers(1, &result.ebo);
      glGenVertexArrays(1, &result.vao);

      glBindVertexArray(result.vao);
      glBindBuffer(GL_ARRAY_BUFFER, result.vbo);
      glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, result.ebo);

      glEnableVertexAttribArray(cast(GLuint)result.attrib_pos);
      glEnableVertexAttribArray(cast(GLuint)result.attrib_uv);
      glEnableVertexAttribArray(cast(GLuint)result.attrib_col);

      glVertexAttribPointer(cast(GLuint)result.attrib_pos, 2, GL_FLOAT, GL_FALSE, vs, cast(void*)vp);
      glVertexAttribPointer(cast(GLuint)result.attrib_uv, 2, GL_FLOAT, GL_FALSE, vs, cast(void*)vt);
      glVertexAttribPointer(cast(GLuint)result.attrib_col, 4, GL_UNSIGNED_BYTE, GL_TRUE, vs, cast(void*)vc);
   }

   glBindTexture(GL_TEXTURE_2D, 0);
   glBindBuffer(GL_ARRAY_BUFFER, 0);
   glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
   glBindVertexArray(0);

   return result;
}

void uploadAtlas(ref NkSdlDevice dev, const void *image, int width, int height)
{  glGenTextures(1, &dev.font_tex);
   glBindTexture(GL_TEXTURE_2D, dev.font_tex);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, cast(GLsizei)width, cast(GLsizei)height, 0,
             GL_RGBA, GL_UNSIGNED_BYTE, image);
}

void free(ref NkSdlDevice dev)
{  glDetachShader(dev.prog, dev.vert_shdr);
   glDetachShader(dev.prog, dev.frag_shdr);
   glDeleteShader(dev.vert_shdr);
   glDeleteShader(dev.frag_shdr);
   glDeleteProgram(dev.prog);
   glDeleteTextures(1, &dev.font_tex);
   glDeleteBuffers(1, &dev.vbo);
   glDeleteBuffers(1, &dev.ebo);
   nk_buffer_free(&dev.cmds);
}

int[2] size(SDL_Window* window)
{  typeof(return) result;
   window.SDL_GetWindowSize(&result[0], &result[1]);
   return result;
}

void render(ref NkSdl sdl, nk_anti_aliasing AA, int max_vertex_buffer, int max_element_buffer)
{  import std.meta : Alias;
   import core.stdc.string;
   int width, height;
   int display_width, display_height;
   nk_vec2 scale;
   GLfloat[4][4] ortho = [
      [2.0f, 0.0f, 0.0f, 0.0f],
      [0.0f,-2.0f, 0.0f, 0.0f],
      [0.0f, 0.0f,-1.0f, 0.0f],
      [-1.0f,1.0f, 0.0f, 1.0f],
   ];
   SDL_GetWindowSize(sdl.win, &width, &height);
   SDL_GL_GetDrawableSize(sdl.win, &display_width, &display_height);
   ortho[0][0] /= cast(GLfloat)width;
   ortho[1][1] /= cast(GLfloat)height;

   scale.x = display_width/cast(float)width;
   scale.y = display_height/cast(float)height;

   /* setup global state */
   glViewport(0,0,display_width,display_height);
   glEnable(GL_BLEND);
   glBlendEquation(GL_FUNC_ADD);
   glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
   glDisable(GL_CULL_FACE);
   glDisable(GL_DEPTH_TEST);
   glEnable(GL_SCISSOR_TEST);
   glActiveTexture(GL_TEXTURE0);

   /* setup program */
   glUseProgram(sdl.ogl.prog);
   glUniform1i(sdl.ogl.uniform_tex, 0);
   glUniformMatrix4fv(sdl.ogl.uniform_proj, 1, GL_FALSE, &ortho[0][0]);

   if (true)
   {  /* convert from command queue into draw list and draw to screen */
      const(nk_draw_command)* cmd;
      void* vertices;
      void* elements;
      const(nk_draw_index)* offset = null;
      nk_buffer vbuf;
      nk_buffer ebuf;

      /* allocate vertex and element buffer */
      glBindVertexArray(sdl.ogl.vao);
      glBindBuffer(GL_ARRAY_BUFFER, sdl.ogl.vbo);
      glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sdl.ogl.ebo);

      glBufferData(GL_ARRAY_BUFFER, max_vertex_buffer, null, GL_STREAM_DRAW);
      glBufferData(GL_ELEMENT_ARRAY_BUFFER, max_element_buffer, null, GL_STREAM_DRAW);

      /* load vertices/elements directly into vertex/element buffer */
      vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
      elements = glMapBuffer(GL_ELEMENT_ARRAY_BUFFER, GL_WRITE_ONLY);
      {  /* fill convert configuration */
         nk_convert_config config;
         const(nk_draw_vertex_layout_element)[] vertex_layout= [
            {nk_draw_vertex_layout_attribute.NK_VERTEX_POSITION, nk_draw_vertex_layout_format.NK_FORMAT_FLOAT, NkSdlVertex.position.offsetof},
            {nk_draw_vertex_layout_attribute.NK_VERTEX_TEXCOORD, nk_draw_vertex_layout_format.NK_FORMAT_FLOAT, NkSdlVertex.uv.offsetof},
            {nk_draw_vertex_layout_attribute.NK_VERTEX_COLOR, nk_draw_vertex_layout_format.NK_FORMAT_R8G8B8A8, NkSdlVertex.col.offsetof},
            NK_VERTEX_LAYOUT_END
         ];
         memset(&config, 0, config.sizeof);
         config.vertex_layout = vertex_layout.ptr;
         config.vertex_size = NkSdlVertex.sizeof;
         config.vertex_alignment = NkSdlVertex.alignof;
         config.null_ = sdl.ogl.null_;
         config.circle_segment_count = 22;
         config.curve_segment_count = 22;
         config.arc_segment_count = 22;
         config.global_alpha = 1.0f;
         config.shape_AA = AA;
         config.line_AA = AA;

         /* setup buffers to load vertices and elements */
         nk_buffer_init_fixed(&vbuf, vertices, cast(nk_size)max_vertex_buffer);
         nk_buffer_init_fixed(&ebuf, elements, cast(nk_size)max_element_buffer);
         nk_convert(&sdl.ctx, &sdl.ogl.cmds, &vbuf, &ebuf, &config);
      }
      glUnmapBuffer(GL_ARRAY_BUFFER);
      glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);

      /* iterate over and execute each draw command */
      nk_draw_foreach(&sdl.ctx, &sdl.ogl.cmds, (cmd)
      {
         if (!cmd.elem_count) return;
         glBindTexture(GL_TEXTURE_2D, cast(GLuint)cmd.texture.id);
         glScissor(cast(GLint)(cmd.clip_rect.x * scale.x),
                 cast(GLint)((height - cast(GLint)(cmd.clip_rect.y + cmd.clip_rect.h)) * scale.y),
                 cast(GLint)(cmd.clip_rect.w * scale.x),
                 cast(GLint)(cmd.clip_rect.h * scale.y));
         glDrawElements(GL_TRIANGLES, cast(GLsizei)cmd.elem_count, GL_UNSIGNED_INT, offset);
         offset += cmd.elem_count;
      });
      nk_clear(&sdl.ctx);
      nk_buffer_clear(&sdl.ogl.cmds);
   }

   glUseProgram(0);
   glBindBuffer(GL_ARRAY_BUFFER, 0);
   glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
   glBindVertexArray(0);
   glDisable(GL_BLEND);
   glDisable(GL_SCISSOR_TEST);
}

nk_image loadIcon(const(char)[] fileName)
{  //I would normally rather use FreeImage, but imagefmt does not need
   //a separate library binary, so for sake of example I felt it was
   //a better choice.
   import imagefmt;
   import std.stdio;

   auto image = fileName.read_image(4);
   uint textureId;
   glGenTextures(1, &textureId);
   glBindTexture(GL_TEXTURE_2D, textureId);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, image.w, image.h, 0, GL_RGBA, GL_UNSIGNED_BYTE, image.buf8.ptr);

   return nk_image_id(cast(int)textureId);
}

extern(C) void nkPasteSdlClipboard(nk_handle usr, nk_text_edit *edit)
{  const char *text = SDL_GetClipboardText();
   if(text) nk_textedit_paste(edit, text, nk_strlen(text));
}

extern(C) void nkCopySdlClipboard(nk_handle usr, const(char) *text, int len)
{  import core.stdc.string, core.stdc.stdlib;

   char *str = null;
   if(!len) return;
   str = cast(char*)malloc(cast(size_t)len+1);
   if(!str) return;
   memcpy(str, text, cast(size_t)len);
   str[len] = '\0';
   SDL_SetClipboardText(str);
   core.stdc.stdlib.free(str);
}


NkSdl makeNkSdl(SDL_Window* win)
{  NkSdl result;
   result.win = win;
   nk_init_default(&result.ctx, null);
   result.ctx.clip.copy = cast(nk_plugin_copy) &nkCopySdlClipboard;
   result.ctx.clip.paste = cast(nk_plugin_paste) &nkPasteSdlClipboard;
   result.ctx.clip.userdata = nk_handle_ptr(null);
   result.ogl = makeNkSdlDevice;
   return result;
}

ref beginFontStash(ref nk_font_atlas atlas)
{  nk_font_atlas_init_default(&atlas);
   nk_font_atlas_begin(&atlas);
   return atlas;
}

void endFontStash(ref NkSdl sdl)
{  const(void)* image; int w; int h;
   image = nk_font_atlas_bake(&sdl.atlas, &w, &h, nk_font_atlas_format.NK_FONT_ATLAS_RGBA32);
   sdl.ogl.uploadAtlas(image, w, h);
   nk_font_atlas_end(&sdl.atlas, nk_handle_id(cast(int)sdl.ogl.font_tex), &sdl.ogl.null_);
   if(sdl.atlas.default_font)
      nk_style_set_font(&sdl.ctx, &sdl.atlas.default_font.handle);
}

int handleEvent (ref NkSdl sdl, SDL_Event *evt)
{  import core.stdc.string;

   /* optional grabbing behavior */
   if(sdl.ctx.input.mouse.grab)
   {  SDL_SetRelativeMouseMode(SDL_TRUE);
      sdl.ctx.input.mouse.grab = 0;
   } else if (sdl.ctx.input.mouse.ungrab)
   {  int x = cast(int)sdl.ctx.input.mouse.prev.x, y = cast(int)sdl.ctx.input.mouse.prev.y;
      SDL_SetRelativeMouseMode(SDL_FALSE);
      SDL_WarpMouseInWindow(sdl.win, x, y);
      sdl.ctx.input.mouse.ungrab = 0;
   }

   if(evt.type == SDL_KEYUP || evt.type == SDL_KEYDOWN)
   {  /* key events */
      int down = evt.type == SDL_KEYDOWN;
      const Uint8* state = SDL_GetKeyboardState(null);
      SDL_Keycode sym = evt.key.keysym.sym;
      if (sym == SDLK_RSHIFT || sym == SDLK_LSHIFT)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_SHIFT, down);
      else if (sym == SDLK_DELETE)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_DEL, down);
      else if (sym == SDLK_RETURN)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_ENTER, down);
      else if (sym == SDLK_TAB)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_TAB, down);
      else if (sym == SDLK_BACKSPACE)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_BACKSPACE, down);
      else if (sym == SDLK_HOME) {
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_TEXT_START, down);
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_SCROLL_START, down);
      } else if (sym == SDLK_END) {
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_TEXT_END, down);
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_SCROLL_END, down);
      } else if (sym == SDLK_PAGEDOWN) {
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_SCROLL_DOWN, down);
      } else if (sym == SDLK_PAGEUP) {
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_SCROLL_UP, down);
      } else if (sym == SDLK_z)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_TEXT_UNDO, down && state[SDL_SCANCODE_LCTRL]);
      else if (sym == SDLK_r)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_TEXT_REDO, down && state[SDL_SCANCODE_LCTRL]);
      else if (sym == SDLK_c)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_COPY, down && state[SDL_SCANCODE_LCTRL]);
      else if (sym == SDLK_v)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_PASTE, down && state[SDL_SCANCODE_LCTRL]);
      else if (sym == SDLK_x)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_CUT, down && state[SDL_SCANCODE_LCTRL]);
      else if (sym == SDLK_b)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_TEXT_LINE_START, down && state[SDL_SCANCODE_LCTRL]);
      else if (sym == SDLK_e)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_TEXT_LINE_END, down && state[SDL_SCANCODE_LCTRL]);
      else if (sym == SDLK_UP)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_UP, down);
      else if (sym == SDLK_DOWN)
         nk_input_key(&sdl.ctx, nk_keys.NK_KEY_DOWN, down);
      else if (sym == SDLK_LEFT) {
         if (state[SDL_SCANCODE_LCTRL])
            nk_input_key(&sdl.ctx, nk_keys.NK_KEY_TEXT_WORD_LEFT, down);
         else nk_input_key(&sdl.ctx, nk_keys.NK_KEY_LEFT, down);
      } else if (sym == SDLK_RIGHT) {
         if (state[SDL_SCANCODE_LCTRL])
            nk_input_key(&sdl.ctx, nk_keys.NK_KEY_TEXT_WORD_RIGHT, down);
         else nk_input_key(&sdl.ctx, nk_keys.NK_KEY_RIGHT, down);
      } else return 0;
      return 1;
   } else if (evt.type == SDL_MOUSEBUTTONDOWN || evt.type == SDL_MOUSEBUTTONUP) {
      /* mouse button */
      int down = evt.type == SDL_MOUSEBUTTONDOWN;
      const int x = evt.button.x, y = evt.button.y;
      if (evt.button.button == SDL_BUTTON_LEFT) {
         if (evt.button.clicks > 1)
            nk_input_button(&sdl.ctx, nk_buttons.NK_BUTTON_DOUBLE, x, y, down);
         nk_input_button(&sdl.ctx, nk_buttons.NK_BUTTON_LEFT, x, y, down);
      } else if (evt.button.button == SDL_BUTTON_MIDDLE)
         nk_input_button(&sdl.ctx, nk_buttons.NK_BUTTON_MIDDLE, x, y, down);
      else if (evt.button.button == SDL_BUTTON_RIGHT)
         nk_input_button(&sdl.ctx, nk_buttons.NK_BUTTON_RIGHT, x, y, down);
      return 1;
   } else if (evt.type == SDL_MOUSEMOTION)
   {  /* mouse motion */
      if (sdl.ctx.input.mouse.grabbed)
      {  int x = cast(int)sdl.ctx.input.mouse.prev.x, y = cast(int)sdl.ctx.input.mouse.prev.y;
         nk_input_motion(&sdl.ctx, x + evt.motion.xrel, y + evt.motion.yrel);
      } else nk_input_motion(&sdl.ctx, evt.motion.x, evt.motion.y);
      return 1;
   } else if (evt.type == SDL_TEXTINPUT)
   {  /* text input */
      nk_glyph glyph;
      memcpy(cast(void*)glyph.ptr, cast(void*)evt.text.text, NK_UTF_SIZE);
      nk_input_glyph(&sdl.ctx, glyph.ptr);
      return 1;
   } else if (evt.type == SDL_MOUSEWHEEL)
   {  /* mouse wheel */
      nk_input_scroll(&sdl.ctx,nk_vec2(cast(float)evt.wheel.x,cast(float)evt.wheel.y));
      return 1;
   }

   return 0;
}

void shutdown(ref NkSdl sdl)
{  import core.stdc.string;

   nk_font_atlas_clear(&sdl.atlas);
   nk_free(&sdl.ctx);
   sdl.ogl.free;
   memset(&sdl, 0, sdl.sizeof);
}
