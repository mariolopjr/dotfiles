-- Godot project files

vim.filetype.add({
  extension = {
    godot = "gdresource",
    gdextension = "gdresource",
  },
})

-- map the gdresource filetype to the godot_resource parser
vim.treesitter.language.register("godot_resource", "gdresource")

vim.api.nvim_create_user_command("Godot", function(opts)
  require("util.godot").open_editor(opts.args)
end, {
  nargs = "?",
  complete = "dir",
  desc = "Open the godot editor for this project",
})

return {}
