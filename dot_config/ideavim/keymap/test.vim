""" Test Keymap
let g:WhichKeyDesc_Test = "<leader>t    +test"

nmap <leader>tt <Action>(Rider.UnitTesting.RunSolution)
nmap <leader>tr <Action>(RiderUnitTestRunSolutionAction)
nmap <leader>tc <Action>(RiderDotCoverUnitTestCoverSolutionAction)
nmap <leader>tf <action>(RerunFailedTests)

let g:WhichKeyDesc_Test_RunTool = "<leader>tt test tool"
let g:WhichKeyDesc_Test_RunTests = "<leader>tr test run"
let g:WhichKeyDesc_Test_RunTestsCover = "<leader>tc test run coverage"
let g:WhichKeyDesc_Test_RunFailed = "<leader>tf test run failed"

