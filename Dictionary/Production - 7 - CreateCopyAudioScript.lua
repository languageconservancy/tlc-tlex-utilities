--Include Utility Functions
tLuaLog("Start");

function script_path()
  local script_paths = {};
  local str = debug.getinfo(2, "S").source:sub(2)
  script_paths['lang'] = str:match("(.*/)") or str:match("(.*[/\\])");
  script_paths['global'] = string.gsub(script_paths.lang,"[a-zA-Z ]+[/\\]$","");
  script_paths['delim'] = str:match("(/)") or str:match("([/\\])");
  return script_paths
end
--load common functions
local report = "Report:\n";
local langCommonError = dofile(script_path().lang..'Common.lua');
if langCommonError ~= nil then
  return "langCommon Error: "..langCommonError
end
local globalCommonError = dofile(script_path().global..'Common.lua');
if globalCommonError ~= nil then
  return "globalCommon Error: "..globalCommonError
end



local lIndex = 0;
local eIndex = 0;
local dIndex = 0;
local cindex=0;
local count = 0;
local audioText = "#!/bin/bash\n\n";
local dedup = {};

for lIndex=0,LangLanguage:GetNumEntries()-1,1 do
  Entry = LangLanguage:GetEntry(lIndex);
  if tFrameWindow():GetSectionWindow(LangLanguage):IsTagged(Entry) then
    for eIndex = 0, Entry:GetNumDescendantsOfElementType(ElementAudio:GetID())-1, 1 do
      local Audio = Entry:GetNthDescendantOfElementType(ElementAudio:GetID(),eIndex);
      local file = tQuery(Audio,"/@FilePath");
      if dedup[file] == nil then
        audioText = audioText.."cp \""..file.."\" \"export/"..file.."\"\n";
        dedup[file] = true;
        count = count+1;
      end
    end
  end
end

local file = io.open(script_path().lang.."Export"..script_path().delim.."copyAudios.command", "w+");
file:write(audioText);
file:close();
return "found "..count.." Audios";