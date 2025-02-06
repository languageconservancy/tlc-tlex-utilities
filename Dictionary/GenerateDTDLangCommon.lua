-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Giang Le Sarlah
--Generate parts of the Common.lua file from a DTD{Date}.txt file
--Include Utility Functions

tRequestLoadAll();
--Include Utility Functions
tLuaLog("Start");

function script_path()
  local script_paths = {};
  local str = debug.getinfo(2, "S").source:sub(2)
  script_paths['lang'] = str:match("(.*/)") or str:match("(.*[/\\])");
  script_paths['global'] = string.gsub(script_paths.lang,"[a-zA-Z ]+[/\\]$","");
  return script_paths
end
--load common functions
dofile(script_path().lang..'Common.lua');
dofile(script_path().global..'Common.lua');

local InputFile = script_path().lang..'DTD.txt';
local OutputFile = script_path().lang.."DTDTmpCommon.txt"

GenerateDTDLangCommon(InputFile, OutputFile);
return "done. check output file at "..OutputFile;