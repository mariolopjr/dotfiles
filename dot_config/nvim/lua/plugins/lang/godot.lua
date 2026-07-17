-- Godot file support
vim.filetype.add({
  extension = {
    gd = "gdscript",
    gdshader = "gdshader",
    tscn = "gdresource",
    tres = "gdresource",
    godot = "gdresource",
    gdextension = "gdresource",
  },
})

-- map the gdresource filetype to the godot_resource parser
vim.treesitter.language.register("godot_resource", "gdresource")

return {}
