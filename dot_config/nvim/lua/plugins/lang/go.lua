-- Go projects

vim.api.nvim_create_user_command("GoInfo", function()
  vim.notify(table.concat(require("util.go").report(), "\n"))
end, {
  desc = "Report the go module and tools resolved for this buffer",
})

return {}
