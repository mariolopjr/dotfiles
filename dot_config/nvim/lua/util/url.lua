-- URL detection for the link underline highlighter

local M = {}

local TLDS = {
  "com",
  "org",
  "net",
  "edu",
  "gov",
  "int",
  "mil",
  "io",
  "dev",
  "co",
  "me",
  "tv",
  "gg",
  "xyz",
  "info",
  "page",
  "site",
  "blog",
  "wiki",
  "cloud",
  "tech",
  "uk",
  "us",
  "ca",
  "de",
  "fr",
  "jp",
  "nl",
  "se",
  "no",
  "fi",
  "au",
  "nz",
  "eu",
  "ch",
  "it",
  "es",
  "pl",
  "br",
  "in",
}

-- vim regex for matchadd: a scheme URL, a www. domain, or a
-- bare domain whose last label is a known TLD
M.regex = table.concat({
  [=[\v<%(]=],
  [=[https?://[^[:space:]]*[[:alnum:]/#=&_~%+-]]=],
  [=[|www\.[^[:space:]]*[[:alnum:]/#=&_~%+-]]=],
  [=[|%([[:alnum:]_-]+\.)+%(]=]
    .. table.concat(TLDS, "|")
    .. [=[)>]=]
    .. [=[%(:[0-9]+)?%(/[^[:space:]]*[[:alnum:]/#=&_~%+-])?]=],
  [=[)]=],
}, "")

return M
